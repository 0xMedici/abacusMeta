//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Factory } from "./Factory.sol";
import { Vault } from "./Vault.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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
contract Auction is ReentrancyGuard {
    
    /* ======== ADDRESS ======== */
    Factory public factory;
    AbacusController public controller;

    /* ======== UINT ======== */
    uint256 public nonce;

    /* ======== MAPPING ======== */
    mapping(address => uint256) public liveAuctions;

    mapping(uint256 => CurrentAuction) public auctions; 

    struct CurrentAuction {
        bool auctionComplete;
        address previousOwner;
        address pool;
        address highestBidder;
        address nft;
        uint256 id;
        uint256 auctionEndTime;
        uint256 nftVal;
        uint256 highestBid;
    }

    /* ======== CONSTRUCTOR ======== */
    constructor(address _controller) {
        controller = AbacusController(_controller);
        factory = controller.factory();
        nonce = 1;
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== AUCTION ======== */
    /// SEE IClosure.sol FOR COMMENTS
    function startAuction(address _closer, address _nft, uint256 _id, uint256 _nftVal) external {
        require(controller.accreditedAddresses(msg.sender));
        auctions[nonce].previousOwner = _closer;
        auctions[nonce].nft = _nft;
        auctions[nonce].id = _id;
        auctions[nonce].nftVal = _nftVal;
        auctions[nonce].pool = msg.sender;
        liveAuctions[msg.sender]++;
        nonce++;
    }

    /// SEE IClosure.sol FOR COMMENTS
    function newBid(uint256 _nonce, uint256 _amount) external nonReentrant {
        CurrentAuction storage auction = auctions[_nonce];
        ERC20 token = ERC20(Vault(payable(auction.pool)).token());
        if(
            auction.nftVal != 0
            && auction.auctionEndTime == 0
        ) {
            auction.auctionEndTime = block.timestamp + 10 minutes;
        }
        require(_amount > 10**token.decimals() / 10000, "Min bid must be greater than 0.0001 tokens");
        require(_amount > 101 * auction.highestBid / 100, "Invalid bid");
        require(block.timestamp < auction.auctionEndTime, "Time over");
        require(token.transferFrom(msg.sender, address(this), _amount), "Bid transfer failed");
        if(auction.highestBid != 0) {
            require(token.transfer(address(factory), auction.highestBid), "Bid return failed");    
        }
        factory.updatePendingReturns(
            auction.highestBidder, 
            address(token), 
            auction.highestBid
        );
        auction.highestBid = _amount;
        auction.highestBidder = msg.sender;

        factory.emitNewBid(
            _nonce
        );
    }

    function buyBack(uint256 _nonce) external nonReentrant {
        CurrentAuction storage auction = auctions[_nonce];
        Vault vault = Vault(payable(auction.pool));
        require(msg.sender == auction.previousOwner);
        require(auction.auctionEndTime != 0, "Invalid auction");
        require(
            block.timestamp < auction.auctionEndTime
            && !auction.auctionComplete,
            "Auction complete - EA"
        );
        uint256 cost = auction.highestBid > auction.nftVal ? 11 * auction.highestBid / 10 : 11 * auction.nftVal / 10;
        factory.updatePendingReturns(
            auction.highestBidder, 
            address(vault.token()), 
            auction.highestBid
        );
        auction.highestBid = cost;
        auction.highestBidder = msg.sender;
        vault.token().transferFrom(msg.sender, address(vault), cost);
        vault.updateSaleValue(_nonce, cost);
        auction.auctionComplete = true;
        liveAuctions[auction.pool]--;
        factory.emitAuctionEnded(
            _nonce
        );
    }

    /// SEE IClosure.sol FOR COMMENTS
    function endAuction(uint256 _nonce) external nonReentrant {
        CurrentAuction storage auction = auctions[_nonce];
        Vault vault = Vault(payable(auction.pool));
        ERC20 token = ERC20(vault.token());
        require(auction.auctionEndTime != 0, "Invalid auction");
        require(
            block.timestamp > auction.auctionEndTime
            && !auction.auctionComplete,
            "Auction ongoing - EA"
        );
        vault.updateSaleValue(_nonce, auction.highestBid);
        token.transfer(address(vault), auction.highestBid);
        auction.auctionComplete = true;
        liveAuctions[auction.pool]--;
        factory.emitAuctionEnded(
            _nonce
        );
    }

    function claimNft(uint256 _nonce) external nonReentrant {
        CurrentAuction storage auction = auctions[_nonce];
        require(auction.auctionComplete, "Auction ongoing - CN");
        IERC721(auction.nft).safeTransferFrom(
            address(this), 
            auction.highestBidder,
            auction.id
        );
        factory.emitNftClaimed(
            _nonce
        );
    }
}