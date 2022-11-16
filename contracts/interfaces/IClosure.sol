//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IClosure {

    function initialize(
        address _vault,
        address _controller
    ) external;

    /// @notice Begin auction upon NFT closure
    /// @dev this can only be called by the parent pool
    /// @param _nftVal pool ascribed value of the NFT being auctioned
    /// @param _nft NFT collection address
    /// @param _id NFT ID
    function startAuction(uint256 _nftVal, address _nft, uint256 _id) external;

    /// @notice Bid in an NFT auction
    /// @dev The previous highest bid is added to a users credit on the parent factory
    /// @param _nft NFT collection address
    /// @param _id NFT ID
    function newBid(address _nft, uint256 _id, uint256 _amount) external;

    /// @notice End an NFT auction
    /// @param _nft NFT collection address
    /// @param _id NFT ID
    function endAuction(address _nft, uint256 _id) external;

    function claimNft(address _nft, uint256 _id) external;
}