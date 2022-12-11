//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFactory {

    /// @notice Create a Spot pool
    /// @param name Name of the pool
    function initiateMultiAssetVault(
        string memory name
    ) external;

    /// @notice Update the recorded collateral slot count and amount of NFTs in a pool
    /// @param name Name of the pool
    /// @param slots Total amount of collateral slots in the pool
    function updateSlotCount(string memory name, uint32 slots) external;

    /// @notice Update a users pending return count
    /// @dev Pending returns come from funds that need to be returned from
    /// various pool contracts
    /// @param _user The recipient of these returned funds
    function updatePendingReturns(address _token, address _user, uint256 _amount) external;

    /// @notice Claim the pending returns that have been sent for the user
    function claimPendingReturns(address _token) external;

    function emitNftInclusion(
        uint256[] calldata encodedNfts
    ) external;

    function emitPoolBegun(
        uint256 _collateralSlots,
        uint256 _interestRate,
        uint256 _epochLength
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
        uint256 _interestEarned
    ) external;

    function emitNftClosed(
        address _caller,
        uint256 _adjustmentNonce,
        uint256 _auctionNonce,
        address _nft,
        uint256 _id,
        uint256 _payout
    ) external;

    function emitNewBid(
        uint256 _nonce
    ) external;

    function emitAuctionEnded(
        uint256 _nonce
    ) external;

    function emitNftClaimed(
        uint256 _nonce
    ) external;

    function emitPrincipalCalculated(
        address _user,
        uint256 _nonce,
        uint256 _auctionNonce
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