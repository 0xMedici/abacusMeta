//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    address public immutable multisig;
    address public factory;
    address public lender;

    /* ======== UINT ======== */
    uint256 public beta;

    /* ======== MAPPING ======== */
    mapping(address => bool) public accreditedAddresses;
    mapping(address => bool) public userWhitelist;
    mapping(address => address) public registry;

    /* ======== EVENTS ======== */
    event WLUserAdded(address[] _user);
    event WLUserRemoved(address[] _user);
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
    function setLender(address _lender) external onlyMultisig {
        require(lender == address(0));
        require(_lender != address(0));
        lender = _lender;
    }

    function setFactory(address _factory) external onlyMultisig {
        require(_factory != address(0));
        require(factory == address(0));
        factory = _factory;
    }

    /* ======== AUTOMATED SETTERS ======== */
    function addAccreditedAddressesMulti(address newAddress) external {
        require(factory == msg.sender || accreditedAddresses[msg.sender]);
        accreditedAddresses[newAddress] = true;
    }

    /* ======== PROPOSALS BETA 1 ======== */
    function addWlUser(address[] calldata users) external onlyMultisig {
        uint256 length = users.length;
        for(uint256 i = 0; i < length; i++) {
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

    function setBeta(uint256 _stage) external onlyMultisig {
        require(_stage > beta);
        beta = _stage;
        emit BetaStageApproved(_stage);
    }

    /* ======== PROXY REGISTRY ======== */
    function setProxy(address _proxy) external {
        registry[msg.sender] = _proxy;
    }

    function clearProxy() external {
        delete registry[msg.sender];
    }
}