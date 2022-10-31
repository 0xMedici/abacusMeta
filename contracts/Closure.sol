//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { IVault } from "./interfaces/IVault.sol";
import { Vault } from "./Vault.sol";
import { IFactory } from "./interfaces/IFactory.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./helpers/ReentrancyGuard.sol";
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

/// @title NFT closure contract
/// @author Gio Medici
/// @notice Operates the post NFT closure auction
contract Closure is ReentrancyGuard, Initializable {
    
    /* ======== ADDRESS ======== */
    IFactory public factory;
    Vault public vault;
    AbacusController public controller;

    /* ======== UINT ======== */
    /// @notice track the amount of ongoing auctions
    uint256 public liveAuctions;

    /* ======== MAPPING ======== */
    /// FOR ALL OF THE FOLLOWING MAPPINGS THE FIRST TWO VARIABLES ARE
    /// [uint256] -> nonce
    /// [address] -> NFT collection address
    /// [uint256] -> NFT ID

    /// @notice Current closure nonce for an NFT
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

    /// @notice track auction completion status
    /// [bool] -> auction completion status
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public auctionComplete;

    /* ======== CONSTRUCTOR ======== */
    function initialize(
        address _vault,
        address _controller
    ) external initializer {
        vault = Vault(payable(_vault));
        controller = AbacusController(_controller);
        factory = IFactory(controller.factory());
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== AUCTION ======== */
    /// SEE IClosure.sol FOR COMMENTS
    function startAuction(uint256 _nftVal, address _nft, uint256 _id) external {
        require(msg.sender == address(vault));
        nonce[_nft][_id]++;
        nftVal[nonce[_nft][_id]][_nft][_id] = _nftVal;
        liveAuctions++;
    }

    /// SEE IClosure.sol FOR COMMENTS
    function newBid(address _nft, uint256 _id) external payable nonReentrant {
        uint256 _nonce = nonce[_nft][_id];
        if(
            nftVal[_nonce][_nft][_id] != 0
            && auctionEndTime[_nonce][_nft][_id] == 0
        ) {
            auctionEndTime[_nonce][_nft][_id] = block.timestamp + 10 minutes;
        }
        require(msg.value > 101 * highestBid[_nonce][_nft][_id] / 100, "Invalid bid");
        require(block.timestamp < auctionEndTime[_nonce][_nft][_id], "Time over");
        factory.updatePendingReturns{ 
            value:highestBid[_nonce][_nft][_id]
        } ( highestBidder[_nonce][_nft][_id] );
        highestBid[_nonce][_nft][_id] = msg.value;
        highestBidder[_nonce][_nft][_id] = msg.sender;

        factory.emitNewBid(
            address(vault),
            _nonce,
            _nft,
            _id,
            msg.sender,
            msg.value
        );
    }

    /// SEE IClosure.sol FOR COMMENTS
    function endAuction(address _nft, uint256 _id) external nonReentrant {
        uint256 _nonce = nonce[_nft][_id];
        require(auctionEndTime[_nonce][_nft][_id] != 0, "Invalid auction");
        require(
            block.timestamp > auctionEndTime[_nonce][_nft][_id]
            && !auctionComplete[_nonce][_nft][_id],
            "Auction ongoing"
        );
        vault.updateSaleValue{value:highestBid[_nonce][_nft][_id]}(_nft, _id, highestBid[_nonce][_nft][_id]);
        auctionComplete[_nonce][_nft][_id] = true;
        liveAuctions--;
        factory.emitAuctionEnded(
            address(vault),
            _nonce,
            _nft,
            _id,
            highestBidder[_nonce][_nft][_id],
            highestBid[_nonce][_nft][_id]
        );
    }

    function claimNft(address _nft, uint256 _id) external nonReentrant {
        uint256 _nonce = nonce[_nft][_id];
        require(auctionComplete[_nonce][_nft][_id], "Auction ongoing");
        IERC721(_nft).transferFrom(
            address(this), 
            highestBidder[_nonce][_nft][_id],
            _id
        );
        factory.emitNftClaimed(
            address(vault),
            _nonce,
            _nft,
            _id,
            msg.sender
        );
    }
}