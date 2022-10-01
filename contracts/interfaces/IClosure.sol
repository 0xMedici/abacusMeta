//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    function newBid(address _nft, uint256 _id) external payable;

    /// @notice End an NFT auction
    /// @param _nft NFT collection address
    /// @param _id NFT ID
    function endAuction(address _nft, uint256 _id) external;

    /// @notice Get the highest bid in the auction for an NFT
    /// @param _nft NFT collection address
    /// @param _id NFT ID 
    function getHighestBid(uint256 _nonce, address _nft, uint256 _id) external view returns(uint256 bid);

    /// @notice Get the auction premium (auction sale - ascribed pool value) of an NFT
    /// @param _nft NFT collection address
    /// @param _id NFT ID 
    /// @return premium Auction premium
    function getAuctionPremium(uint256 _nonce, address _nft, uint256 _id) external view returns(uint256 premium);

    /// @notice Get the auction end time of an NFT 
    /// @param _nft NFT collection address
    /// @param _id NFT ID 
    /// @return endTime Auction end time
    function getAuctionEndTime(uint256 _nonce, address _nft, uint256 _id) external view returns(uint256 endTime);

    /// @notice Get the number of live auctions
    /// @return _liveAuctions Amount of live auctions
    function getLiveAuctionCount() external view returns(uint256 _liveAuctions);
}