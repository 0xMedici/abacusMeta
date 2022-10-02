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
    /// @notice Borrow against an NFT
    /// @dev Upon borrowing ETH is minted against the value of the backing pool
    /// @param _pool Backing pool address
    /// @param nft NFT Collection address
    /// @param id NFT ID 
    /// @param _amount Loan amount
    function borrow(address _pool, address nft, uint256 id, uint256 _amount) external nonReentrant {
        require(controller.accreditedAddresses(_pool), "Not accredited");
        Position storage openLoan = loans[nft][id];
        Vault vault = Vault(payable(_pool));
        require(
            msg.sender == IERC721(nft).ownerOf(id)
            || msg.sender == openLoan.borrower, "Not owner"
        );
        if(openLoan.amount == 0) {
            IERC721(nft).transferFrom(msg.sender, address(this), id);
        }
        require(
            95 * vault.getPayoutPerReservation((block.timestamp - vault.startTime()) / 1 days) 
                / 100 >= (_amount + openLoan.amount), "Exceed current LTV"
        );
        require(
            vault.reservationMade(
                (block.timestamp - vault.startTime()) / 1 days,
                nft,
                id
            ), "Reservation not made"
        );
        require(
            vault.reservationMade(
                (block.timestamp - vault.startTime() + 12 hours) / 1 days,
                nft,
                id
            ), "Reservation not made in future"
        );
        require(
            (block.timestamp - vault.startTime()) / 1 days 
            == (block.timestamp - vault.startTime() + 12 hours) / 1 days, "Invalid borrow time"
        );
        uint256 payoutPerResFuture = 
            vault.getPayoutPerReservation((block.timestamp - vault.startTime() + 12 hours) / 1 days);
        require(95 * payoutPerResFuture / 100 >= _amount + openLoan.amount, "Exceed future LTV");
        if(!loanDeployed[nft][id]) {
            openLoan.pool = _pool;
            openLoan.amount = _amount;
            openLoan.borrower = msg.sender;
            openLoan.startEpoch = (block.timestamp - Vault(payable(openLoan.pool)).startTime()) / 1 days;
            loanDeployed[nft][id] = true;
        } else {
            require(!this.getInterestViolation(nft, id));
            openLoan.amount += _amount;
        }
        vault.accessLiq(msg.sender, nft, id, _amount);
        emit EthBorrowed(msg.sender, _pool, nft, id, _amount);
    }

    /// @notice Pay interest on an outstanding loan
    /// @dev The interest rate is stored on the backing Spot pool contract
    /// @param _epoch Epoch for which a user is paying interest
    /// @param _nft NFT for which a user is paying interest
    /// @param _id Corresponding NFT ID for which a user is paying interest
    function payInterest(uint256 _epoch, address _nft, uint256 _id) external payable {
        Position storage openLoan = loans[_nft][_id];
        Vault vault = Vault(payable(openLoan.pool));
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / 1 days;
        require(_epoch <= poolEpoch, "Improper epoch input");
        require(!openLoan.interestPaid[_epoch], "Already paid interest");
        require(msg.value == vault.interestRate() * vault.getPayoutPerReservation(_epoch) / 10_000, "Incorrect payment size");
        openLoan.timesInterestPaid++;
        openLoan.interestPaid[_epoch] = true;
        vault.processFees{value: msg.value}();
    }

    /// @notice Repay an open loan
    /// @param nft NFT Collection address
    /// @param id NFT ID 
    function repay(address nft, uint256 id) external payable nonReentrant {
        Position storage openLoan = loans[nft][id];
        uint256 poolEpoch = (block.timestamp - Vault(payable(openLoan.pool)).startTime()) / 1 days;
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

    /// @notice Liquidate a borrower
    /// @dev A liquidator can check 'getLiqStatus' to see if a user is eligible for liquidation
    /// Liquidation criteria is as follows:
        /// 1. 95% of the pools payout IN THE NEXT EPOCH will not cover the outstanding loan amount
            /// > This can be checked by inputing NFTs currently at auction within the liquidation window
            /// The protocol will calculate the outstanding auction offers and add that to the payout
            /// attributed per NFT and use that to decide the current price point and check whether or not
            /// a users loan is violating the allowed LTV
        /// 2. A borrower is missing 2 or more interest payments
        /// 3. A user does not have an outstanding reservation set IN THE NEXT EPOCH
    /// @param nft NFT Collection address
    /// @param id NFT ID
    /// @param _nfts Set of NFTs currently at auction 
    /// @param _ids Set of NFT IDs currently at auction
    /// @param _closureNonces Corresponding closure nonces of inputted NFTs
    function liquidate(
        address nft, 
        uint256 id, 
        address[] calldata _nfts,
        uint256[] calldata _ids, 
        uint256[] calldata _closureNonces
    ) external nonReentrant {
        Vault vault = Vault(payable(loans[nft][id].pool));
        uint256 loanAmount = loans[nft][id].amount;
        bool violationTracker;
        if(this.getInterestViolation(nft, id)) {
            violationTracker = true;
        } else if(
            !vault.reservationMade(
                (block.timestamp - vault.startTime() + 12 hours) / 1 days,
                nft,
                id
            )
        ) {
            violationTracker = true;
        } else if(this.getPricePointViolation(vault, loanAmount, _nfts, _ids, _closureNonces)) {
            violationTracker = true;
        }
        require(violationTracker, "Liquidation failed");
        processLiquidation(
            vault,
            nft,
            id
        );
    }

    /// @notice Grant a third party transfer permission
    function allowTransferFrom(address nft, uint256 id, address allowee) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(msg.sender == openLoan.borrower, "Not borrower");
        openLoan.transferFromPermission = allowee;
    }

    /// @notice Transfer the ownership of a loan
    /// @dev TRANSFERRING A LOAN WILL ALLOW THE RECIPIENT TO PAY IT OFF AND RECEIVE THE UNDERLYING NFT
    /// @param from The current owner of the loan
    /// @param to The recipient of the loan
    /// @param nft NFT attached to the loan
    /// @param id Corresponding NFT ID attached to the loan
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
    /// @notice Get liquidation status of an open loan
    /// @param nft NFT Collection address
    /// @param id NFT ID
    function getLiqStatus(
        address nft, 
        uint256 id, 
        address[] calldata _nfts,
        uint256[] calldata _ids, 
        uint256[] calldata _closureNonces
    ) external view returns(bool) {
        Vault vault = Vault(payable(loans[nft][id].pool));
        uint256 loanAmount = loans[nft][id].amount;
        if(
            this.getPricePointViolation(vault, loanAmount, _nfts, _ids, _closureNonces)
            || !vault.reservationMade(
                (block.timestamp - vault.startTime() + 12 hours) / 1 days,
                nft,
                id
            )
            || this.getInterestViolation(nft, id)
        ) return true;
        return false;
    }

    /// @notice Calculate the current price point and check for LTV violation
    /// @param vault Vault being used for the loan
    /// @param loanAmount Outstanding loan amount
    /// @param _nfts Set of NFTs at auction
    /// @param _ids Set of NFT IDs at auction
    /// @param _closureNonces Closure nonces of chosen NFTs
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

    /// @notice Check whether or not an existing loan is in violation of missing interest payments
    /// @param nft NFT of outstanding loan
    /// @param id ID of outstanding loan
    function getInterestViolation(
        address nft, 
        uint256 id 
    ) external view returns(bool) {
        Vault vault = Vault(payable(loans[nft][id].pool));
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / 1 days;
        return poolEpoch - loans[nft][id].startEpoch > loans[nft][id].timesInterestPaid + 2;
    }

    /// @notice Get position information regarding -> borrower, pool backing, loan amount
    /// @param nft NFT Collection address
    /// @param id NFT ID
    /// @return borrower Loan borrower
    /// @return pool Pool backing the loan
    /// @return outstandingAmount Loan amount
    function getPosition(
        address nft, 
        uint256 id
    ) external view returns(address borrower, address pool, uint256 outstandingAmount) {
        borrower = loans[nft][id].borrower;
        pool = loans[nft][id].pool;
        outstandingAmount = loans[nft][id].amount;
    }

    function getInterestPayment(uint256 _epoch, address _nft, uint256 _id) external view returns(uint256) {
        Position storage openLoan = loans[_nft][_id];
        Vault vault = Vault(payable(openLoan.pool));
        return vault.interestRate() * vault.getPayoutPerReservation(_epoch) / 10_000;
    }
}