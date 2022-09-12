//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IFactory {

    /// @notice Create a multi asset vault
    /// @dev The creator will have to pay a creation fee (denominated in ABC)
    /// @param name Name of the pool
    function initiateMultiAssetVault(
        string memory name
    ) external;

    function updateSlotCount(uint256 mavNonce, uint256 slots, uint256 amountNfts) external;

    /// @notice Sign off on starting a vaults emissions
    /// @dev Each NFT can only have its signature attached to one vault at a time
    /// @param multiVaultNonce Nonce corresponding to desired vault
    /// @param nft List of NFTs (must be in the vault and owned by the caller)
    /// @param id List of NFT IDs (must be in the vault and owned by the caller)
    function signMultiAssetVault(
        uint256 multiVaultNonce,
        address[] calldata nft,
        uint256[] calldata id
    ) external;

    /// @notice Sever ties between an NFT and a pool
    /// @dev Only callable by an accredited address (an existing pool)
    /// @param nftToRemove NFT address to be removed
    /// @param idToRemove NFT ID to be removed
    /// @param multiVaultNonce Nonce corresponding to desired vault 
    function updateNftInUse(
        address nftToRemove,
        uint256 idToRemove,
        uint256 multiVaultNonce
    ) external;

    /// @notice Update a users pending return count
    /// @dev Pending returns come from funds that need to be returned from
    /// various pool contracts
    /// @param _user The recipient of these returned funds
    function updatePendingReturns(address _user) external payable;

    /// @notice Claim the pending returns that have been sent for the user
    function claimPendingReturns() external;

    function emitNftInclusion(
        uint256[] calldata encodedNfts
    ) external;

    function emitPoolBegun(uint256 ticketSize) external;

    function emitToggle(
        address _nft,
        uint256 _id,
        bool _chosenToggle, 
        uint256 _totalToggles
    ) external;

    function emitPurchase(
        address _buyer, 
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket,
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
        uint256 _nonce,
        uint256 _closureNonce
    ) external;

    function emitLPTransfer(
        address from,
        address to,
        uint256 nonce
    ) external;

    function emitPositionAllowance(
        address from,
        address to
    ) external;

    function getSqrt(uint x) external pure returns (uint y);

    function encodeCompressedValue(
        address[] calldata nft,
        uint256[] calldata id
    ) external pure returns(
        uint256[] memory _compTokenInfo
    );

    function decodeCompressedValue(
        uint256 _compTokenInfo
    ) external pure returns(address _nft, uint256 _id);

    function decodeCompressedTickets(
        uint256 comTickets
    ) external pure returns(
        uint256 stopIndex,
        uint256[10] memory tickets 
    );



}