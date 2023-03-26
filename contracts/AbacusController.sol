//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Factory } from "./Factory.sol";
import { Lend } from "./Lend.sol";
import { Auction } from "./Auction.sol";
import { TrancheCalculator } from "./TrancheCalculator.sol";
import { RiskPointCalculator } from "./RiskPointCalculator.sol";
import { MoneyFlow } from "./MoneyFlow.sol";
import { ClosureHandler } from "./ClosureHandler.sol";

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

/// @title Abacus Controller
/// @author Gio Medici
/// @notice Abacus protocol controller contract that holds all relevant addresses and metrics 
contract AbacusController {

    /* ======== ADDRESS ======== */
    address public multisig;
    Factory public factory;
    Lend public lender;
    Auction public auction;
    TrancheCalculator public calculator;
    RiskPointCalculator public riskCalculator;
    MoneyFlow public flow;
    ClosureHandler public handler;

    /* ======== BOOL ======== */
    bool public finalMultisigSet;

    /* ======== UINT ======== */
    uint256 public beta;

    /* ======== MAPPING ======== */
    mapping(address => bool) public accreditedAddresses;
    mapping(address => bool) public userWhitelist;
    mapping(address => bool) public agnosticRemovalWl;

    /* ======== EVENTS ======== */
    event WLUserAdded(address[] _user);
    event WLUserRemoved(address[] _user);
    event WLAgnosticRemoval(address[] _addresses);
    event BetaStageApproved(uint256 stage);

    /* ======== MODIFIERS ======== */
    modifier onlyMultisig() {
        require(msg.sender == multisig);
        _;
    }

    /* ======== CONSTRUCTOR ======== */
    constructor(address _multisig) {
        require(_multisig != address(0));
        multisig = _multisig;
        beta = 1;
    }

    /* ======== IMMUTABLE SETTERS ======== */
    function setMultisig(address _multisig) external onlyMultisig {
        require(!finalMultisigSet);
        finalMultisigSet = true;
        multisig = _multisig;
    }

    function setLender(address _lender) external onlyMultisig {
        require(address(lender) == address(0));
        require(_lender != address(0));
        lender = Lend(payable(_lender));
    }

    function setFactory(address _factory) external onlyMultisig {
        require(_factory != address(0));
        require(address(factory) == address(0));
        factory = Factory(payable(_factory));
    }

    function setAuction(address _auction) external onlyMultisig {
        require(_auction != address(0));
        require(address(auction) == address(0));
        accreditedAddresses[_auction] = true;
        auction = Auction(payable(_auction));
    }

    function setCalculator(address _calculator) external onlyMultisig {
        require(_calculator != address(0));
        require(address(calculator) == address(0));
        calculator = TrancheCalculator(_calculator);
    }

    function setRiskCalculator(address _calculator) external onlyMultisig {
        require(_calculator != address(0));
        require(address(riskCalculator) == address(0));
        riskCalculator = RiskPointCalculator(_calculator);
    }

    function setMoneyFlow(address _moneyFlow) external onlyMultisig {
        require(_moneyFlow != address(0));
        require(address(flow) == address(0));
        flow = MoneyFlow(_moneyFlow);
    }

    function setClosureHandler(address _handler) external onlyMultisig {
        require(_handler != address(0));
        require(address(_handler) == address(0));
        handler = ClosureHandler(_handler);
    }

    /* ======== AUTOMATED SETTERS ======== */
    function addAccreditedAddressesMulti(address newAddress) external {
        require(address(factory) == msg.sender || accreditedAddresses[msg.sender]);
        accreditedAddresses[newAddress] = true;
    }

    /* ======== PROPOSALS BETA 1 ======== */
    function addWlUser(address[] calldata users) external onlyMultisig {
        uint256 length = users.length;
        for(uint256 i = 0; i < length; i++) {
            require(users[i] != address(0));
            userWhitelist[users[i]] = true;
        }
        emit WLUserAdded(users);
    }

    function removeWlUser(address[] calldata users) external onlyMultisig {
        uint256 length = users.length;
        for(uint256 i = 0; i < length; i++) {
            delete userWhitelist[users[i]];
        }
        emit WLUserRemoved(users);
    }

    function wlAgnosticRemoval(address[] calldata _addresses) external onlyMultisig {
        uint256 length = _addresses.length;
        for(uint256 i = 0; i < length; i++) {
            require(_addresses[i] != address(0));
            agnosticRemovalWl[_addresses[i]] = true;
        }
        emit WLAgnosticRemoval(_addresses);
    }

    function setBeta(uint256 _stage) external onlyMultisig {
        require(_stage > beta);
        beta = _stage;
        emit BetaStageApproved(_stage);
    }

    function setRemoval
}