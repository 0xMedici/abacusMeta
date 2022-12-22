//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Auction } from "./Auction.sol";
import { Factory } from "./Factory.sol";
import { Position } from "./Position.sol";
import { RiskPointCalculator } from "./RiskPointCalculator.sol";
import { TrancheCalculator } from "./TrancheCalculator.sol";
import { BitShift } from "./helpers/BitShift.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import "./helpers/ReentrancyGuard.sol";
import "./helpers/ReentrancyGuard2.sol";
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

/// @title Spot pool
/// @author Gio Medici
/// @notice Spot pools allow users to collateralize any combination of NFT collections and IDs
contract Vault is ReentrancyGuard, ReentrancyGuard2, Initializable {

    /* ======== CONTRACTS ======== */
    Factory factory;
    AbacusController controller;
    RiskPointCalculator riskCalc;
    TrancheCalculator trancheCalc;
    Auction auction;
    Position positionManager;

    ERC20 public token;

    /* ======== ADDRESSES ======== */
    address creator;

    /* ======== STRINGS ======== */
    string name;

    /* ======== UINT ======== */
    uint256 creatorFee;
    uint256 spotsRemoved;
    uint256 reservations;

    uint256 public modTokenDecimal;

    uint256 public liquidationRule;

    uint256 public resetEpoch;

    uint256 public epochLength;

    /// @notice Interest rate that the pool charges for usage of liquidity
    uint256 public interestRate;

    /// @notice Total amount of slots to be collateralized
    uint256 public amountNft;

    /// @notice Pool creation time
    uint256 public startTime;

    /// @notice Total amount of adjustments required (every time an NFT is 
    /// closed this value increments)
    uint256 public adjustmentsRequired;

    /* ======== MAPPINGS ======== */
    mapping(uint256 => bool) nftClosed;
    mapping(uint256 => uint256) adjustmentNonce;
    mapping(uint256 => uint256) loss;
    mapping(uint256 => uint256) epochOfClosure;
    mapping(uint256 => uint256) payoutInfo;
    mapping(uint256 => uint256) auctionSaleValue;
    mapping(uint256 => uint256) compressedEpochVals;
    mapping(uint256 => uint256[]) ticketsPurchased;
    mapping(address => mapping(uint256 => uint256)) tokenMapping;

    /// @notice A users position nonce
    /// [address] -> User address
    /// [uint256] -> Next nonce value 
    mapping(address => uint256) public positionNonce;

    /// @notice Payout size for each reservation during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> payout size
    mapping(uint256 => uint256) public epochEarnings;

    /// @notice Tracking the adjustments made by each user for each open nonce
    /// [address] -> user
    /// [uint256] -> nonce
    /// [uint256] -> amount of adjustments made
    mapping(uint256 => uint256) public adjustmentsMade;

    /// @notice Track an addresses allowance status to trade another addresses position
    /// [address] allowance recipient
    mapping(uint256 => address) public allowanceTracker;

    /// @notice Track a traders profile for each nonce
    /// [address] -> user
    /// [uint256] -> nonce
    mapping(uint256 => Buyer) public traderProfile;

    /// @notice Track adjustment status of closed NFTs
    /// [address] -> User 
    /// [uint256] -> nonce
    /// [address] -> NFT collection
    /// [uint256] -> NFT ID
    /// [bool] -> Status of adjustment
    mapping(uint256 => mapping(uint256 => bool)) public adjustCompleted;

    /// @notice Tracks the amount of liquidity that has been accessed on behalf of an NFT
    /// [address] -> NFT collection address
    /// [uint256] -> NFT ID
    mapping(address => mapping(uint256 => uint256)) public liqAccessed;
    
    /* ======== STRUCTS ======== */
    /// @notice Holds core metrics for each trader
    /// [active] -> track if a position is closed
    /// [multiplier] -> the multiplier applied to a users credit intake when closing a position
    /// [startEpoch] -> epoch that the position was opened
    /// [unlockEpoch] -> epoch that the position can be closed
    /// [comListOfTickets] -> compressed (using bit shifts) value containing the list of tranches
    /// [comAmountPerTicket] -> compressed (using bit shifts) value containing the list of amounts
    /// of tokens purchased in each tranche
    /// [ethLocked] -> total amount of eth locked in the position
    struct Buyer {
        bool active;
        uint32 startEpoch;
        uint32 unlockEpoch;
        uint32 riskStart;
        uint32 riskPoints;
        uint32 riskLost;
        uint32 riskStartLost;
        uint128 tokensLocked;
        uint128 tokensStatic;
        uint128 tokensLost;
        address owner;
        uint256 comListOfTickets;
        uint256 comAmountPerTicket;
    }

    /* ======== EVENTS ======== */
    event NftInclusion(address[] nfts, uint256[] ids);
    event VaultBegun(address _token, uint256 _collateralSlots, uint256 _interest, uint256 _epoch);
    event Purchase(address _buyer, uint256[] tickets, uint256[] amountPerTicket, uint256 nonce, uint256 startEpoch, uint256 finalEpoch);
    event SaleComplete(address _seller, uint256 nonce, uint256 ticketsSold, uint256 creditsPurchased);
    event NftClosed(uint256 _adjustmentNonce, uint256 _closureNonce, address _collection, uint256 _id, address _caller, uint256 payout, address closePoolContract); 
    event LPTransferAllowanceChanged(address from, address to);
    event LPTransferred(address from, address to, uint256 nonce);
    event PrincipalCalculated(address _closePoolContract, address _user, uint256 _nonce, uint256 _closureNonce);

    /* ======== CONSTRUCTOR ======== */
    function initialize(
        string memory _name,
        address _controller,
        address _creator
    ) external initializer {
        controller = AbacusController(_controller);
        factory = controller.factory();
        require(_creator != address(0));
        creator = _creator;
        name = _name;
        auction = Auction(controller.auction());
        riskCalc = controller.riskCalculator();
        trancheCalc = controller.calculator();
        adjustmentsRequired = 1;
    }

    /* ======== CONFIGURATION ======== */
    /** 
    Error codes:
        NC - msg.sender not the creator (caller incorrect)
        AS - pool already started
        NO - NFTs with no owner are allowed
        AM - Already included (there exists a duplicate NFT submission)
    */
    function includeNft(
        address[] calldata _collection,
        uint256[] calldata _id
    ) external {
        require(
            startTime == 0
            // , "AS"
        );
        require(
            msg.sender == creator
            // , " NC"
        );
        uint256 length = _collection.length;
        for(uint256 i = 0; i < length; i++) {
            address collection = _collection[i];
            uint256 id = _id[i];
            require(
                IERC721(collection).ownerOf(id) != address(0)
                // , " NO"
            );
            require(
                (tokenMapping[collection][id / 250] & 2**(id % 250) == 0)
                // , " AM"
            );
            tokenMapping[collection][id / 250] |= 2**(id % 250);
        }
        emit NftInclusion(_collection, _id);
    }

    function setEquations(
        uint256[] calldata risk,
        uint256[] calldata tranche
    ) external {
        riskCalc.setMetrics(
            risk
        );
        trancheCalc.setMetrics(
            tranche
        );
    }

    /** 
    Error codes:
        NC - msg.sender not the creator (caller incorrect)
        AS - pool already started
        TTL - ticket size too low (min 10)
        TTH - ticket size too high (max 100000) 
        RTL - interest rate too low (min 10)
        RTH - interest rate too high (max 500000)
        ITSC - invalid ticket and slot count entry (max ticketSize * slot is 2^25)
        TLS - too little slots (min 1)
        TMS - too many slots (max 2^32)
        IRB - invalid risk base (min 11, max 999)
        IRS - invalid risk step (min 2, max 999)
    */
    function begin(
        uint32 _slots,
        uint256 _rate,
        uint256 _epochLength,
        address _token,
        uint256 _creatorFee,
        uint256 _liquidationRule
    ) external {
        require(
            _epochLength >= 2 minutes 
            && _epochLength <= 2 weeks
            // , " Out of time bounds"
        );
        require(
            msg.sender == creator
            // , " NC"
        );
        require(
            startTime == 0
            // , " AS"
        );
        require(
            _rate > 10
            // , " RTS"
        );
        require(
            _rate < 500000
            // , " RTH"
        );
        require(
            _slots > 0
            // , " TLS"
        );
        require(
            _slots < 2**32
            // , " TMS"
        );
        require(
            _creatorFee < 100
            // , " CFH"
        );
        require(
            ERC20(_token).decimals() > 3
        );
        epochLength = _epochLength;
        amountNft = _slots;
        interestRate = _rate;
        startTime = block.timestamp;
        token = ERC20(_token);
        modTokenDecimal = 10**ERC20(_token).decimals() / 1000;
        creatorFee = _creatorFee;
        liquidationRule = _liquidationRule;
        emit VaultBegun(address(token), _slots, _rate, _epochLength);
    }

    /* ======== TRADING ======== */
    /** 
    Error codes:
        NS - pool hasn’t started yet
        II - invalid input (ticket length and amount per ticket length don’t match up)
        PTL - position too large (tried to purchase from too many tickets at once, max 100)
        IT - invalid startEpoch submission
        TS - lock time too short (finalEpoch needs to be more than 1 epoch greater than startEpoch)
        TL -  lock time too long (finalEpoch needs to be at most 10 epochs greater than startEpoch)
        ITA - invalid ticket amount (ticket amount submission cannot equal 0)
        TLE - ticket limit exceeded (this purchase will exceed the ticket limit of one of the chosen tranches)
    */
    function purchase(
        address _buyer,
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint32 startEpoch,
        uint32 finalEpoch
    ) external nonReentrant {
        require(tickets.length >= 1);
        require(
            startTime != 0
            // , " NS"
        );
        require(
            tickets.length == amountPerTicket.length
            // , " II"
        );
        require(
            tickets.length <= 100
            // , " PTL"
        );
        require(
            startEpoch == (block.timestamp - startTime) / epochLength
            // , " IT"
        );
        require(
            finalEpoch - startEpoch > 1
            // , " TS"
        );
        require(
            finalEpoch - startEpoch <= 10
            // , " TL"
        );
        uint256 totalTokensRequested;
        uint256 largestTicket;
        uint256 riskStart;
        uint256 riskNorm;
        (largestTicket, riskNorm) = positionManager.createPosition(
            _buyer,
            tickets, 
            amountPerTicket,
            startEpoch,
            finalEpoch
        );
        // for(uint256 i = 0; i < tickets.length / 10 + 1; i++) {
        //     if(tickets.length % 10 == 0 && i == tickets.length / 10) break;
        //     uint256 tempVal;
        //     uint256 upperBound;
        //     if(10 + i * 10 > tickets.length) {
        //         upperBound = tickets.length;
        //     } else {
        //         upperBound = 10 + i * 10;
        //     }
        //     tempVal = choppedPosition(
        //         _buyer,
        //         tickets[0 + i * 10:upperBound],
        //         amountPerTicket[0 + i * 10:upperBound],
        //         startEpoch,
        //         finalEpoch
        //     );
        //     riskNorm += tempVal & (2**32 - 1);
        //     tempVal >>= 32;
        //     riskStart += tempVal & (2**32 - 1);
        //     tempVal >>= 32;
        //     if(tempVal > largestTicket) largestTicket = tempVal;
        // }
        riskNorm <<= 128;
        riskNorm |= riskStart;
        totalTokensRequested = updateProtocol(
            largestTicket,
            startEpoch,
            finalEpoch,
            tickets,
            amountPerTicket,
            riskNorm
        );
        require(token.transferFrom(msg.sender, address(this), totalTokensRequested * modTokenDecimal));
    }

    /** 
    Error codes:
        IC - improper caller (caller doesn’t own the position)
        PC - Position closed (users already closed their position)
        ANM - Proper adjustments have not been made (further adjustments required before being able to close)
        PNE - Position non-existent (no position exists with this nonce)
        USPE - Unable to sell position early (means the pool is in use)
    */
    function sell(
        uint256 _nonce
    ) external nonReentrant returns(uint256 interestEarned) {
        Buyer storage trader = traderProfile[_nonce];
        require(
            msg.sender == trader.owner
            // , " IC"
        );
        require(
            trader.active
            // , " PC"
        );
        require(
            adjustmentsMade[_nonce] == adjustmentsRequired
            // , " ANM"
        );
        require(
            trader.unlockEpoch != 0
            // , " PNE"
        );
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        uint256 finalEpoch;
        uint256 interestLost;
        if(poolEpoch >= trader.unlockEpoch) {
            finalEpoch = trader.unlockEpoch;
        } else {
            require(
                reservations == 0
                // , " USPE"
            );
            finalEpoch = poolEpoch;
        }
        for(uint256 j = trader.startEpoch; j < finalEpoch; j++) {
            uint256 riskPoints = this.getRiskPoints(j);
            if(j == trader.startEpoch) {
                interestLost = (trader.riskStart > trader.riskStartLost ? trader.riskStartLost : trader.riskStart) * epochEarnings[j] / riskPoints; 
                interestEarned = (trader.riskStart > trader.riskStartLost ? (trader.riskStart - trader.riskStartLost) : 0) * epochEarnings[j] / riskPoints;
            } else {
                interestLost = (trader.riskPoints > trader.riskLost ? trader.riskLost : trader.riskPoints) * epochEarnings[j] / riskPoints; 
                interestEarned = (trader.riskPoints > trader.riskLost ? (trader.riskPoints - trader.riskLost) : 0) * epochEarnings[j] / riskPoints;
            }
        }
        if(poolEpoch < trader.unlockEpoch) {
            for(poolEpoch; poolEpoch < trader.unlockEpoch; poolEpoch++) {
                uint256[] memory epochTickets = ticketsPurchased[poolEpoch];
                uint256 comTickets = trader.comListOfTickets;
                uint256 comAmounts = trader.comAmountPerTicket;
                while(comAmounts > 0) {
                    uint256 ticket = comTickets & (2**25 - 1);
                    uint256 amount = (comAmounts & (2**25 - 1)) / 100;
                    comTickets >>= 25;
                    comAmounts >>= 25;
                    uint256 temp = this.getTicketInfo(poolEpoch, ticket);
                    temp -= amount;
                    epochTickets[ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1) 
                        - (2**(((ticket % 10))*25) - 1));
                    epochTickets[ticket / 10] |= (temp << ((ticket % 10)*25));
                }
                ticketsPurchased[poolEpoch] = epochTickets;
                uint256 tempComp = compressedEpochVals[poolEpoch];
                uint256 prevPosition;
                prevPosition += 35;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 51) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 35) & (2**51 -1)) 
                                - (trader.startEpoch == poolEpoch ? trader.riskStart : trader.riskPoints)
                            ) << prevPosition
                        );
                prevPosition += 135;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 170) & (2**84 -1)) 
                                - trader.tokensStatic
                            ) << prevPosition
                        );
                compressedEpochVals[poolEpoch] = tempComp;
            }
        }
        emit SaleComplete(
            msg.sender,
            _nonce,
            trader.comListOfTickets,
            interestEarned
        );
        token.transfer(controller.multisig(), trader.tokensLost + interestLost);
        token.transfer(msg.sender, trader.tokensLocked + interestEarned);
        delete traderProfile[_nonce].active;
    }

    /* ======== POSITION MOVEMENT ======== */
    function changeTransferPermission(
        address recipient,
        uint256 _nonce
    ) external nonReentrant returns(bool) {
        require(traderProfile[_nonce].owner == msg.sender);
        allowanceTracker[_nonce] = recipient;
        emit LPTransferAllowanceChanged(
            msg.sender,
            recipient
        );
        return true;
    }

    /** 
    Error chart:
        IC - invalid caller (caller is not the owner or doesn’t have permission)
        MAP - must adjust position (positions must be fully adjusted before being traded)
    */
    function transferFrom(
        address from,
        address to,
        uint256 nonce
    ) external nonReentrant returns(bool) {
        require(
            msg.sender == allowanceTracker[nonce]
            || msg.sender == traderProfile[nonce].owner
            // , " IC"
        );
        traderProfile[nonce].owner = to;
        delete allowanceTracker[nonce];
        emit LPTransferred(from, to, nonce);
        return true;
    }

    /* ======== POOL CLOSURE ======== */
    /** 
    Error chart: 
        TNA - token non-existent (chosen NFT to close does not exist in the pool) 
        PE0 - payout equal to 0 (payout must be greater than 0 to close an NFT) 
        NRA - no reservations available (all collateral spots are in use currently so closure is unavailable)
        TF - Transfer failed (transferring the NFT has failed so closure reverted)
    */
    function closeNft(address _nft, uint256 _id) external nonReentrant2 returns(uint256) {
        require(
            this.getHeldTokenExistence(_nft, _id)
            // , " TNA"
        );
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        uint256 nonce = auction.nonce();
        adjustmentsRequired++;
        adjustmentNonce[nonce] = adjustmentsRequired;
        uint256 ppr = this.getPayoutPerReservation(poolEpoch);
        require(
            ppr != 0
            // , " PE0"
        );
        epochOfClosure[nonce] = poolEpoch;
        uint256 temp = ppr;
        temp <<= 128;
        temp |= this.getRiskPoints(poolEpoch);
        payoutInfo[nonce] = temp;
        uint256 payout = 1 * ppr / 100;
        epochEarnings[poolEpoch] += (950 - creatorFee) * payout / 100;
        token.transfer(address(factory), creatorFee * payout / 1000);
        factory.updatePendingReturns(
            address(token),
            creator,
            creatorFee * payout / 1000
        );
        token.transfer(controller.multisig(), 5 * payout / 100);
        token.transfer(msg.sender, ppr - payout - liqAccessed[_nft][_id]);
        nftClosed[poolEpoch] = true;
        if(liqAccessed[_nft][_id] == 0) {
            require(
                this.getReservationsAvailable() > 0
                // , " NRA"
            );
        } else {
            delete liqAccessed[_nft][_id];
            reservations--;
        }
        spotsRemoved++;
        auction.startAuction(msg.sender, _nft, _id, ppr);
        IERC721(_nft).transferFrom(msg.sender, address(auction), _id);
        require(
            IERC721(_nft).ownerOf(_id) == address(auction)
        );
        emit NftClosed(
            adjustmentsRequired,
            nonce,
            _nft,
            _id,
            msg.sender, 
            ppr, 
            address(auction)
        );
        return(ppr - payout);
    }

    /** 
        Error chart:
            IC - invalid caller
    */
    function updateSaleValue(
        uint256 _nonce,
        uint256 _saleValue
    ) external payable nonReentrant {
        require(
            msg.sender == address(auction)
        );
        uint256 poolEpoch = epochOfClosure[_nonce];
        auctionSaleValue[_nonce] = _saleValue;
        if((payoutInfo[_nonce] >> 128) > _saleValue) {
            while(this.getTotalAvailableFunds(poolEpoch) > 0) {
                poolEpoch++;
            }
            if(poolEpoch > resetEpoch) {
                resetEpoch = poolEpoch;
            }
        } else {
            spotsRemoved--;
        }
    }

    /** 
    Error chart:
        AOG - auction is ongoing (can only restore with no auctions ongoing)
        NTY - not time yet (the current pool epoch is not yet at the allowed reset epoch) 
        RNN - restoration not needed (there is no need to restore the pool currently)
    */
    function restore() external nonReentrant {
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        require(
            auction.liveAuctions(address(this)) == 0
            // , " AOG"
        );
        require(
            poolEpoch >= resetEpoch
            // , " NTY"
        );
        require(
            spotsRemoved != 0
            // , " RNN"
        );
        delete spotsRemoved;
    }

    /* ======== ACCOUNT CLOSURE ======== */
    /**
    Error chart: 
        AA - already adjusted (this closure has already been adjusted for) 
        AU - adjustments up to date (no more adjustments currently needed for this position)
        AO - auction ongoing (there is a auction ongoing and adjustments can’t take place until the completion of an auction) 
        IAN - invalid adjustment nonce (check the NFT, ID, and closure nonce) 
    */
    function adjustTicketInfo(
        uint256 _nonce,
        uint256 _auctionNonce
    ) external nonReentrant returns(bool) {
        Buyer storage trader = traderProfile[_nonce];
        require(
            !adjustCompleted[_nonce][_auctionNonce]
            // , " AA"
        );
        require(
            adjustmentsMade[_nonce] < adjustmentsRequired
            // , " AU"
        );
        uint256 auctionEndTime;
        (,,,,,,auctionEndTime,,) = auction.auctions(_auctionNonce);
        require(
            block.timestamp > auctionEndTime
            && auctionEndTime != 0
            // , " AO"
        );
        require(
            msg.sender == trader.owner
            // , " IC"
        );
        require(
            adjustmentsMade[_nonce] == adjustmentNonce[_auctionNonce] - 1
            // , "IAN"
        );
        adjustmentsMade[_nonce]++;
        if(
            trader.unlockEpoch <= epochOfClosure[_auctionNonce]
        ) {
            adjustCompleted[_nonce][_auctionNonce] = true;
            return true;
        }
        uint256 epoch = epochOfClosure[_auctionNonce];
        internalAdjustment(
            _nonce,
            _auctionNonce,
            payoutInfo[_auctionNonce],
            auctionSaleValue[_auctionNonce],
            trader.comListOfTickets,
            trader.comAmountPerTicket,
            epoch
        );
        emit PrincipalCalculated(
            address(auction),
            msg.sender,
            _nonce,
            _auctionNonce
        );
        adjustCompleted[_nonce][_auctionNonce] = true;
        return true;
    }

    /**
        Error chart: 
            NA - not accredited
    */
    function processFees(uint256 _amount) external nonReentrant {
        require(
            address(controller.lender()) == msg.sender
            // , "NA"
        );
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        uint256 payout = (50 + creatorFee) * _amount / 1000;
        token.transfer(controller.multisig(), 50 * _amount / 1000);
        token.transfer(address(factory), creatorFee * payout / 1000);
        factory.updatePendingReturns(
            address(token),
            creator,
            creatorFee * _amount / 1000
        );
        epochEarnings[poolEpoch] += _amount - payout;
    }

    /**
        Error chart: 
            NA - not accredited
            TNI - token not included in pool
            NLA - all available capital is borrowed
    */
    function accessLiq(address _user, address _nft, uint256 _id, uint256 _amount) external nonReentrant {
        require(
            address(controller.lender()) == msg.sender
            // , "NA"
        );
        require(
            this.getHeldTokenExistence(_nft, _id)
            // , "TNI"
        );
        require(_user != address(0));
        if(liqAccessed[_nft][_id] == 0) {
            require(
                this.getReservationsAvailable() > 0
                // , "NRA"
            );
            reservations++;
        }
        liqAccessed[_nft][_id] += _amount;
        require(token.transfer(_user, _amount));
    }

    /**
        Error chart: 
            NA - not accredited
    */
    function depositLiq(address _nft, uint256 _id, uint256 _amount) external nonReentrant {
        require(
            address(controller.lender()) == msg.sender
            // , "NA"
        );
        liqAccessed[_nft][_id] -= _amount;
        if(liqAccessed[_nft][_id] == 0) {
            reservations--;
        }
    }

    /**
        Error chart: 
            NA - not accredited
            NLE - no loan exists
    */
    function resetOutstanding(address _nft, uint256 _id) external nonReentrant {
        require(
            address(controller.lender()) == msg.sender
            // , "NA"
        );
        require(
            liqAccessed[_nft][_id] != 0
            // , "NLE"
        );
        delete liqAccessed[_nft][_id];
        reservations--;
    }

    /* ======== INTERNAL ======== */
    // function choppedPosition(
    //     address _buyer,
    //     uint256[] calldata tickets,
    //     uint256[] calldata amountPerTicket,
    //     uint256 startEpoch,
    //     uint256 finalEpoch
    // ) internal returns(uint256 tempReturn) {
    //     uint256 _nonce = positionNonce[_buyer];
    //     positionNonce[_buyer]++;
    //     Buyer storage trader = traderProfile[_nonce];
    //     adjustmentsMade[_nonce] = adjustmentsRequired;
    //     trader.startEpoch = uint32(startEpoch);
    //     trader.unlockEpoch = uint32(finalEpoch);
    //     trader.active = true;
    //     uint256 riskPoints;
    //     uint256 length = tickets.length;
    //     for(uint256 i; i < length; i++) {
    //         require(
    //             tickets[i] <= 100
    //             || trancheCalc.calculateBound(tickets[i]) * modTokenDecimal 
    //                 < this.getPayoutPerReservation(startEpoch) * 50
    //         );
    //         riskPoints += riskCalc.calculateMultiplier(tickets[i]) * amountPerTicket[i];
    //     }
    //     (trader.comListOfTickets, trader.comAmountPerTicket, tempReturn, trader.tokensLocked) = BitShift.bitShift(
    //         modTokenDecimal,
    //         tickets,
    //         amountPerTicket
    //     );
    //     trader.tokensStatic = trader.tokensLocked;
    //     trader.riskStart = 
    //         uint32(
    //             riskPoints * (epochLength - (block.timestamp - (startTime + startEpoch * epochLength)) / 10 minutes * 10 minutes)
    //                 /  epochLength
    //         );
    //     tempReturn <<= 32;
    //     tempReturn |= trader.riskStart;
    //     trader.riskPoints = uint32(riskPoints);
    //     tempReturn <<= 32;
    //     tempReturn |= riskPoints;
    //     for(uint256 i; i < length; i++) {
    //         require(
    //             !nftClosed[startEpoch] || this.getTicketInfo(startEpoch, tickets[i]) == 0
    //             // , "TC"
    //         );
    //     }

    //     emit Purchase(
    //         _buyer,
    //         tickets,
    //         amountPerTicket,
    //         _nonce,
    //         startEpoch,
    //         finalEpoch
    //     );
    // }

    function updateProtocol(
        uint256 largestTicket,
        uint256 startEpoch,
        uint256 endEpoch,
        uint256[] calldata tickets, 
        uint256[] calldata ticketAmounts,
        uint256 riskPoints
    ) internal returns(uint256 totalTokens) {
        uint256 length = tickets.length;
        for(uint256 j = startEpoch; j < endEpoch; j++) {
            while(
                ticketsPurchased[j].length == 0 
                || ticketsPurchased[j].length - 1 < largestTicket / 10
            ) ticketsPurchased[j].push(0);
            uint256[] memory epochTickets = ticketsPurchased[j];
            uint256 amount;
            uint256 temp;
            for(uint256 i = 0; i < length; i++) {
                uint256 ticket = tickets[i];
                temp = this.getTicketInfo(j, ticket);
                temp += ticketAmounts[i];
                require(
                    ticketAmounts[i] != 0
                    // , "ITA"
                );
                require(
                    temp <= amountNft * (trancheCalc.calculateBound(ticket + 1) - trancheCalc.calculateBound(ticket))
                    // , "TLE"
                );
                epochTickets[ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1) 
                    - (2**(((ticket % 10))*25) - 1));
                epochTickets[ticket / 10] |= (temp << ((ticket % 10)*25));
                amount += ticketAmounts[i];
            }
            uint256 tempComp = compressedEpochVals[j];
            uint256 prevPosition;
            prevPosition += 35;
            require(
                (
                    ((compressedEpochVals[j] >> 35) & (2**51 -1)) 
                    + ((j == startEpoch ? riskPoints & (2**128 - 1) : riskPoints >> 128))
                ) < (2**51 -1)
            );
            tempComp = 
                tempComp & ~((2**(prevPosition + 51) - 1) - (2**prevPosition - 1)) 
                    | (
                        (
                            ((compressedEpochVals[j] >> 35) & (2**51 -1)) 
                            + ((j == startEpoch ? riskPoints & (2**128 - 1) : riskPoints >> 128))
                        ) << prevPosition
                    );
            prevPosition += 135;
            require(
                (
                    ((compressedEpochVals[j] >> 170) & (2**84 -1)) 
                    + amount * modTokenDecimal
                ) < (2**84 -1)
            );
            tempComp = 
                tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                    | (
                        (
                            ((compressedEpochVals[j] >> 170) & (2**84 -1)) 
                            + amount * modTokenDecimal
                        ) << prevPosition
                    );
            compressedEpochVals[j] = tempComp;
            ticketsPurchased[j] = epochTickets;
            totalTokens = amount;
        }
    }

    function internalAdjustment(
        uint256 _nonce,
        uint256 _auctionNonce,
        uint256 _payout,
        uint256 _finalNftVal,
        uint256 _comTickets,
        uint256 _comAmounts,
        uint256 _epoch
    ) internal {
        Buyer storage trader = traderProfile[_nonce];
        uint256 payout;
        uint256 riskLost;
        uint256 tokensLost;
        uint256 appLoss;
        uint256 _riskParam = this.getUserRiskPoints(_nonce, _epoch);
        _riskParam <<= 128;
        _riskParam |= trader.riskPoints;
        (
            payout,
            appLoss,
            riskLost,
            tokensLost
        ) = internalCalculation(
            _comTickets,
            _comAmounts,
            _epoch,
            _payout,
            _finalNftVal,
            _riskParam
        ); 
        _comAmounts = 0;
        if(_payout > _finalNftVal) {
            if(loss[_auctionNonce] > _payout - _finalNftVal) {
                _comAmounts += appLoss;
            } else if(loss[_auctionNonce] + appLoss > _payout - _finalNftVal) {
                _comAmounts += loss[_auctionNonce] + appLoss - (_payout - _finalNftVal);
            }
        }
        token.transfer(controller.multisig(), _comAmounts);
        loss[_auctionNonce] += 
        appLoss += (appLoss % amountNft == 0 ? 0 : 1);
        if(trader.tokensLocked > appLoss) {
            trader.tokensLocked -= uint128(appLoss);
        } else {
            trader.tokensLocked = 0;
        }
        trader.riskLost += uint32(riskLost);
        trader.riskStartLost += uint32(trader.riskStart * riskLost / trader.riskPoints);
        trader.tokensLost += uint128(tokensLost);
        _payout >>= 128;
        if(_payout > _finalNftVal) {
            trader.tokensLocked -= uint128(payout);
        }
        token.transfer(trader.owner, payout);
    }

    function internalCalculation(
        uint256 _comTickets,
        uint256 _comAmounts,
        uint256 _epoch,
        uint256 _payout,
        uint256 _finalNftVal,
        uint256 _riskParams
    ) internal returns(
        uint256 payout,
        uint256 appLoss,
        uint256 riskLost,
        uint256 tokensLost
    ) {
        uint256 totalRiskPoints = _payout & (2**128 - 1);
        _payout >>= 128;
        while(_comAmounts > 0) {
            uint256 ticket = _comTickets & (2**25 - 1);
            uint256 amountTokens = _comAmounts & (2**25 - 1);
            uint256 totalTicketTokens = this.getTicketInfo(_epoch, ticket);
            uint256 payoutContribution = amountTokens * modTokenDecimal / amountNft / 100;
            if(trancheCalc.calculateBound(ticket + 1) <= _finalNftVal) {
                if(_finalNftVal >= _payout) {
                    payout += (_finalNftVal - _payout) * findProperRisk(_riskParams, ticket, amountTokens) / totalRiskPoints;
                } else {
                    payout += payoutContribution;
                }
                delete amountTokens;
            } else if(trancheCalc.calculateBound(ticket) > _finalNftVal) {
                if(_finalNftVal >= _payout) {
                    tokensLost += (_finalNftVal - _payout) * findProperRisk(_riskParams, ticket, amountTokens) / totalRiskPoints;
                } 
                appLoss += payoutContribution;
            } else if(
                trancheCalc.calculateBound(ticket + 1) > _finalNftVal
            ) {
                if(
                    totalTicketTokens * modTokenDecimal / amountNft 
                        > (_finalNftVal - trancheCalc.calculateBound(ticket))
                ) {
                    uint256 lossAmount;
                    lossAmount = (
                        totalTicketTokens * modTokenDecimal / amountNft - (_finalNftVal - trancheCalc.calculateBound(ticket))
                    );
                    lossAmount = lossAmount * amountTokens / totalTicketTokens / 100;
                    appLoss += lossAmount;
                    if(_finalNftVal >= _payout) {
                        lossAmount *= (_finalNftVal - _payout) * findProperRisk(_riskParams, ticket, amountTokens) / totalRiskPoints / payoutContribution;
                        tokensLost += lossAmount;
                        payout += (_finalNftVal - _payout) * findProperRisk(_riskParams, ticket, amountTokens) / totalRiskPoints - lossAmount;
                    } else {
                        payout += payoutContribution - lossAmount;
                    }
                } else {
                    if(_finalNftVal >= _payout) {
                        payout += (_finalNftVal - _payout) * findProperRisk(_riskParams, ticket, amountTokens) / totalRiskPoints;
                    } else {
                        payout += payoutContribution;
                    }
                    delete amountTokens;
                }
            }
            riskLost += findProperRisk(_riskParams, ticket, amountTokens) / amountNft;
            _comTickets >>= 25;
            _comAmounts >>= 25;
        }
    }

    function findProperRisk(
        uint256 _riskParams,
        uint256 _ticket,
        uint256 _amountTokens
    ) internal returns(uint256 riskPoints) {
        return (_riskParams >> 128) * 
                    riskCalc.calculateMultiplier(_ticket) * _amountTokens / 100 / 
                        (_riskParams & (2**128 - 1));
    }

    /* ======== GETTER ======== */
    function getReservationsAvailable() external view returns(uint256) {
        return amountNft - reservations - spotsRemoved;
    }

    function getTotalAvailableFunds(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return (compVal >> 170) & (2**84 -1);
    }

    function getPayoutPerReservation(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return ((compVal >> 170) & (2**84 -1)) / amountNft;
    }

    function getRiskPoints(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return (compVal >> 35) & (2**51 -1);
    }

    function getHeldTokenExistence(address _nft, uint256 _id) external view returns(bool) {
        return (tokenMapping[_nft][_id / 250] >> (_id % 250) & 1 == 1);
    }

    function getTicketInfo(uint256 epoch, uint256 ticket) external view returns(uint256) {
        uint256[] memory epochTickets = ticketsPurchased[epoch];
        if(epochTickets.length <= ticket / 10) {
            return 0;
        }
        uint256 temp = epochTickets[ticket / 10];
        temp &= (2**((ticket % 10 + 1)*25) - 1) - (2**(((ticket % 10))*25) - 1);
        return temp >> ((ticket % 10) * 25);
    }

    function getUserRiskPoints(
        uint256 _nonce,
        uint256 _epoch
    ) external view returns(uint256 riskPoints) {
        Buyer memory trader = traderProfile[_nonce];
        if(_epoch == trader.startEpoch) {
            riskPoints = trader.riskStart;
        } else if(_epoch > trader.startEpoch && _epoch < trader.unlockEpoch){
            riskPoints = trader.riskPoints;
        }
    }
}