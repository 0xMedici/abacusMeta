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
    event LPTransferAllowanceChanged(address from, address to);
    event LPTransferred(address from, address to, uint256 nonce);
    event PrincipalCalculated(address _closePoolContract, address _user, uint256 _nonce, uint256 _closureNonce);

    /* ======== CONSTRUCTOR ======== */
    function initialize(
        address _controller,
        address _vault
    ) external initializer {
        controller = AbacusController(_controller);
        vault = Vault(_vault);
        factory = controller.factory();
        auction = Auction(controller.auction());
        riskCalc = controller.riskCalculator();
        trancheCalc = controller.calculator();
        adjustmentsRequired = 1;
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
        adjustmentsMade[_nonce] = adjustmentsRequired;
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
        trader.riskStart = 
            uint32(
                riskPoints * (
                    vault.epochLength() - (block.timestamp - (vault.startTime() + startEpoch * vault.epochLength())) 
                        / 10 minutes * 10 minutes
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