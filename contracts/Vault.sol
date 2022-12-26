//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Auction } from "./Auction.sol";
import { Factory } from "./Factory.sol";
import { Position } from "./Position.sol";
import { RiskPointCalculator } from "./RiskPointCalculator.sol";
import { TrancheCalculator } from "./TrancheCalculator.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

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

    Position public positionManager;
    ERC20 public token;

    /* ======== ENUMS ======== */
    enum Stage{ INITIALIZED, INCLUDED_NFT, SET_METRICS, STARTED }
    Stage stage;

    /* ======== ADDRESSES ======== */
    address creator;

    /* ======== STRINGS ======== */
    string name;

    /* ======== UINT ======== */
    uint256 creatorFee;
    uint256 reservations;

    uint256 public spotsRemoved;

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
    mapping(uint256 => uint256) epochOfClosure;
    mapping(uint256 => uint256) payoutInfo;
    mapping(uint256 => uint256) auctionSaleValue;
    mapping(uint256 => uint256) compressedEpochVals;
    mapping(uint256 => uint256[]) ticketsPurchased;
    mapping(address => mapping(uint256 => uint256)) tokenMapping;

    /// @notice Payout size for each reservation during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> payout size
    mapping(uint256 => uint256) public epochEarnings;

    /// @notice Tracking the adjustments made by each user for each open nonce
    /// [uint256] -> auction nonce
    /// [uint256] -> adjustment nonce
    mapping(uint256 => uint256) public adjustmentNonce;

    /// @notice Tracks the amount of liquidity that has been accessed on behalf of an NFT
    /// [address] -> NFT collection address
    /// [uint256] -> NFT ID
    mapping(address => mapping(uint256 => uint256)) public liqAccessed;
    
    /* ======== EVENTS ======== */
    event NftInclusion(address[] nfts, uint256[] ids);
    event VaultBegun(address _token, uint256 _collateralSlots, uint256 _interest, uint256 _epoch);
    event Purchase(address _buyer, uint256[] tickets, uint256[] amountPerTicket, uint256 nonce, uint256 startEpoch, uint256 finalEpoch);
    event NftClosed(uint256 _adjustmentNonce, uint256 _closureNonce, address _collection, uint256 _id, address _caller, uint256 payout, address closePoolContract); 
    event PrincipalCalculated(address _closePoolContract, address _user, uint256 _nonce, uint256 _closureNonce);

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
        positionManager = Position(_positionManager);
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
            , "AS"
        );
        require(
            msg.sender == creator
            , " NC"
        );
        uint256 length = _collection.length;
        for(uint256 i = 0; i < length; i++) {
            address collection = _collection[i];
            uint256 id = _id[i];
            require(
                IERC721(collection).ownerOf(id) != address(0)
                , " NO"
            );
            require(
                (tokenMapping[collection][id / 250] & 2**(id % 250) == 0)
                , " AM"
            );
            tokenMapping[collection][id / 250] |= 2**(id % 250);
        }
        stage = Stage.INCLUDED_NFT;
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
        uint32 _slots,
        uint256 _rate,
        uint256 _epochLength,
        address _token,
        uint256 _creatorFee,
        uint256 _liquidationRule
    ) external {
        require(stage == Stage.SET_METRICS);
        require(
            _epochLength >= 2 minutes 
            && _epochLength <= 2 weeks
            , " Out of time bounds"
        );
        require(
            msg.sender == creator
            , " NC"
        );
        require(
            startTime == 0
            , " AS"
        );
        require(
            _rate > 10
            , " RTS"
        );
        require(
            _rate < 500000
            , " RTH"
        );
        require(
            _slots > 0
            , " TLS"
        );
        require(
            _slots < 2**32
            , " TMS"
        );
        require(
            _creatorFee < 400
            , " CFH"
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
        positionManager.setVaultInfo();
        stage = Stage.STARTED;
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
        require(
            startEpoch == (block.timestamp - startTime) / epochLength
            , " IT"
        );
        require(
            finalEpoch - startEpoch > 1
            , " TS"
        );
        require(
            finalEpoch - startEpoch <= 10
            , " TL"
        );
        uint256 totalTokensRequested;
        uint256 largestTicket;
        uint256 riskNorm;
        (largestTicket, riskNorm) = positionManager.createPosition(
            _buyer,
            tickets,
            amountPerTicket,
            startEpoch,
            finalEpoch
        );
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
    ) external nonReentrant returns(uint256 payout, uint256 lost) {
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        uint256 finalEpoch;
        uint256 unlockEpoch;        
        (
            payout, 
            lost, 
            finalEpoch,
            unlockEpoch
        ) = positionManager.sellPosition(
            msg.sender,
            _nonce,
            poolEpoch
        );
        if(finalEpoch == poolEpoch) {
            require(
                reservations == 0
                , " USPE"
            );
        }
        if(finalEpoch == poolEpoch) {
            for(poolEpoch; poolEpoch < unlockEpoch; poolEpoch++) {
                uint256[] memory epochTickets = ticketsPurchased[poolEpoch];
                uint256 comTickets;
                uint256 comAmounts;
                (, comTickets, comAmounts) = positionManager.getPositionOverallInfo(_nonce);
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
                (, comAmounts,) = positionManager.getPositionTokenInfo(_nonce);
                prevPosition += 35;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 51) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 35) & (2**51 -1)) 
                                - positionManager.getUserRiskPoints(_nonce, poolEpoch)
                            ) << prevPosition
                        );
                prevPosition += 135;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 170) & (2**84 -1)) 
                                - comAmounts
                            ) << prevPosition
                        );
                compressedEpochVals[poolEpoch] = tempComp;
            }
        }
        token.transfer(controller.multisig(), lost);
        token.transfer(msg.sender, payout);
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
            , " TNA"
        );
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        uint256 nonce = auction.nonce();
        adjustmentsRequired++;
        adjustmentNonce[nonce] = adjustmentsRequired;
        uint256 ppr = this.getPayoutPerReservation(poolEpoch);
        require(
            ppr != 0
            , " PE0"
        );
        epochOfClosure[nonce] = poolEpoch;
        uint256 temp = ppr;
        temp <<= 128;
        temp |= this.getRiskPoints(poolEpoch);
        payoutInfo[nonce] = temp;
        uint256 payout = 1 * ppr / 100;
        epochEarnings[poolEpoch] += (950 - creatorFee) * payout / 1000;
        token.transfer(address(factory), creatorFee * payout / 1000);
        factory.updatePendingReturns(
            address(token),
            creator,
            creatorFee * payout / 1000
        );
        token.transfer(controller.multisig(), 5 * payout / 100);
        token.transfer(msg.sender, ppr - payout - liqAccessed[_nft][_id]);
        if(liqAccessed[_nft][_id] == 0) {
            require(
                this.getReservationsAvailable() > 0
                , " NRA"
            );
        } else {
            delete liqAccessed[_nft][_id];
            reservations--;
        }
        spotsRemoved++;
        auction.startAuction(msg.sender, _nft, _id, ppr);
        IERC721(_nft).transferFrom(msg.sender, address(auction), _id);
        require(
            IERC721(_nft).ownerOf(_id) == address(auction),
            "TF"
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
            , " AOG"
        );
        require(
            poolEpoch >= resetEpoch
            , " NTY"
        );
        require(
            spotsRemoved != 0
            , " RNN"
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
        address owner;
        (owner,,) = positionManager.getPositionOverallInfo(_nonce);
        require(
            msg.sender == owner
            , " IC"
        );
        uint256 payout;
        uint256 mPayout;
        (, payout, mPayout) = positionManager.adjustTicketInfo(
            _nonce,
            _auctionNonce,
            payoutInfo[_auctionNonce],
            auctionSaleValue[_auctionNonce],
            epochOfClosure[_auctionNonce]
        );
        emit PrincipalCalculated(
            address(auction),
            msg.sender,
            _nonce,
            _auctionNonce
        );
        return true;
    }

    /**
        Error chart: 
            NA - not accredited
    */
    function processFees(uint256 _amount) external nonReentrant {
        require(
            address(controller.lender()) == msg.sender
            , "NA"
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
            , "NA"
        );
        require(
            this.getHeldTokenExistence(_nft, _id)
            , "TNI"
        );
        require(_user != address(0));
        if(liqAccessed[_nft][_id] == 0) {
            require(
                this.getReservationsAvailable() > 0
                , "NRA"
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
            , "NA"
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
            , "NA"
        );
        require(
            liqAccessed[_nft][_id] != 0
            , "NLE"
        );
        delete liqAccessed[_nft][_id];
        reservations--;
    }

    /* ======== INTERNAL ======== */
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
                    , "ITA"
                );
                require(
                    temp <= 
                        amountNft * 
                            (trancheCalc.calculateBound(ticket + 1) - trancheCalc.calculateBound(ticket))
                                / modTokenDecimal
                    , "TLE"
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
}