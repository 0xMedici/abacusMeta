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
    AbacusController public controller;

    /* ======== UINT ======== */
    uint256 public nonce;

    /* ======== MAPPING ======== */
    mapping(uint256 => CurrentAuction) public auctions;

    /* ======== STRUCT ======== */
    struct CurrentAuction {
        bool auctionComplete;
        address currency;
        address highestBidder;
        address nft;
        uint256 id;
        uint256 gracePeriodEndTime;
        uint256 auctionEndTime;
        uint256 nftVal;
        uint256 highestBid;
    }

    /* ======== EVENTS ======== */
    event AuctionStarted(address _token, uint256 _closureNonce);
    event NewBid(address _token, uint256 _closureNonce, address _bidder, uint256 _bid);
    event AuctionEnded(address _currency, address _token, uint256 _closureNonce, address _winner, uint256 _highestBid);
    event NftClaimed(uint256 _closureNonce, address _winner);

    /* ======== CONSTRUCTOR ======== */
    constructor(address _controller) {
        controller = AbacusController(_controller);
        nonce = 1;
    }

    /* ======== AUCTION ======== */
    function updateRiskEquation(
        uint256[] ops
    ) external {
        //TODO: create on risk calculator
    }

    /// SEE IClosure.sol FOR COMMENTS
    function startAuction(address _currency, address _nft, uint256 _id, uint256 _nftVal) external {
        require(controller.accreditedAddresses(msg.sender));
        CurrentAuction storage auction = auctions[nonce];
        auction.nft = _nft;
        auction.id = _id;
        auction.nftVal = _nftVal;
        auction.currency = _currency;
        auction.gracePeriodEndTime = block.timestamp + 6 hours;
        nonce++;
        emit AuctionStarted(_currency, nonce - 1);
    }

    function newGracePeriodBid(
        uint256[] calldata _compPools,
        uint256[] calldata _auctionNonces,
        uint256[] calldata _tickets
    ) external nonReentrant {
        uint256 totalPurchaseCost;
        uint256 prevIndex;
        for(uint256 i = 0; i < _auctionNonces.length; i++) {
            uint256 endIndex = _compPools[i] & (2**96 - 1);
            totalPurchaseCost = _createBid(
                _compPools[i] >> 96,
                _auctionNonces[prevIndex:endIndex],
                _tickets[prevIndex:endIndex]
            );
            _updateProtocol(
                msg.sender,
                _auctionNonces,
                _compPools,
                _tickets[i]
            );
            require(
                ERC20(currency).transferFrom(msg.sender, address(controller.flow()), totalPurchaseCost)
                , "Purchase transfer failed"
            );
        }
    }

    /// SEE IClosure.sol FOR COMMENTS
    function newBid(
        address[] calldata _currency,
        uint256[] calldata _auctionNonces,
        uint256[] calldata _amounts
    ) external nonReentrant {
        uint256 loadedFunds;
        for(uint256 i = 0; i < _auctionNonces.length; i++) {
            uint256 _amount = _amounts[i];
            uint256 _nonce = _auctionNonces[i];
            CurrentAuction storage auction = auctions[_nonce];
            ERC20 token = ERC20(auction.currency);
            require(
                auction.highestGraceBid == 0
                , "Auctioned ended during grace"
            );
            if(
                auction.nftVal != 0
                && auction.auctionEndTime == 0
            ) {
                auction.auctionEndTime = block.timestamp + 24 hours;
            }
            require(
                _amount > 10**token.decimals() / 10000
                , "Min bid must be greater than 0.0001 tokens"
            );
            require(
                _amount > 101 * auction.highestBid / 100
                , "Invalid bid"
            );
            require(
                block.timestamp < auction.auctionEndTime
                , "Time over"
            );
            loadedFunds += _amount;
            if(_currency[i] != (i + 1 < _auctionNonces.length ? _currency[i+1] : address(0))) {
                require(
                    token.transferFrom(msg.sender, address(controller.flow()), loadedFunds)
                    , "Bid transfer failed"
                );
                loadedFunds = 0;
            }
            if(auction.highestBid != 0) {
                controller.flow().updatePendingReturns(
                    auction.highestBidder,
                    address(token),
                    auction.highestBid
                );
            }
            if(_amount == auction.nftVal) {
                auction.auctionEndTime = block.timestamp;
            }
            auction.highestBid = _amount;
            auction.highestBidder = msg.sender;
            emit NewBid(
                address(token),
                _nonce,
                msg.sender,
                _amount
            );
        }
    }

    /// SEE IClosure.sol FOR COMMENTS
    function endAuction(
        uint256[] calldata _nonces
    ) external nonReentrant {
        for(uint256 i = 0; i < _nonces.length; i++) {
            uint256 _nonce = _nonces[i];
            CurrentAuction storage auction = auctions[_nonce];
            Vault vault = Vault(payable(auction.pool));
            require(auction.auctionEndTime != 0, "Invalid auction");
            require(
                block.timestamp > auction.auctionEndTime
                && !auction.auctionComplete,
                "Auction ongoing - EA"
            );
            auction.auctionComplete = true;
            emit AuctionEnded(
                _nonce,
                auction.highestBidder,
                auction.highestBid
            );
        }
    }

    function claimNft(
        uint256[] calldata _nonces
    ) external nonReentrant {
        for(uint256 i = 0; i < _nonces.length; i++) {
            uint256 _nonce = _nonces[i];
            CurrentAuction storage auction = auctions[_nonce];
            require(
                auction.auctionComplete
                , "Auction ongoing - CN"
            );
            IERC721(auction.nft).safeTransferFrom(
                address(this), 
                auction.highestBidder,
                auction.id
            );
            emit NftClaimed(
                auction.pool,
                _nonce,
                auction.highestBidder
            );
        }
    }

    function _createBid(
        address _pool,
        uint256[] calldata _auctionNonces,
        uint256[] calldata _tickets
    ) internal returns(uint256 totalPurchaseCost) {
        for(uint256 i = 0; i < _auctionNonces.length; i++) {
            CurrentAuction storage auction = auctions[_auctionNonces[i]];
            require(auction.currency == address(Vault(_pool).token()));
            totalPurchaseCost += auction.nftVal;
        }
    }

    function _updateProtocol(
        address _user,  
        uint256[] calldata _auctionNonce,
        uint256[] calldata _compPools,
        uint256[] calldata _tickets
    ) internal {
        uint256 prevIndex = 0;
        for(uint256 j = 0; j < _compPools.length; j++) {
            CurrentAuction storage auction = auction[_auctionNonce[i]];
            uint256 netRiskPoints;
            Vault vault = Vault(_compPools[i] >> 96);
            require(
                vault.payoutInfo(_auctionNonce[i]) != 0
                , "Pool not involved"
            );
            uint256 endIndex = _compPools[i] & (2**96 - 1);
            for(uint256 i = prevIndex; i < endIndex; i++) {
                uint256 _amount = vault.position().getTicketsOwned(_user, _tickets[i]);
                uint256 _upperBound = controller.calculator().mockCalculation(pool, _tickets[i]);
                //TODO: create global risk function 
                //TODO: risk calculation = take _upperBoundRisk * _amount
                netRiskPoints += controller.riskCalc().calculateMultiplier(_upperBound) * _amount;
            }
            prevIndex = endIndex;
            require(
                block.timestamp < auction.gracePeriodEndTime
                , "Grace period auction has concluded!"
            );
            require(
                netRiskPoints > auction.highestBidGrace
                , "Must have more risk points than existing bidder!"
            );
            if(auction.highestBidder != address(0)) {
                controller.flow().updatePendingReturns(
                    auction.highestBidder, 
                    auction.currency,
                    auction.nftVal
                );
            }
            auction.highestBid = auction.nftVal;
            auction.auctionEndTime = auction.gracePeriodEndTime;
            auction.highestBidder = _user;
            auction.highestBidGrace = netRiskPoints;
        }
        // emit NewGracePeriodBid(
        //     address(vault), 
        //     address(token),
        //     _nonce, 
        //     address(this),
        //     _nft, 
        //     _id, 
        //     msg.sender, 
        //     netRiskPoints
        // );
    }

    function getAuctionSaleValue(uint256 _nonce) external view returns(uint256) {
        if(auctions[_nonce].auctionComplete) {
            return auctions[_nonce].highestBid;    
        } else {
            return 0;
        }
    }
}