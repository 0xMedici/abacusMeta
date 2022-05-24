//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IClosePoolMulti {
    function initialize(
        address _vault,
        address _controller,
        address _heldCollection,
        uint256 _version
    ) external;

    function startAuction(uint256 _nftVal, uint256 _id) external;

    function newBid(uint256 _id) payable external;

    function reclaimBid(uint256 _id) external;

    function endAuction(uint256 _id) external;

    function calculatePrincipal(uint256 _id) external;

    function payout(address _user, uint256 payoutAmount) external;

    function getLiveAuctionCount() view external returns(uint256 _liveAuctions);

    function getAuctionPremium(uint256 _id) view external returns(uint256 premium);

    function getAuctionEndTime(uint256 _id) view external returns(uint256 endTime);
}