//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Auction } from "./Auction.sol";
import { Factory } from "./Factory.sol";
import { Position } from "./Position.sol";
import { RiskPointCalculator } from "./RiskPointCalculator.sol";
import { TrancheCalculator } from "./TrancheCalculator.sol";
import { MoneyFlow } from "./MoneyFlow.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
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
    MoneyFlow flow;

    Position public positionManager;
    ERC20 public token;

    /* ======== ENUMS ======== */
    enum Stage{ INITIALIZED, INCLUDED_NFT, SET_METRICS, STARTED }
    Stage stage;

    /* ======== ADDRESSES ======== */
    address public creator;

    /* ======== STRINGS ======== */
    string name;

    /* ======== BYTES32 ======== */
    bytes32 public root;

    /* ======== UINT ======== */
    uint256 public creatorFee;

    uint256 public closureFee;

    uint256 public collectionAmount;

    uint256 public modTokenDecimal;

    uint256 public liquidationWindow;

    /// @notice Interest rate that the pool charges for usage of liquidity
    uint256 public interestRate;

    /// @notice Total amount of adjustments required (every time an NFT is 
    /// closed this value increments)
    uint256 public adjustmentsRequiredPre;

    uint256 public adjustmentsRequiredComplete;

    uint256 public totalRiskPoints;

    uint256 public profitsPerRisk;

    uint256 public totalTokens;

    /* ======== ARRAYS ======== */
    uint256[] public ticketVolumes;

    /* ======== MAPPINGS ======== */
    mapping(address => bool) addressExists;

    mapping(uint256 => uint256) public payoutInfo;

    mapping(uint256 => uint256) public adjustmentNonceTracker;
    
    mapping(uint256 => uint256) public ticketValuePerPoint;

    mapping(uint256 => uint256) public trancheAdjustmentsMade;

    mapping(uint256 => uint256) public trancheVPR;
    
    /* ======== EVENTS ======== */
    event NftInclusion(address[] nfts, uint256[] ids);
    event VaultBegun(address _token, uint256 _collateralSlots, uint256 _interest, uint256 _epoch);
    event Purchase(address _buyer, uint256[] tickets, uint256[] amountPerTicket, uint256 nonce, uint256 startEpoch, uint256 finalEpoch);
    event NftClosed(uint256 _adjustmentNonce, uint256 _closureNonce, address _collection, uint256 _id, address _caller, uint256 payout, address closePoolContract); 
    event PrincipalCalculated(address _closePoolContract, address _user, uint256 _nonce, uint256 _closureNonce);
    event FeesEarned(address _pool, uint256 _epoch, uint256 _fees);

    /* ======== CONSTRUCTOR ======== */
    function initialize(
        string memory _name,
        address _controller,
        address _creator,
        address _positionManager
    ) external initializer {
        controller = AbacusController(_controller);
        factory = controller.factory();
        require(_creator != address(0));
        stage = Stage.INITIALIZED;
        creator = _creator;
        name = _name;
        auction = Auction(controller.auction());
        riskCalc = controller.riskCalculator();
        trancheCalc = controller.calculator();
        flow = controller.flow();
        positionManager = Position(_positionManager);
        adjustmentsRequiredPre = 1;
        adjustmentsRequiredComplete = 1;
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
        bytes32 _root,
        address[] calldata _collection,
        uint256[] calldata _id
    ) external {
        require(msg.sender == creator);
        require(root == 0x0, "Inclusion finished");
        require(_collection.length == _id.length, "Invalid input");
        if(_root != 0x0) {
            root = _root;
            stage = Stage.INCLUDED_NFT;
        }
        uint256 length = _collection.length;
        for(uint256 i = 0; i < length; i++) {
            if(!addressExists[_collection[i]]) {
                addressExists[_collection[i]] = true;
                collectionAmount++;
            }
        }
        emit NftInclusion(_collection, _id);
    }

    function setEquations(
        uint256[] calldata risk,
        uint256[] calldata tranche
    ) external {
        require(stage == Stage.INCLUDED_NFT);
        riskCalc.setMetrics(
            risk
        );
        trancheCalc.setMetrics(
            tranche
        );
        positionManager.setEquations(
            risk,
            tranche
        );
        stage = Stage.SET_METRICS;
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
        uint256 _rate,
        address _token,
        uint256 _creatorFee,
        uint256 _closureFee
    ) external {
        require(stage == Stage.SET_METRICS);
        require(
            msg.sender == creator
            , "NC"
        );
        require(
            _rate > 10
            , "RTS"
        );
        require(
            _rate < 500000
            , "RTH"
        );
        require(
            _creatorFee < 400
            , "CFH"
        );
        require(
            _closureFee < 100
            , "CFTH"
        );
        require(
            ERC20(_token).decimals() > 3
        );
        interestRate = _rate;
        token = ERC20(_token);
        modTokenDecimal = 10**ERC20(_token).decimals() / 1000;
        creatorFee = _creatorFee;
        closureFee = _closureFee;
        positionManager.setVaultInfo();
        stage = Stage.STARTED;
        // emit VaultBegun(address(token), _slots, _rate, _epochLength);
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
        uint256[] calldata amountPerTicket
    ) external nonReentrant {
        require(tickets.length >= 1);
        require(
            stage == Stage.STARTED
            , " NS"
        );
        require(
            tickets.length == amountPerTicket.length
            , " II"
        );
        require(
            tickets.length <= 100
            , " PTL"
        );
        uint256 totalTokensRequested;
        uint256 largestTicket;
        uint256 riskPoints;
        adjustTicketInfo(tickets);
        (largestTicket, riskPoints) = positionManager.createPosition(
            _buyer,
            tickets,
            amountPerTicket
        );
        totalTokensRequested = _updateProtocol(
            largestTicket,
            tickets,
            amountPerTicket,
            riskPoints
        );
        flow.receiveLiquidity(_buyer, totalTokensRequested * modTokenDecimal);
        //TODO: emit purchase event
    }

    function submitPendingWithdrawal() external {
        //check that withdraw amounts are within bounds of balance
        //choose tickets
        //choose amounts
        //add to pending withdraw tracker of each
        //log withdrawal timer for user

        //FOR LIQUIDATION LOGIC
        //once pending time concludes, if proper liquidity isn't there
            //auto liquidates an NFT with a loan out in the violating tranche
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
        uint256[] calldata _tickets,
        uint256[] calldata _amounts
    ) external nonReentrant returns(uint256 payout) {
        uint256[] memory ticketVolumes_ = ticketVolumes;
        uint256 totalTokenAmount;
        uint256 riskAmount;
        payout = position.sell(
            msg.sender,
            _tickets,
            _amounts
        );
        for(uint256 i = 0; i < _tickets.length; i++) {
            uint256 _ticketAmount = _amounts[i];
            uint256 ticket = _tickets[i];
            uint256 temp = this.getTicketInfo(ticket);
            temp -= _ticketAmount;
            require(
                trancheAdjustmentsMade[ticket] < adjustmentsRequiredPre
                , "Not adjusted"
            );
            ticketVolumes_[ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1)
                - (2**(((ticket % 10))*25) - 1));
            ticketVolumes_[ticket / 10] |= (temp << ((ticket % 10)*25));
            riskAmount += riskCalc.calculateMultiplier(ticket) * _ticketAmount;
            totalTokenAmount += _ticketAmount;
        }
        totalRiskPoints -= riskAmount;
        totalTokens -= totalTokenAmount;
        flow.returnLiquidity(msg.sender, payout);
        //TODO: emit sale event
    }

    /* ======== POOL CLOSURE ======== */
    /** 
    Error chart: 
        TNA - token non-existent (chosen NFT to close does not exist in the pool) 
        PE0 - payout equal to 0 (payout must be greater than 0 to close an NFT) 
        NRA - no reservations available (all collateral spots are in use currently so closure is unavailable)
        TF - Transfer failed (transferring the NFT has failed so closure reverted)
    */
    function closeNft(
        uint256 _auctionNonce,
        uint256 _ppr
    ) external nonReentrant2 returns(uint256) {
        require(
            msg.sender == address(controller.closureHandler())
            , "Not closure handler"
        );
        adjustmentsRequiredPre++;
        adjustmentNonceTracker[adjustmentsRequiredPre] = _auctionNonce;
        payoutInfo[_auctionNonce] = ppr;
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
        uint256[] calldata _tickets
    ) public nonReentrant {
        for(uint256 i = 0; i < _tickets.length; i++) {
            if(trancheAdjustmentsMade[_tickets[i]] < adjustmentsRequiredPre + 1) {
                uint256 ticketAmount = this.getPerpTicketInfo(_ticket);
                uint256 existingValueInTicket = ticketAmount * ticketValuePerPoint[_ticket];
                _adjustTranche(
                    _tickets[i],
                    ticketAmount,
                    existingValueInTicket
                );
                _adjustTrancheClosures(
                    _ticket[i],
                    ticketAmount,
                    existingValueInTicket
                );
            }
        }
    }

    /**
        Error chart: 
            NA - not accredited
    */
    function processFees(uint256 _amount) external nonReentrant {
        require(
            address(controller.flow()) == msg.sender
            , "NA"
        );
        profitsPerRisk += _amount / totalRiskPoints;
        emit FeesEarned(address(this), poolEpoch, _amount);
    }

    /* ======== INTERNAL ======== */
    function _updateProtocol(
        uint256 largestTicket,
        uint256[] calldata _tickets,
        uint256[] calldata _ticketAmounts,
        uint256 _riskPoints
    ) internal returns(uint256 totalCost) {
        totalRiskPoints += _riskPoints;
        while(
            ticketVolumes.length == 0 
            || ticketVolumes.length - 1 < largestTicket / 10
        ) ticketVolumes.push(0);
        uint256[] memory ticketVolumes_ = ticketVolumes;
        uint256 totalTicketAmount;
        for(uint256 i = 0; i < _tickets.length; i++) {
            uint256 _ticketAmount = _ticketAmounts[i];
            uint256 ticket = _tickets[i];
            uint256 temp = this.getTicketInfo(_tickets[i]);
            temp += _ticketAmount;
            require(
                _ticketAmount != 0
                , "ITA"
            );
            require(
                temp <= 2**24 - 1
                , "TLE"
            );
            if(ticketValuePerPoint[ticket] == 0) {
                ticketValuePerPoint[ticket] = modTokenDecimal;
                trancheAdjustmentsMade[ticket] = 1;
            }
            ticketVolumes_[ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1)
                - (2**(((ticket % 10))*25) - 1));
            ticketVolumes_[ticket / 10] |= (temp << ((ticket % 10)*25));
            totalCost += _ticketAmount * ticketValuePerPoint[ticket];
            totalTicketAmount += _ticketAmount;
        }
        totalTokens += totalTicketAmount;
    }

    function _adjustTrancheClosures(
        uint256 _ticket,
        uint256 ticketAmount,
        uint256 existingValueInTicket
    ) internal {
        //TODO: add loss harvesting for over counted losses
        uint256 adjustmentLevel = trancheAdjustmentsMade[_ticket];
        uint256 adjustmentsRequired_ = adjustmentsRequiredPre;
        bool reverted;
        for(uint256 i = adjustmentLevel; i < adjustmentsRequired_; i++) {
            uint256 _auctionNonce = adjustmentNonceTracker[i];
            uint256 payout = payoutInfo[_auctionNonce];
            uint256 saleValue = auction.getAuctionSaleValue(_auctionNonce);
            if(saleValue == 0) {
                reverted = true;
                existingValueInTicket = ticketAmount * ticketValuePerPoint[_ticket];
                break;
            }
            if(payout > saleValue) {
                if(trancheCalc.calculateBound(_ticket + 1) * modTokenDecimal > saleValue) {
                    if(
                        existingValueInTicket >= 
                        this.getTrancheSize(_ticket) * modTokenDecimal
                    ) {
                        existingValueInTicket -= this.getTrancheSize(_ticket) * modTokenDecimal;
                    } else {
                        existingValueInTicket = 0;
                    }
                }
            }
        }
        ///TODO: COMPRESS THESE 3
        if(!reverted) {
            adjustmentsRequiredComplete = adjustmentsRequired_;
            trancheAdjustmentsMade[_ticket] = adjustmentsRequired_;    
        }
        ticketValuePerPoint[_ticket] = (existingValueInTicket) / ticketAmount;
        trancheVPR[_ticket] = profitsPerRisk;
    }

    function _adjustTranche(
        uint256 _ticket,
        uint256 ticketAmount,
        uint256 existingValueInTicket
    ) internal {
        //TODO: add loss harvesting for over counted losses
        existingValueInTicket += (profitsPerRisk - trancheVPR[_ticket]) * this.getRiskPointsSum(_ticket, ticketAmount);
        ///TODO: COMPRESS THESE 3
        ticketValuePerPoint[_ticket] = (existingValueInTicket) / ticketAmount;
        trancheVPR[_ticket] = profitsPerRisk;
    }

    /* ======== GETTER ======== */

    function getRiskPointsSum(uint256 _ticket, uint256 _amount) external view returns(uint256) {
        return riskCalc.calculateMultiplier(_ticket) * _amount;
    }

    function getTrancheSize(uint256 _ticket) external view returns(uint256) {
        return (trancheCalc.calculateBound(_ticket + 1) - trancheCalc.calculateBound(_ticket));
    }

    function getHeldTokenExistence(bytes32[] calldata _merkleProof, address _nft, uint256 _id) external view returns(bool) {
        require(addressExists[_nft]);
        bytes memory id = bytes(Strings.toString(_id));
        uint256 nftInt = uint160(_nft);
        bytes memory nft = bytes(Strings.toString(nftInt));
        bytes memory value = bytes.concat(nft, id);
        bytes32 leaf = keccak256(abi.encodePacked(value));
        require(MerkleProof.verify(_merkleProof, root, leaf));
        return true;
    }

    function getTicketInfo(uint256 ticket) external view returns(uint256) {
        uint256 temp = ticketVolumes[ticket / 10];
        temp &= (2**((ticket % 10 + 1)*25) - 1) - (2**(((ticket % 10))*25) - 1);
        return temp >> ((ticket % 10) * 25);
    }
}