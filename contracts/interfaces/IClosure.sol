//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IClosure {
    function initialize(
        address _vault,
        address _controller,
        uint256 _version
    ) external;

    function startAuction(uint256 _nftVal, address _nft, uint256 _id) external;

    function newBid(address _nft, uint256 _id) external payable;

    function endAuction(address _nft, uint256 _id) external;

    function calculatePrincipal(address _user, uint256 _nonce, address _nft, uint256 _id) external;

    function getHighestBid(address _nft, uint256 _id) external view returns(uint256 bid);

    function getAuctionPremium(address _nft, uint256 _id) external view returns(uint256 premium);

    function getAuctionEndTime(address _nft, uint256 _id) external view returns(uint256 endTime);

    function getLiveAuctionCount() external view returns(uint256 _liveAuctions);
}