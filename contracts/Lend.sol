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
    /// [borrower] user
    /// [pool] backing pool
    /// [amount] loan amount
    struct Position {
        address borrower;
        address pool;
        address transferFromPermission;
        uint256 startEpoch;
        uint256 amount;
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
    /// @dev Upon borrowing NFT ETH is minted against the value of the backing pool
    /// @param _pool Backing pool address
    /// @param nft NFT Collection address
    /// @param id NFT ID 
    /// @param _amount Loan amount
    function borrow(address _pool, address nft, uint256 id, uint256 _amount) external nonReentrant {
        require(controller.accreditedAddresses(_pool));
        Position storage openLoan = loans[nft][id];
        Vault vault = Vault(payable(_pool));
        require(
            msg.sender == IERC721(nft).ownerOf(id)
            || msg.sender == openLoan.borrower
        );
        if(openLoan.amount == 0) {
            IERC721(nft).transferFrom(msg.sender, address(this), id);
        }
        require(
            95 * vault.getPayoutPerReservation((block.timestamp - Vault(payable(_pool)).startTime()) / 1 days) 
                / 100 >= (_amount + openLoan.amount)
        );
        require(
            vault.reservationMade(
                (block.timestamp - Vault(payable(_pool)).startTime()) / 1 days,
                nft,
                id
            )
        );
        require(
            vault.reservationMade(
                (block.timestamp - Vault(payable(_pool)).startTime() + 12 hours) / 1 days,
                nft,
                id
            )
        );
        require(
            (block.timestamp - Vault(payable(_pool)).startTime()) / 1 days 
            == (block.timestamp - Vault(payable(_pool)).startTime() + 12 hours) / 1 days
        );
        uint256 payoutPerResFuture = 
            vault.getPayoutPerReservation((block.timestamp - Vault(payable(_pool)).startTime() + 12 hours) / 1 days);
        require(95 * payoutPerResFuture / 100 >= _amount + openLoan.amount);
        if(!loanDeployed[nft][id]) {
            openLoan.pool = _pool;
            openLoan.amount = _amount;
            openLoan.borrower = msg.sender;
            loanDeployed[nft][id] = true;
        } else {
            openLoan.amount += _amount;
        }
        vault.accessLiq(msg.sender, nft, id, _amount);
        emit EthBorrowed(msg.sender, _pool, nft, id, _amount);
    }

    function payInterest(uint256 _epoch, address _nft, uint256 _id) external payable {
        Position storage openLoan = loans[_nft][_id];
        Vault vault = Vault(payable(openLoan.pool));
        uint256 poolEpoch = (vault.startTime() - block.timestamp) / 1 days;
        require(_epoch <= poolEpoch);
        require(!openLoan.interestPaid[_epoch]);
        require(msg.value == vault.interestRate() * vault.getPayoutPerReservation(_epoch) / 10_000);
        openLoan.interestPaid[_epoch] = true;
        vault.processFees{value: msg.value}();
    }

    /// @notice Repay an open loan
    /// @param nft NFT Collection address
    /// @param id NFT ID 
    function repay(address nft, uint256 id) external payable nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(msg.sender == openLoan.borrower);
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
        /// 2. Upon liquidation the liquidator receives (5 - vault closure fee)% of the payout
    /// On liquidation the lending contract closes the pool and refills the outstanding NFT ETH
    /// @param nft NFT Collection address
    /// @param id NFT ID
    function liquidate(
        address nft, 
        uint256 id, 
        address[] calldata _nfts,
        uint256[] calldata _ids, 
        uint256[] calldata _epochs,
        uint256[] calldata _closureNonces
    ) external nonReentrant {
        Vault vault = Vault(payable(loans[nft][id].pool));
        uint256 loanAmount = loans[nft][id].amount;
        require(
            this.getPricePointViolation(vault, loanAmount, _nfts, _ids, _closureNonces)
            || !vault.reservationMade(
                (block.timestamp - vault.startTime() + 12 hours) / 1 days,
                nft,
                id
            )
            || this.getInterestViolation(nft, id, _epochs)
        );
        processLiquidation(
            vault,
            nft,
            id
        );
    }

    function allowTransferFrom(address nft, uint256 id, address allowee) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(msg.sender == openLoan.borrower);
        openLoan.transferFromPermission = allowee;
    }

    function transferFromLoanOwnership(
        address from,
        address to, 
        address nft, 
        uint256 id
    ) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(
            msg.sender == openLoan.borrower
            || openLoan.transferFromPermission == msg.sender
        );
        openLoan.borrower = to;
        emit LoanTransferred(openLoan.pool, from, to, nft, id);
    }

    function processLiquidation(
        Vault vault,
        address nft,
        uint256 id
    ) internal {
        uint256 loanAmount = loans[nft][id].amount;
        uint256 payoutPerResCurrent = 
            vault.getPayoutPerReservation((block.timestamp - vault.startTime()) / 1 days);
        IERC721(nft).approve(address(vault), id);
        vault.closeNft(nft, id);
        payable(msg.sender).transfer((payoutPerResCurrent - loanAmount) / 100);
        vault.processFees{value: payoutPerResCurrent - loanAmount - ((payoutPerResCurrent - loanAmount) / 100)}();
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
        uint256[] calldata _epochs,
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
            || this.getInterestViolation(nft, id, _epochs)
        ) return true;
        return false;
    }

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
                totalBids / _nfts.length 
                + (
                    vault.getPayoutPerReservation((block.timestamp - vault.startTime() + 12 hours) / 1 days)
                ) / vault.reservationsAvailable()
            ) / 100 <= loanAmount 
        );
    }

    function getInterestViolation(
        address nft, 
        uint256 id, 
        uint256[] calldata _epochs
    ) external view returns(bool) {
        Vault vault = Vault(payable(loans[nft][id].pool));
        uint256 interestViolationTracker;
        for(uint256 j; j < _epochs.length; j++) {
            require(
                _epochs[j] >= loans[nft][id].startEpoch 
                && _epochs[j] < (block.timestamp - vault.startTime()) / 1 days
            );
            if(!loans[nft][id].interestPaid[_epochs[j]]) {
                interestViolationTracker++;
            }
        }
        return interestViolationTracker >= 2;
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
}