//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Vault } from "./Vault.sol";
import { IVault } from "./interfaces/IVault.sol";
import { Closure } from "./Closure.sol";
import { AbacusController } from "./AbacusController.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

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
        uint256 timesInterestPaid;
        mapping(uint256 => bool) interestPaid;
    }

    /* ======== EVENT ======== */
    event EthBorrowed(address _user, address _pool, address nft, uint256 id, uint256 _amount);
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
        Position storage openLoan = loans[_nft][_id];
        Vault vault = Vault(payable(_pool));
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        require(
            msg.sender == IERC721(_nft).ownerOf(_id)
            || msg.sender == openLoan.borrower, "Not owner"
        );
        if(openLoan.amount == 0) {
            IERC721(_nft).transferFrom(msg.sender, address(this), _id);
        }
        require(
            95 * vault.getPayoutPerReservation((block.timestamp - vault.startTime()) / 1 days) 
                / 100 >= (_amount + openLoan.amount), "Exceed current LTV"
        );
        uint256 payoutPerResFuture = 
            vault.getPayoutPerReservation((block.timestamp - vault.startTime() + 12 hours) / 1 days);
        require(95 * payoutPerResFuture / 100 >= _amount + openLoan.amount, "Exceed future LTV");
        if(!loanDeployed[_nft][_id]) {
            openLoan.pool = _pool;
            openLoan.amount = _amount;
            openLoan.borrower = msg.sender;
            openLoan.startEpoch = (block.timestamp - Vault(payable(openLoan.pool)).startTime()) / 1 days;
            loanDeployed[_nft][_id] = true;
        } else {
            uint256 epochsMissed = poolEpoch - loans[_nft][_id].startEpoch - loans[_nft][_id].timesInterestPaid;
            require(epochsMissed == 0);
            openLoan.amount += _amount;
        }
        vault.accessLiq(msg.sender, _nft, _id, _amount);
        emit EthBorrowed(msg.sender, _pool, _nft, _id, _amount);
    }

    /// SEE ILend.sol FOR COMMENTS
    function payInterest(uint256 _epoch, address _nft, uint256 _id) external payable nonReentrant {
        Position storage openLoan = loans[_nft][_id];
        Vault vault = Vault(payable(openLoan.pool));
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        require(_epoch <= poolEpoch, "Improper epoch input");
        require(!openLoan.interestPaid[_epoch], "Already paid interest");
        uint256 epochsMissed = poolEpoch - loans[_nft][_id].startEpoch - loans[_nft][_id].timesInterestPaid;
        require(
            msg.value == 
                vault.interestRate() * vault.getPayoutPerReservation(_epoch) / 10_000 
                    * vault.epochLength() / (52 weeks) * ((epochsMissed >= 2) ? 3 * epochsMissed / 2 : 1),
            "Incorrect payment size"
        );
        openLoan.timesInterestPaid++;
        openLoan.interestPaid[_epoch] = true;
        vault.processFees{value: msg.value}();
    }

    /// SEE ILend.sol FOR COMMENTS
    function repay(address nft, uint256 id) external payable nonReentrant {
        Position storage openLoan = loans[nft][id];
        uint256 poolEpoch = (block.timestamp - Vault(payable(openLoan.pool)).startTime()) / Vault(payable(openLoan.pool)).epochLength();
        require(msg.sender == openLoan.borrower, "Not borrower");
        require(poolEpoch - openLoan.startEpoch + 1 == openLoan.timesInterestPaid, "Must pay outstanding interest");
        address borrower = openLoan.borrower;
        openLoan.amount -= msg.value;
        payable(openLoan.pool).transfer(msg.value);
        if(openLoan.amount == 0) {
            delete loans[nft][id];
            delete loanDeployed[nft][id];
            IERC721(nft).transferFrom(address(this), borrower, id);
        }
        emit EthRepayed(msg.sender, openLoan.pool, nft, id, msg.value);
    }

    /// SEE ILend.sol FOR COMMENTS
    function liquidate(
        address nft, 
        uint256 id, 
        address[] calldata _nfts,
        uint256[] calldata _ids, 
        uint256[] calldata _closureNonces
    ) external nonReentrant {
        Vault vault = Vault(payable(loans[nft][id].pool));
        uint256 loanAmount = loans[nft][id].amount;
        if(this.getPricePointViolation(vault, loanAmount, _nfts, _ids, _closureNonces)) {
            processLiquidation(
                vault,
                nft,
                id
            );
        }
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
        payable(msg.sender).transfer((payout - loanAmount) / 100);
        vault.processFees{value: payout - loanAmount - ((payout - loanAmount) / 100)}();
        emit BorrowerLiquidated(loans[nft][id].borrower, address(vault), nft, id, loanAmount);
        delete loanDeployed[nft][id];
        delete loans[nft][id];
    }

    /* ======== GETTERS ======== */
    /// SEE ILend.sol FOR COMMENTS
    function getPricePointViolation(
        Vault vault,
        uint256 loanAmount,
        address[] calldata _nfts,
        uint256[] calldata _ids, 
        uint256[] calldata _closureNonces
    ) external view returns(bool) {
        uint256 totalBids;
        for(uint256 i; i < _closureNonces.length; i++) {
            uint256 auctionEndTime = Closure(payable(vault.closePoolContract())).auctionEndTime(_closureNonces[i], _nfts[i], _ids[i]);
            require(
                auctionEndTime != 0
                && auctionEndTime < block.timestamp + 12 hours
            );
            totalBids += Closure(payable(vault.closePoolContract())).highestBid(_closureNonces[i], _nfts[i], _ids[i]);
        }
        return (
            95 * (
                (totalBids
                + (
                    vault.getPayoutPerReservation((block.timestamp - vault.startTime() + 12 hours) / 1 days)
                )) / (vault.reservationsAvailable() + _nfts.length)
            ) / 100 <= loanAmount 
        );
    }

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
        uint256 timesInterestPaid
    ) {
        Position storage loan = loans[nft][id];
        borrower = loan.borrower;
        pool = loan.pool;
        amount = loan.amount;
        transferFromPermission = loan.transferFromPermission;
        startEpoch = loan.startEpoch;
        timesInterestPaid = loan.timesInterestPaid;
    }

    /// SEE ILend.sol FOR COMMENTS
    function getInterestPayment(uint256 _epoch, address _nft, uint256 _id) external view returns(uint256) {
        Vault vault = Vault(payable(loans[_nft][_id].pool));
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        uint256 epochsMissed = poolEpoch - loans[_nft][_id].startEpoch - loans[_nft][_id].timesInterestPaid;
        return vault.interestRate() * vault.getPayoutPerReservation(_epoch) / 10_000 
                    * vault.epochLength() / (52 weeks) * ((epochsMissed >= 2) ? 3 * epochsMissed / 2 : 1);
    }
}