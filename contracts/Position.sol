//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Auction } from "./Auction.sol";
import { Factory } from "./Factory.sol";
import { Vault } from "./Vault.sol";
import { RiskPointCalculator } from "./RiskPointCalculator.sol";
import { TrancheCalculator } from "./TrancheCalculator.sol";
import { BitShift } from "./helpers/BitShift.sol";

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
contract Position is ReentrancyGuard, ReentrancyGuard2, Initializable {

    /* ======== CONTRACTS ======== */
    Factory factory;
    Vault vault;
    AbacusController controller;
    RiskPointCalculator riskCalc;
    TrancheCalculator trancheCalc;
    Auction auction;

    ERC20 public token;

    /* ======== UINT ======== */

    uint256 public nonce;

    uint256 public modTokenDecimal;

    /// @notice Total amount of slots to be collateralized
    uint256 public amountNft;

    /* ======== MAPPINGS ======== */
    mapping(uint256 => bool) nftClosed;
    mapping(uint256 => uint256) loss;
    mapping(uint256 => uint256) epochOfClosure;
    mapping(uint256 => uint256) payoutInfo;
    mapping(uint256 => uint256) auctionSaleValue;
    mapping(uint256 => uint256) compressedEpochVals;
    mapping(uint256 => uint256[]) ticketsPurchased;
    mapping(address => mapping(uint256 => uint256)) tokenMapping;

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
    event Purchase(address _buyer, uint256[] tickets, uint256[] amountPerTicket, uint256 nonce, uint256 startEpoch, uint256 finalEpoch);
    event SaleComplete(address _seller, uint256 nonce, uint256 ticketsSold);
    event LPTransferAllowanceChanged(address from, address to);
    event LPTransferred(address from, address to, uint256 nonce);
    event PrincipalCalculated(address _closePoolContract, address _user, uint256 _nonce, uint256 _closureNonce);

    /* ======== CONSTRUCTOR ======== */
    function initialize(
        address _controller
    ) external initializer {
        controller = AbacusController(_controller);
        factory = controller.factory();
        auction = Auction(controller.auction());
        riskCalc = controller.riskCalculator();
        trancheCalc = controller.calculator();
    }

    function setVault(address _vault) external {
        require(msg.sender == address(factory));
        require(address(vault) == address(0));
        vault = Vault(_vault);
    }

    function setEquations(
        uint256[] calldata risk,
        uint256[] calldata tranche
    ) external {
        require(msg.sender == address(vault));
        riskCalc.setMetrics(
            risk
        );
        trancheCalc.setMetrics(
            tranche
        );
    }

    function setVaultInfo() external {
        require(msg.sender == address(vault));
        amountNft = vault.amountNft();
        modTokenDecimal = vault.modTokenDecimal();
        token = vault.token();
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
    function createPosition(
        address _buyer,
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint32 startEpoch,
        uint32 finalEpoch
    ) external nonReentrant returns(uint256 largestTicket, uint256 riskNorm) {
        uint256 riskStart;
        for(uint256 i = 0; i < tickets.length / 10 + 1; i++) {
            if(tickets.length % 10 == 0 && i == tickets.length / 10) break;
            uint256 tempVal;
            uint256 upperBound;
            if(10 + i * 10 > tickets.length) {
                upperBound = tickets.length;
            } else {
                upperBound = 10 + i * 10;
            }
            tempVal = choppedPosition(
                _buyer,
                tickets[0 + i * 10:upperBound],
                amountPerTicket[0 + i * 10:upperBound],
                startEpoch,
                finalEpoch
            );
            riskNorm += tempVal & (2**32 - 1);
            tempVal >>= 32;
            riskStart += tempVal & (2**32 - 1);
            tempVal >>= 32;
            if(tempVal > largestTicket) largestTicket = tempVal;
        }
        riskNorm <<= 128;
        riskNorm |= riskStart;
    }

    function sellPosition(
        address _caller,
        uint256 _nonce,
        uint256 _poolEpoch
    ) external returns(
        uint256 payout, 
        uint256 lost,
        uint256 finalEpoch,
        uint256 unlockEpoch
    ) {
        Buyer storage trader = traderProfile[_nonce];
        require(
            trader.unlockEpoch != 0
            , " PNE"
        );
        require(
            _caller == trader.owner
            , " IC"
        );
        require(
            trader.active
            , " PC"
        );
        require(
            adjustmentsMade[_nonce] == vault.adjustmentsRequired()
            , " ANM"
        );
        if(_poolEpoch >= trader.unlockEpoch) {
            finalEpoch = trader.unlockEpoch;
        } else {
            finalEpoch = _poolEpoch;
        }
        for(uint256 j = trader.startEpoch; j < finalEpoch; j++) {
            uint256 riskPoints = vault.getRiskPoints(j);
            uint256 epochEarnings = vault.epochEarnings(j);
            if(j == trader.startEpoch) {
                lost += 
                    (trader.riskStart > trader.riskStartLost ? trader.riskStartLost : trader.riskStart) 
                        * epochEarnings / riskPoints; 
                payout += 
                    (trader.riskStart > trader.riskStartLost ? (trader.riskStart - trader.riskStartLost) : 0) 
                        * epochEarnings / riskPoints;
            } else {
                lost += 
                    (trader.riskPoints > trader.riskLost ? trader.riskLost : trader.riskPoints) 
                        * epochEarnings / riskPoints; 
                payout += 
                    (trader.riskPoints > trader.riskLost ? (trader.riskPoints - trader.riskLost) : 0) 
                        * epochEarnings / riskPoints;
            }
        }

        emit SaleComplete(
            _caller,
            _nonce,
            trader.comListOfTickets
        );
        payout += trader.tokensLocked;
        lost += trader.tokensLost;
        unlockEpoch = trader.unlockEpoch;
        delete traderProfile[_nonce].active;
    }

    function adjustTicketInfo(
        uint256 _nonce,
        uint256 _auctionNonce,
        uint256 _payoutInfo,
        uint256 _auctionSaleValue,
        uint256 _epochOfClosure
    ) external nonReentrant returns(bool result, uint256 payout, uint256 mPayout) {
        require(msg.sender == address(vault));
        Buyer storage trader = traderProfile[_nonce];
        require(
            !adjustCompleted[_nonce][_auctionNonce]
            , " AA"
        );
        require(
            adjustmentsMade[_nonce] < vault.adjustmentsRequired()
            , " AU"
        );
        uint256 auctionEndTime;
        (,,,,,,auctionEndTime,,) = auction.auctions(_auctionNonce);
        require(
            block.timestamp > auctionEndTime
            && auctionEndTime != 0
            , " AO"
        );
        require(
            adjustmentsMade[_nonce] == vault.adjustmentNonce(_auctionNonce) - 1
            , "IAN"
        );
        adjustmentsMade[_nonce]++;
        if(
            trader.unlockEpoch <= _epochOfClosure
        ) {
            adjustCompleted[_nonce][_auctionNonce] = true;
            result = true;
            return (result, payout, mPayout);
        }
        (payout, mPayout) = internalAdjustment(
            _nonce,
            _auctionNonce,
            _payoutInfo,
            _auctionSaleValue,
            trader.comListOfTickets,
            trader.comAmountPerTicket,
            _epochOfClosure
        );
        emit PrincipalCalculated(
            address(auction),
            msg.sender,
            _nonce,
            _auctionNonce
        );
        adjustCompleted[_nonce][_auctionNonce] = true;
        result = true;
        return (result, payout, mPayout);
    }

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
        uint256 _nonce
    ) external nonReentrant returns(bool) {
        require(
            msg.sender == allowanceTracker[_nonce]
            || msg.sender == traderProfile[_nonce].owner
            , " IC"
        );
        traderProfile[_nonce].owner = to;
        delete allowanceTracker[_nonce];
        emit LPTransferred(from, to, _nonce);
        return true;
    }

    /* ======== INTERNAL ======== */
    function choppedPosition(
        address _buyer,
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch
    ) internal returns(uint256 tempReturn) {
        uint256 _nonce = nonce;
        nonce++;
        Buyer storage trader = traderProfile[_nonce];
        adjustmentsMade[_nonce] = vault.adjustmentsRequired();
        trader.owner = _buyer;
        trader.startEpoch = uint32(startEpoch);
        trader.unlockEpoch = uint32(finalEpoch);
        trader.active = true;
        uint256 riskPoints;
        uint256 length = tickets.length;
        for(uint256 i; i < length; i++) {
            require(
                tickets[i] <= 100
                || trancheCalc.calculateBound(tickets[i]) * modTokenDecimal 
                    < vault.getPayoutPerReservation(startEpoch) * 50
            );
            riskPoints += riskCalc.calculateMultiplier(tickets[i]) * amountPerTicket[i];
        }
        (trader.comListOfTickets, trader.comAmountPerTicket, tempReturn, trader.tokensLocked) = BitShift.bitShift(
            modTokenDecimal,
            tickets,
            amountPerTicket
        );
        trader.tokensStatic = trader.tokensLocked;
        trader.riskPoints = uint32(riskPoints);
        trader.riskStart = 
            uint32(
                riskPoints * (
                    vault.epochLength() - (block.timestamp - (vault.startTime() + startEpoch * vault.epochLength())) 
                )
                /  vault.epochLength()
            );
        tempReturn <<= 32;
        tempReturn |= trader.riskStart;
        trader.riskPoints = uint32(riskPoints);
        tempReturn <<= 32;
        tempReturn |= riskPoints;
        for(uint256 i; i < length; i++) {
            require(
                !nftClosed[startEpoch] || vault.getTicketInfo(startEpoch, tickets[i]) == 0
                , "TC"
            );
        }
        emit Purchase(
            _buyer,
            tickets,
            amountPerTicket,
            _nonce,
            startEpoch,
            finalEpoch
        );
    }

    function internalAdjustment(
        uint256 _nonce,
        uint256 _auctionNonce,
        uint256 _payout,
        uint256 _finalNftVal,
        uint256 _comTickets,
        uint256 _comAmounts,
        uint256 _epoch
    ) internal returns(uint256 payout, uint256) {
        Buyer storage trader = traderProfile[_nonce];
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
        if(_payout > _finalNftVal) {
            uint256 currentLoss = loss[_auctionNonce];
            if(currentLoss > _payout - _finalNftVal) {
                _comTickets += appLoss;
            } else if(currentLoss + appLoss > _payout - _finalNftVal) {
                _comTickets += currentLoss + appLoss - (_payout - _finalNftVal);
            }
        }
        loss[_auctionNonce] += appLoss;
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
        return (payout, _comTickets);
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
            uint256 totalTicketTokens = vault.getTicketInfo(_epoch, ticket);
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
    function getPositionTimeline(uint256 _nonce) external view returns(
        uint256 startEpoch, 
        uint256 unlockEpoch
    ) {
        Buyer memory trader = traderProfile[_nonce];
        startEpoch = trader.startEpoch;
        unlockEpoch = trader.unlockEpoch;
    }

    function getPositionRiskInfo(uint256 _nonce) external view returns(
        uint256 riskStart, 
        uint256 riskPoints, 
        uint256 riskLost, 
        uint256 riskStartLost
    ) {
        Buyer memory trader = traderProfile[_nonce];
        riskStart = trader.riskStart;
        riskPoints = trader.riskPoints;
        riskLost = trader.riskLost;
        riskStartLost = trader.riskStartLost;
    }

    function getPositionTokenInfo(uint256 _nonce) external view returns(
        uint256 tokensLocked,
        uint256 tokensStatic, 
        uint256 tokensLost
    ) {
        Buyer memory trader = traderProfile[_nonce];
        tokensLocked = trader.tokensLocked;
        tokensStatic = trader.tokensStatic;
        tokensLost = trader.tokensLost;
    }

    function getPositionOverallInfo(uint256 _nonce) external view returns(
        address owner, 
        uint256 listOfTickets, 
        uint256 listOfAmounts
    ) {
        Buyer memory trader = traderProfile[_nonce];
        owner = trader.owner;
        listOfTickets = trader.comListOfTickets;
        listOfAmounts = trader.comAmountPerTicket;
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