//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IClosePool {
    function initialize(
        address _vault,
        address _controller,
        address _heldToken,
        uint256 _heldId,
        uint256 _nftVal,
        uint256 _version
    ) external;

    function newBid() payable external;

    function endAuction() external;

    function calculatePrincipal(address _user) external;

    function payout(address _user, uint256 payoutAmount) external;

    function getAuctionPremium() view external returns(uint256 premium);

    function getAuctionEndTime() view external returns(uint256 endTime);

    
}