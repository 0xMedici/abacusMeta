//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./helpers/ReentrancyGuard.sol";
import { AbacusController } from "./AbacusController.sol";
import { ABCToken } from "./AbcToken.sol";
import { IVault } from "./interfaces/IVault.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "hardhat/console.sol";

               //\\                 ||||||||||||||||||||||||||                   //\\                 ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
              ///\\\                |||||||||||||||||||||||||||                 ///\\\                ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
             ////\\\\               |||||||             ||||||||               ////\\\\               ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
            /////\\\\\              |||||||             ||||||||              /////\\\\\              |||||||                       ||||||||            ||||||||  ||||||||||
           //////\\\\\\             |||||||             ||||||||             //////\\\\\\             |||||||                       ||||||||            ||||||||  ||||||||||
          ///////\\\\\\\            |||||||             ||||||||            ///////\\\\\\\            |||||||                       ||||||||            ||||||||  ||||||||||
         ////////\\\\\\\\           ||||||||||||||||||||||||||||           ////////\\\\\\\\           |||||||                       ||||||||            ||||||||  ||||||||||
        /////////\\\\\\\\\          ||||||||||||||                        /////////\\\\\\\\\          |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
       /////////  \\\\\\\\\         ||||||||||||||||||||||||||||         /////////  \\\\\\\\\         |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
      /////////    \\\\\\\\\        |||||||             ||||||||        /////////    \\\\\\\\\        |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
     /////////||||||\\\\\\\\\       |||||||             ||||||||       /////////||||||\\\\\\\\\       |||||||                       ||||||||            ||||||||                    ||||||||||
    /////////||||||||\\\\\\\\\      |||||||             ||||||||      /////////||||||||\\\\\\\\\      |||||||                       ||||||||            ||||||||                    ||||||||||
   /////////          \\\\\\\\\     |||||||             ||||||||     /////////          \\\\\\\\\     |||||||                       ||||||||            ||||||||                    ||||||||||
  /////////            \\\\\\\\\    |||||||             ||||||||    /////////            \\\\\\\\\    ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||
 /////////              \\\\\\\\\   |||||||||||||||||||||||||||    /////////              \\\\\\\\\   ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||
/////////                \\\\\\\\\  ||||||||||||||||||||||||||    /////////                \\\\\\\\\  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||

