//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IVaultFactory {

    function updatePendingReturns(address _user) payable external;

    function getVaultAddress(address nft, uint256 id) view external returns(address vaultAddress);

    function emitEmissionSigning(
        address _callerToken,
        uint256 _callerId,
        address _signer
    ) external;

    function emitTokenPurchase(
        address _callerToken,
        uint256 _callerId,
        address _buyer,
        uint256 ticket,
        uint256 amount,
        uint256 _lockTime
    ) external;

    function emitTokenSale(
        address _callerToken,
        uint256 _callerId,
        address _seller, 
        uint256 ticket
    ) external;

    function emitSaleComplete(
        address _callerToken,
        uint256 _callerId,
        address _seller,
        uint256 creditsPurchased
    ) external;

    function emitPendingOrderSubmitted(
        address _callerToken, 
        uint256 _callerId,
        address _buyer,
        uint256 ticket,
        uint256 executorReward
    ) external;

    function emitFeeRedemption(
        address _callerToken,
        uint256 _callerId,
        uint256 toVeHolders
    ) external;

    function emitPoolClosure(
        address _callerToken,
        uint256 _callerId,
        uint256 _finalVal, 
        address _closePoolContract, 
        address _vault 
    ) external;

    function emitNewBid(
        address _callerToken,
        uint256 _callerId,
        uint256 _bid,
        address _bidder,
        address _closePoolContract,
        address _vault
    ) external;

    function emitAuctionEnded(
        address _callerToken,
        uint256 _callerId,
        uint256 _finalVal,
        uint256 _auctionVal,
        address _closePoolContract,
        address _vault
    ) external;

    function emitAccountClosed(
        address _callerToken,
        uint256 _callerId,
        uint256 _finalVal,
        uint256 _auctionVal,
        uint256 _payoutCredits,
        uint256 _payoutEth,
        address _closePoolContract,
        address _vault
    ) external;
}