//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vault } from "./Vault.sol";
import { AbacusController } from "./AbacusController.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./helpers/ReentrancyGuard.sol";
// import "hardhat/console.sol";

/// @title NFT Lender
/// @author Gio Medici
/// @notice Borrow against the value of a backing Abacus Spot pool
contract Lend is ReentrancyGuard {

    /* ======== ADDRESS IMMUTABLE ======== */
    AbacusController public immutable controller;

    /* ======== MAPPING ======== */
    /// @notice Track if a loan has been taken out against an NFT
    /// [address] -> NFT Collection address
    /// [uint256] -> NFT ID
    /// [bool] -> deployment status
    mapping(address => mapping(uint256 => bool)) public loanDeployed;

    /// @notice Track loan metrics
    /// [address] -> NFT Collection address
    /// [uint256] -> NFT ID
    mapping(address => mapping(uint256 => Position)) public loans;
    
    /* ======== STRUCT ======== */
    /// @notice Struct to hold information regarding deployed loan
    /// [borrower] -> User with the borrower
    /// [pool] -> Underlying Spot pool
    /// [transferFromPermission] -> Stores the address of a user with transfer permission
    /// [startEpoch] -> The epoch that the loan was taken out
    /// [amount] -> Outstanding loan amount
    /// [timesInterestPaid] -> Amout of epochs that interest has been paid
    /// [interestPaid] -> Track whether a loan has had interest paid during an epoch
        /// [uint256] -> epoch
    struct Position {
        address borrower;
        address pool;
        address transferFromPermission;
        uint256 startEpoch;
        uint256 amount;
        uint256 interestEpoch;
    }

    /* ======== EVENT ======== */
    event EthBorrowed(address _user, address _pool, address nft, uint256 id, uint256 _amount);
    event InterestPaid(address _user, address _pool, address nft, uint256 id, uint256[] _epoch, uint256 _amountPaid);
    event EthRepayed(address _user, address _pool, address nft, uint256 id, uint256 _amount);
    event BorrowerLiquidated(address _user, address _pool, address nft, uint256 id, uint256 _amount);
    event LoanTransferred(address _pool, address from, address to, address nft, uint256 id);

    /* ======== CONSTRUCTOR ======== */
    constructor(address _controller) {
        controller = AbacusController(_controller);
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== LENDING ======== */
    /// SEE ILend.sol FOR COMMENTS
    function borrow(address _pool, address _nft, uint256 _id, uint256 _amount) external nonReentrant {
        require(controller.accreditedAddresses(_pool), "Not accredited");
        require(_amount > 0, "Must borrow some amount");
        Position storage openLoan = loans[_nft][_id];
        Vault vault = Vault(payable(_pool));
        require(vault.getHeldTokenExistence(_nft, _id), "Invalid borrow choice");
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        require(
            msg.sender == IERC721(_nft).ownerOf(_id)
            || msg.sender == openLoan.borrower, "Not owner"
        );
        if(openLoan.amount == 0) {
            require(vault.getReservationsAvailable() > 0, "Unable to take out a new loan right now. All Collateral Slots in use.");
            IERC721(_nft).transferFrom(msg.sender, address(this), _id);
        }
        require(
            95 * vault.getPayoutPerReservation((block.timestamp - vault.startTime()) / vault.epochLength()) 
                / 100 >= (_amount + openLoan.amount), "Exceed current LTV"
        );
        uint256 payoutPerResFuture = 
            vault.getPayoutPerReservation(
                (block.timestamp - vault.startTime() + vault.epochLength() / 6) / vault.epochLength()
            );
        require(95 * payoutPerResFuture / 100 >= _amount + openLoan.amount, "Exceed future LTV");
        if(!loanDeployed[_nft][_id]) {
            openLoan.pool = _pool;
            openLoan.amount = _amount;
            openLoan.borrower = msg.sender;
            openLoan.startEpoch = (block.timestamp - Vault(payable(openLoan.pool)).startTime()) / vault.epochLength();
            openLoan.interestEpoch = openLoan.startEpoch;
            loanDeployed[_nft][_id] = true;
        } else {
            if(poolEpoch > openLoan.interestEpoch) {
                uint256 epochsMissed = poolEpoch + 1 - openLoan.interestEpoch;
                require(epochsMissed == 0, "Must pay down interest owed before borrowing more");    
            }
            openLoan.amount += _amount;
        }
        require(IERC721(_nft).ownerOf(_id) == address(this), "NFT custody transfer failed");
        vault.accessLiq(msg.sender, _nft, _id, _amount);
        emit EthBorrowed(msg.sender, _pool, _nft, _id, _amount);
    }

    /// SEE ILend.sol FOR COMMENTS
    function payInterest(uint256[] calldata _epoch, address _nft, uint256 _id) external nonReentrant {
        Position storage openLoan = loans[_nft][_id];
        require(openLoan.amount != 0, "No open loan");
        Vault vault = Vault(payable(openLoan.pool));
        // require(openLoan.amount < vault.getPayoutPerReservation((block.timestamp - vault.startTime()) / vault.epochLength()));
        uint256 totalInterest;
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        require(poolEpoch + 1 != openLoan.interestEpoch, "Interest already paid");
        uint256 interestEpoch_ = openLoan.interestEpoch;
        uint256 epochsMissed = poolEpoch + 1 - interestEpoch_;
        for(uint256 i; i < _epoch.length; i++) {
            uint256 epoch = _epoch[i];
            require(poolEpoch > epoch, "Must wait till epoch concludes");
            require(epoch == interestEpoch_, "Already paid interest");
            totalInterest += vault.interestRate() * vault.getPayoutPerReservation(epoch) / 10_000 
                        * vault.epochLength() / (52 weeks) * ((epochsMissed >= 2) ? 3 * epochsMissed / 2 : 1);
            interestEpoch_++;
        }
        openLoan.interestEpoch = interestEpoch_;
        require((vault.token()).transferFrom(msg.sender, address(vault), totalInterest));
        vault.processFees(totalInterest);
        emit InterestPaid(msg.sender, openLoan.pool, _nft, _id, _epoch, totalInterest);
    }

    /// SEE ILend.sol FOR COMMENTS
    function repay(address nft, uint256 id, uint256 _amount) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        Vault vault = Vault(payable(openLoan.pool));
        require(openLoan.amount != 0, "No open loan");
        address pool = openLoan.pool;
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        require(msg.sender == openLoan.borrower, "Not borrower");
        uint256 finalInterestPayment;
        if(poolEpoch == openLoan.interestEpoch) {
            finalInterestPayment = vault.interestRate() * vault.getPayoutPerReservation(poolEpoch) / 10_000 
                        * vault.epochLength() / (52 weeks);
        } else {
            require(poolEpoch + 1 == openLoan.interestEpoch, "Must pay outstanding interest");
        }
        address borrower = openLoan.borrower;
        openLoan.amount -= _amount;
        require(vault.token().transferFrom(msg.sender, pool, _amount));
        vault.depositLiq(nft, id, _amount);
        if(openLoan.amount == 0) {
            delete loans[nft][id];
            delete loanDeployed[nft][id];
            IERC721(nft).transferFrom(address(this), borrower, id);
        }
        require(IERC721(nft).ownerOf(id) == borrower, "Transfer failed");
        emit EthRepayed(msg.sender, pool, nft, id, _amount);
    }

    /// SEE ILend.sol FOR COMMENTS
    function liquidate(
        address nft, 
        uint256 id
    ) external nonReentrant {
        Vault vault = Vault(payable(loans[nft][id].pool));
        uint256 loanAmount = loans[nft][id].amount;
        uint256 currentEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        uint256 futureEpoch = (block.timestamp - vault.startTime() + vault.epochLength() / 6) / vault.epochLength();
        if(loanAmount > vault.getPayoutPerReservation(currentEpoch)) {
            require((vault.token()).transferFrom(msg.sender, address(vault), loanAmount), "Must cover entire loan");
            IERC721(nft).transferFrom(address(this), msg.sender, id);
            vault.resetOutstanding(nft, id);
        } else if(loanAmount > vault.getPayoutPerReservation(futureEpoch)) {
            processLiquidation(
                vault, 
                nft, 
                id
            );
        } else {
            revert("Liquidation failed");
        }

        emit BorrowerLiquidated(loans[nft][id].borrower, address(vault), nft, id, loanAmount);
        delete loanDeployed[nft][id];
        delete loans[nft][id];
    }

    /// SEE ILend.sol FOR COMMENTS
    function allowTransferFrom(address nft, uint256 id, address allowee) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(msg.sender == openLoan.borrower, "Not borrower");
        openLoan.transferFromPermission = allowee;
    }

    /// SEE ILend.sol FOR COMMENTS
    function transferFromLoanOwnership(
        address from,
        address to, 
        address nft, 
        uint256 id
    ) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(
            msg.sender == openLoan.borrower
            || openLoan.transferFromPermission == msg.sender, "No permission"
        );
        delete openLoan.transferFromPermission;
        openLoan.borrower = to;
        emit LoanTransferred(openLoan.pool, from, to, nft, id);
    }
    
    /* ======== INTERNAL ======== */
    function processLiquidation(
        Vault vault,
        address nft,
        uint256 id
    ) internal {
        uint256 loanAmount = loans[nft][id].amount;
        IERC721(nft).approve(address(vault), id);
        uint256 payout = vault.closeNft(nft, id);
        require((vault.token()).transfer(msg.sender, (payout - loanAmount) / 10));
        require((vault.token()).transfer(address(vault), payout - loanAmount - ((payout - loanAmount) / 10)));
        vault.processFees(payout - loanAmount - ((payout - loanAmount) / 10));
    }

    /* ======== GETTERS ======== */
    /// SEE ILend.sol FOR COMMENTS
    function getPosition(
        address nft, 
        uint256 id
    ) external view returns(
        address borrower,
        address pool,
        address transferFromPermission,
        uint256 startEpoch,
        uint256 amount,
        uint256 interestEpoch
    ) {
        Position storage loan = loans[nft][id];
        borrower = loan.borrower;
        pool = loan.pool;
        transferFromPermission = loan.transferFromPermission;
        startEpoch = loan.startEpoch;
        amount = loan.amount;
        interestEpoch = loan.interestEpoch;
    }

    /// SEE ILend.sol FOR COMMENTS
    function getInterestPayment(uint256[] calldata _epoch, address _nft, uint256 _id) external view returns(uint256) {
        Vault vault = Vault(payable(loans[_nft][_id].pool));
        uint256 totalInterest;
        uint256 length = _epoch.length;
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        if(
            loans[_nft][_id].amount == 0
            || loans[_nft][_id].interestEpoch == poolEpoch + 1
        ) {
            return 0;
        }
        uint256 epochsMissed = poolEpoch + 1 - loans[_nft][_id].interestEpoch;
        for(uint256 i; i < length; i++) {
            uint256 epoch = _epoch[i];
            totalInterest += vault.interestRate() * vault.getPayoutPerReservation(epoch) / 10_000 
                        * vault.epochLength() / (52 weeks) * ((epochsMissed >= 2) ? 3 * epochsMissed / 2 : 1);
        }
        return totalInterest;
    }
}