/// @title Spot pool closure contract
/// @author Gio Medici
/// @notice Executes the post NFT closure operations (auction, principal adjustment)
contract Closure is ReentrancyGuard, Initializable {
    
    /* ======== ADDRESS ======== */

    IFactory public factory;

    IVault public vault;

    AbacusController public controller;

    /* ======== UINT ======== */
    /// @notice track the amount of ongoing auctions
    uint256 public liveAuctions;

    /* ======== MAPPING ======== */
    /// FOR ALL OF THE FOLLOWING MAPPINGS THE FIRST TWO VARIABLES ARE
    /// [uint256] -> nonce
    /// [address] -> NFT collection address
    /// [uint256] -> NFT ID

    mapping(address => mapping(uint256 => uint256)) public nonce;

    /// @notice track the highest bidder in an auction
    /// [address] -> higher bidder
    mapping(uint256 => mapping(address => mapping(uint256 => address))) public highestBidder;

    /// @notice track auction end time
    /// [uint256] -> auction end time 
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public auctionEndTime;

    /// @notice track NFT value ascribed by the pool
    /// [uint256] -> pool ascribed valuation
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public nftVal;

    /// @notice track highest bid in an auction
    /// [uint256] -> highest bid
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public highestBid;

    /// @notice track auction premium (highest bid - pool ascribed value)
    /// [uint256] -> auction premium
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public auctionPremium;

    /// @notice track auction completion status
    /// [bool] -> auction completion status
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public auctionComplete;

    /* ======== CONSTRUCTOR ======== */

    function initialize(
        address _vault,
        address _controller,
        uint256 _version
    ) external initializer {
        vault = IVault(payable(_vault));
        controller = AbacusController(_controller);
        factory = IFactory(controller.factoryVersions(_version));
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}

    /* ======== AUCTION ======== */
    /// @notice Begin auction upon NFT closure
    /// @dev this can only be called by the parent pool
    /// @param _nftVal pool ascribed value of the NFT being auctioned
    /// @param _nft NFT collection address
    /// @param _id NFT ID
    function startAuction(uint256 _nftVal, address _nft, uint256 _id) external {
        require(msg.sender == address(vault));
        uint256 _nonce = nonce[_nft][_id];
        auctionEndTime[_nonce][_nft][_id] = block.timestamp + 12 hours;
        nftVal[_nonce][_nft][_id] = _nftVal;
        liveAuctions++;
        nonce[_nft][_id]++;
    }

    /// @notice Bid in an NFT auction
    /// @dev The previous highest bid is added to a users credit on the parent factory
    /// @param _nft NFT collection address
    /// @param _id NFT ID
    function newBid(address _nft, uint256 _id) external payable nonReentrant {
        uint256 _nonce = nonce[_nft][_id] - 1;
        require(msg.value > 101 * highestBid[_nonce][_nft][_id] / 100);
        require(block.timestamp < auctionEndTime[_nonce][_nft][_id]);
        factory.updatePendingReturns{ 
            value:highestBid[_nonce][_nft][_id]
        } ( highestBidder[_nonce][_nft][_id] );

        highestBid[_nonce][_nft][_id] = msg.value;
        highestBidder[_nonce][_nft][_id] = msg.sender;

        factory.emitNewBid(
            address(vault),
            _nft,
            _id,
            msg.sender,
            msg.value
        );
    }

    /// @notice End an NFT auction
    /// @param _nft NFT collection address
    /// @param _id NFT ID
    function endAuction(address _nft, uint256 _id) external nonReentrant {
        uint256 _nonce = nonce[_nft][_id] - 1;
        require(auctionEndTime[_nonce][_nft][_id] != 0);
        require(
            block.timestamp > auctionEndTime[_nonce][_nft][_id]
            && !auctionComplete[_nonce][_nft][_id]
        );

        if(highestBid[_nonce][_nft][_id] > nftVal[_nonce][_nft][_id]) {
            auctionPremium[_nonce][_nft][_id] = highestBid[_nonce][_nft][_id] - nftVal[_nonce][_nft][_id];
        }
        
        vault.updateSaleValue{value:highestBid[_nonce][_nft][_id]}(_nft, _id, highestBid[_nonce][_nft][_id]);

        auctionComplete[_nonce][_nft][_id] = true;
        IERC721(_nft).transferFrom(
            address(this), 
            highestBidder[_nonce][_nft][_id],
            _id
        );

        liveAuctions--;
        factory.emitAuctionEnded(
            address(vault),
            _nft,
            _id,
            highestBidder[_nonce][_nft][_id],
            highestBid[_nonce][_nft][_id]
        );
    }

    /* ======== GETTERS ======== */
    /// @notice Get the highest bid in the auction for an NFT
    /// @param _nft NFT collection address
    /// @param _id NFT ID 
    function getHighestBid(uint256 _nonce, address _nft, uint256 _id) external view returns(uint256 bid) {
        bid = highestBid[_nonce][_nft][_id];
    }

    /// @notice Get the auction premium (auction sale - ascribed pool value) of an NFT
    /// @param _nft NFT collection address
    /// @param _id NFT ID 
    /// @return premium Auction premium
    function getAuctionPremium(uint256 _nonce, address _nft, uint256 _id) external view returns(uint256 premium) {
        premium = auctionPremium[_nonce][_nft][_id];
    }

    /// @notice Get the auction end time of an NFT 
    /// @param _nft NFT collection address
    /// @param _id NFT ID 
    /// @return endTime Auction end time
    function getAuctionEndTime(uint256 _nonce, address _nft, uint256 _id) external view returns(uint256 endTime) {
        endTime = auctionEndTime[_nonce][_nft][_id];
    }

    /// @notice Get the number of live auctions
    /// @return _liveAuctions Amount of live auctions
    function getLiveAuctionCount() external view returns(uint256 _liveAuctions) {
        _liveAuctions = liveAuctions;
    }
}