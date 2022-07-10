//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IFactory {

    function initiateMultiAssetVault(
        string memory name
    ) external;

    function updateSlotCount(
        uint256 mavNonce, 
        uint256 slots,
        uint256 amountNfts
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
    ) external;

    function closePool(
        address _pool,
        address[] memory _nft,
        uint256[] memory _ids
    ) external;

    function updatePendingReturns(address _user) external payable;

    function claimPendingReturns() external;

    function emitNftInclusion(uint256[] memory encodedNfts) external;

    function emitPoolBegun() external;

    function emitToggle(
        address _nft,
        uint256 _id,
        bool _chosenToggle, 
        uint256 _totalToggles
    ) external;

    function emitPurchase(
        address _buyer, 
        uint256[] memory tickets,
        uint256[] memory amountPerTicket,
        uint256 nonce,
        uint256 _startEpoch,
        uint256 _finalEpoch
    ) external;

    function emitSaleComplete(
        address _seller,
        uint256 _nonce,
        uint256 _ticketsSold,
        uint256 _creditsPurchased
    ) external;

    function emitGeneralBribe(
        address _briber,
        uint256 _bribeAmount,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external;

    function emitConcentratedBribe(
        address _briber,
        uint256[] memory tickets,
        uint256[] memory bribePerTicket,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external;

    function emitPoolRestored(
        uint256 _payoutPerReservation
    ) external;

    function emitSpotReserved(
        uint256 _reservationId,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external;

    function emitNftClosed(
        address _caller,
        address _nft,
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
        address _user,
        uint256 _nonce
    ) external;

    function emitPayout(
        address _pool,
        address _user,
        uint256 _payoutAmount
    ) external;

    function emitLPTransfer(
        address from,
        address to,
        uint256[] memory tickets,
        uint256[] memory amountPerTicket
    ) external;

    function emitPositionAllowance(
        address from,
        address to
    ) external;

    function encodeCompressedValue(
        address[] memory nft,
        uint256[] memory id
    ) external pure returns(
        uint256[] memory _compTokenInfo
    );

    function decodeCompressedValue(
        uint256 comTickets
    ) external pure returns(
        uint256 stopIndex,
        uint256[10] memory tickets 
    );
}