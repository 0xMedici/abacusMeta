//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Vault } from "../Vault.sol";

interface ILend {

    /// @notice Borrow against an NFT
    /// @dev Upon borrowing ETH is minted against the value of the backing pool
    /// @param _pool Backing pool address
    /// @param nft NFT Collection address
    /// @param id NFT ID 
    /// @param _amount Loan amount
    function borrow(address _pool, address nft, uint256 id, uint256 _amount) external;

    /// @notice Pay interest on an outstanding loan
    /// @dev The interest rate is stored on the backing Spot pool contract
    /// @param _epoch Epoch for which a user is paying interest
    /// @param _nft NFT for which a user is paying interest
    /// @param _id Corresponding NFT ID for which a user is paying interest
    function payInterest(uint256 _epoch, address _nft, uint256 _id) external payable;

    /// @notice Repay an open loan
    /// @param nft NFT Collection address
    /// @param id NFT ID 
    function repay(address nft, uint256 id) external payable;

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
    ) external;

    /// @notice Grant a third party transfer permission
    function allowTransferFrom(address nft, uint256 id, address allowee) external;

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
    ) external;

    /// @notice Get liquidation status of an open loan
    /// @param nft NFT Collection address
    /// @param id NFT ID
    function getLiqStatus(
        address nft, 
        uint256 id, 
        address[] calldata _nfts,
        uint256[] calldata _ids, 
        uint256[] calldata _closureNonces
    ) external view returns(bool);

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
    ) external view returns(bool);

    /// @notice Check whether or not an existing loan is in violation of missing interest payments
    /// @param nft NFT of outstanding loan
    /// @param id ID of outstanding loan
    function getInterestViolation(
        address nft, 
        uint256 id 
    ) external view returns(bool);

    /// @notice Get position information regarding -> borrower, pool backing, loan amount
    /// @param nft NFT Collection address
    /// @param id NFT ID
    /// @return borrower Loan borrower
    /// @return pool Pool backing the loan
    /// @return outstandingAmount Loan amount
    function getPosition(
        address nft, 
        uint256 id
    ) external view returns(address borrower, address pool, uint256 outstandingAmount);

    /// @notice Return required interest payment during an epoch
    /// @param _epoch Epoch of interest
    /// @param _nft NFT collection address borrowed against
    /// @param _id NFT ID being borrowed against
    function getInterestPayment(uint256 _epoch, address _nft, uint256 _id) external view returns(uint256);
}