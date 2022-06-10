//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVaultFactoryMulti {

    function initiateMultiAssetVault(
        address[] memory _nft, 
        uint256[] memory _id, 
        uint256 amountSlots
    ) external;

    function signMultiAssetVault(
        uint256 multiVaultNonce,
        address[] memory nft,
        uint256[] memory id,
        address boostedCollection
    ) external;

    function updateNftInUse(
        address nftToRemove,
        uint256 idToRemove,
        uint256 multiVaultNonce
    ) external returns(address[] memory newCollections, uint256[] memory newIds);

    function closePool(address _pool, address[] memory nft, uint256[] memory ids) external;

    function updatePendingReturns(address _user) external payable;

    function claimPendingReturns() external;

    function emitPayoutRatioAdjusted(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _user,
        uint256 _ratio
    ) external;

    function emitPurchase(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _buyer, 
        uint256[] memory tickets,
        uint256[] memory amountPerTicket,
        uint256 _startEpoch,
        uint256 _finalEpoch
    ) external;

    function emitSaleComplete(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _seller,
        uint256 _creditsPurchased
    ) external;

    function emitGeneralBribe(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _briber,
        uint256 _bribeAmount,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external;

    function emitConcentratedBribe(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _briber,
        uint256[] memory tickets,
        uint256[] memory bribePerTicket,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external;

    function emitPoolRestored(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        uint256 _payoutPerReservation
    ) external;

    function emitSpotReserved(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        uint256 _reservationId,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external;

    function emitNftClosed(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _caller,
        uint256 _closedId,
        uint256 _payout,
        address _closePoolContract
    ) external;

    function emitNewBid(
        address _pool,
        address _callerToken,
        uint256 _id,
        address _bidder,
        uint256 _bid
    ) external;

    function emitAuctionEnded(
        address _pool,
        address _callerToken,
        uint256 _id,
        address _bidder,
        uint256 _bid
    ) external;

    function emitPrincipalCalculated(
        address _pool,
        address _callerToken,
        uint256 _id,
        address _user
    ) external;

    function emitPayout(
        address _pool,
        address _user,
        uint256 _payoutAmount
    ) external;

    function emitLPTransfer(
        address[] memory _collections,
        uint256[] memory heldIds,
        address from,
        address to,
        uint256[] memory tickets,
        uint256[] memory amountPerTicket
    ) external;

    function emitPositionAllowance(
        address[] memory _collections,
        uint256[] memory heldIds,
        address from,
        address to
    ) external;

    function emitLPInitiated(
        address[] memory _collections,
        uint256[] memory heldIds,
        address initiater
    ) external;
}