//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Auction } from "./Auction.sol";
import { Factory } from "./Factory.sol";
import { Vault } from "./Vault.sol";
import { Lend } from "./Lend.sol";
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

    /* ======== MAPPING ======== */
    mapping(uint256 => Position) public positions;

    /* ======== STRUCT ======== */
    struct Position {
        address owner;
        uint256 lockTime;
        uint256 unlockTime;
        bytes32 positionHash;
    }

    /* ======== MAPPINGS ======== */
    mapping(address => uint256[]) public ticketHoldings;
    mapping(address => uint256[]) public pendingWithdrawals;
    mapping(address => uint256) public withdrawalTime;

    mapping(address => mapping(address => uint256[])) public trancheAllowance;

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
        uint256[] calldata amountPerTicket
    ) external nonReentrant returns(uint256 largestTicket, uint256 riskPoints) {
        require(
            msg.sender == address(vault)
            , "Fraudulent creator"
        );
        for(uint256 j = 0; j < tickets.length; i++) {
            if(ticket > largestTicket) {
                largestTicket = ticket;
            }
        }
        while(
            ticketHoldings[_buyer].length == 0 
            || ticketHoldings[_buyer].length - 1 < largestTicket / 10
        ) ticketHoldings[_buyer].push(0);
        while(
            pendingWithdrawals[_buyer].length == 0 
            || pendingWithdrawals[_buyer].length - 1 < largestTicket / 10
        ) pendingWithdrawals[_buyer].push(0);
        uint256[] memory ticketHoldings_ = ticketHoldings[_buyer];
        for(uint256 i = 0; i < tickets.length; i++) {
            uint256 ticket = tickets[i];
            uint256 temp = this.getTicketsOwned(_buyer, ticket);
            temp += amountPerTicket[i];
            require(
                ticket <= 100
                || trancheCalc.calculateBound(ticket) * modTokenDecimal 
                    < vault.totalTokens() * modTokenDecimal * 50
                , "Tranche too high!"
            );
            riskPoints += riskCalc.calculateMultiplier(ticket) * amountPerTicket[i];
            ticketHoldings_[_buyer][ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1)
                - (2**(((ticket % 10))*25) - 1));
            ticketHoldings_[_buyer][ticket / 10] |= (temp << ((ticket % 10)*25));
        }
        ticketHoldings[_buyer] = ticketHoldings_;
    }

    function requestSale(
        address _caller,
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket
    ) external {
        //switch to hashbased withdrawal requests
        uint256[] memory pendingHoldings_ = pendingWithdrawals[msg.sender];
        for(uint256 i = 0; i < tickets.length; i++) {
            uint256 ticket = tickets[i];
            uint256 amount = amountPerTicket[i];
            require(
                this.getTicketsOwned(_caller, ticket) >= amount
                , "Tranche bal too low"
            );
            uint256 temp = this.getTicketsOwned(_buyer, ticket);
            temp -= amount;
            pendingHoldings_[_buyer][ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1)
                - (2**(((ticket % 10))*25) - 1));
            pendingHoldings_[_buyer][ticket / 10] |= (temp << ((ticket % 10)*25));
        }
        pendingWithdrawals[msg.sender] = pendingHoldings_;
        //TODO: allow this to be customized
        withdrawalTime[msg.sender] = block.timestamp + 2 weeks;
    }

    function sell(
        address _caller,
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket
    ) external returns(
        uint256 payout
    ) {
        require(msg.sender == address(vault));
        uint256[] memory ticketHoldings_ = ticketHoldings;
        uint256[] memory pendingHoldings_ = pendingWithdrawals[msg.sender];
        for(uint256 i = 0; i < tickets.length; i++) {
            uint256 ticket = tickets[i];
            uint256 amount = amountPerTicket[i];
            require(
                this.getTicketsOwned(_caller, ticket) >= amount
                , "Tranche bal too low"
            );
            if(
                vault.getTicketInfo(ticket) 
                    - controller.lender().ticketLiqAccessed(address(vault), ticket)
                        >= amount
            ) {} else if(withdrawalTime > block.timestamp) {
                require(
                    pendingHoldings_[msg.sender][ticket / 10]
                        & ((2**((_ticket % 10 + 1)*25) - 1) - (2**(((_ticket % 10))*25) - 1))
                            >= amount
                    , "Not enough to be withdrawn"
                );
            } else {
                revert("Withdrawal failed");
            }
            uint256 temp = this.getTicketsOwned(_buyer, ticket);
            temp -= amountPerTicket[i];
            payout += vault.ticketValuePerPoint(ticket) * amount;
            ticketHoldings_[ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1)
                - (2**(((ticket % 10))*25) - 1));
            ticketHoldings_[ticket / 10] |= (temp << ((ticket % 10)*25));
        }
        ticketHoldings[msg.sender] = ticketHoldings_;
        delete pendingWithdrawals[msg.sender];
        //TODO: emit sale complete event
    }

    function changeTransferPermission(
        address recipient,
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket
    ) external nonReentrant returns(bool) {
        require(
            tickets.length == amountPerTicket.length
            , "Improper input"
        );
        for(uint256 j = 0; j < tickets.length; i++) {
            if(ticket > largestTicket) {
                largestTicket = ticket;
            }
        }
        while(
            trancheAllowance[msg.sender][recipient].length == 0 
            || trancheAllowance[msg.sender][recipient].length - 1 < largestTicket / 10
        ) trancheAllowance[msg.sender][recipient].push(0);
        uint256[] memory trancheAllowance_ = trancheAllowance[msg.sender][recipient];
        for(uint256 i = 0; i < tickets.length; i++) {
            uint256 ticket = tickets[i];
            uint256 amount = amountPerTicket[i];
            uint256 temp = this.getAllowance(msg.sender, recipient, ticket);
            temp += amount;
            trancheAllowance_[msg.sender][recipient][ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1)
                - (2**(((ticket % 10))*25) - 1));
            trancheAllowance_[msg.sender][recipient][ticket / 10] |= (temp << ((ticket % 10)*25));
        }
        trancheAllowance[msg.sender][recipient] = trancheAllowance_;
        //TODO: emit allowance event
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
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket
    ) external nonReentrant returns(bool) {
        require(
            tickets.length == amountPerTicket.length
            , "Improper input"
        );
        uint256[] memory trancheAllowance_ = trancheAllowance[from][msg.sender];
        for(uint256 i = 0; i < tickets.length; i++) {
            uint256 ticket = tickets[i];
            uint256 amount = amountPerTicket[i];
            uint256 allowedAmount = this.getAllowance(from, msg.sender, ticket);
            require(
                allowedAmount >= amount
                , "Allowance too low"
            );
            allowedAmount -= amount;
            trancheAllowance_[from][msg.sender][ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1)
                - (2**(((ticket % 10))*25) - 1));
            trancheAllowance_[from][msg.sender][ticket / 10] |= (allowedAmount << ((ticket % 10)*25));
        }
        trancheAllowance[from][msg.sender] = trancheAllowance_;
        //TODO: emit transfer event
        return true;
    }

    /* ======== GETTER ======== */
    function getTicketsOwned(address _user, uint256 _ticket) external view returns(uint256) {
        uint256 temp = ticketHoldings[_user][_ticket / 10];
        temp &= (2**((_ticket % 10 + 1)*25) - 1) - (2**(((_ticket % 10))*25) - 1);
        return temp >> ((_ticket % 10) * 25);
    }

    function getUserPending(address _user, uint256 _ticket) external view returns(uint256) {
        uint256 temp = pendingWithdrawals[_user][_ticket / 10];
        temp &= (2**((_ticket % 10 + 1)*25) - 1) - (2**(((_ticket % 10))*25) - 1);
        return temp >> ((_ticket % 10) * 25);
    }

    function getAllowance(address _user, address _allowed, uint256 _ticket) external view returns(uint256) {
        uint256 temp = trancheAllowance[_user][_allowed][_ticket / 10];
        temp &= (2**((_ticket % 10 + 1)*25) - 1) - (2**(((_ticket % 10))*25) - 1);
        return temp >> ((_ticket % 10) * 25);
    }
}