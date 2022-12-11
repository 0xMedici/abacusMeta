//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vault } from "../Vault.sol";

interface ILend {

    /// @notice Borrow against an NFT
    /// @dev Upon borrowing ETH is minted against the value of the backing pool
    /// @param _pool Backing pool address
    /// @param _nft NFT Collection address
    /// @param _id NFT ID 
    /// @param _amount Loan amount
    function borrow(address _pool, address _nft, uint256 _id, uint256 _amount) external;

    /// @notice Pay interest on an outstanding loan
    /// @dev The interest rate is stored on the backing Spot pool contract
    /// @param _epoch Epoch for which a user is paying interest
    /// @param _nft NFT for which a user is paying interest
    /// @param _id Corresponding NFT ID for which a user is paying interest
    function payInterest(uint256[] calldata _epoch, address _nft, uint256 _id) external;

    /// @notice Repay an open loan
    /// @param nft NFT Collection address
    /// @param id NFT ID 
    /// @param _amount repayment amount
    function repay(address nft, uint256 id, uint256 _amount) external;

    /// @notice Liquidate a borrower
    /// @dev A liquidator can check 'getLiqStatus' to see if a user is eligible for liquidation
    /// Liquidation occurs if a user is within the liquidation window of a pool and they have yet to repay their loan
    /// or bring their outstanding amount below 95% the pools value.
    /// @param nft NFT Collection address
    /// @param id NFT ID
    function liquidate(
        address nft, 
        uint256 id
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

    /// @notice Get position information regarding -> borrower, pool backing, loan amount
    /// @param nft NFT Collection address
    /// @param id NFT ID
    /// @return borrower Loan borrower
    /// @return pool Pool backing the loan
    /// @return transferFromPermission address of a user that has permission to transfer loan
    /// @return startEpoch first epoch of the loan
    /// @return amount loan amount outstanding 
    /// @return interestEpoch last epoch that interest was paid
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
    );

    /// @notice Return required interest payment during an epoch
    /// @param _epoch Epoch of interest
    /// @param _nft NFT collection address borrowed against
    /// @param _id NFT ID being borrowed against
    function getInterestPayment(uint256[] calldata _epoch, address _nft, uint256 _id) external view returns(uint256);
}