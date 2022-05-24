// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";

import "./helpers/ERC20.sol";


/// @title ABC Token
/// @author Gio Medici
/// @notice Abacus currency contract
contract ABCToken is ERC20 {

    /* ======== ADDRESS ======== */

    address public pendingPresale;
    address public presale;
    address public pendingController;
    AbacusController public controller;

    uint256 public requestedMintAmount;

    mapping(address => mapping(address => uint256)) public userAllowance;

    /// @notice purely for testing
    mapping(address => uint256) public counterForNextClaim;

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller) ERC20("Abacus Token", "ABC") {
        //for testing purposes
        _mint(msg.sender, 10000000000e18);
        controller = AbacusController(_controller);
    }

    /* ======== SETTERS ======== */

    /// @notice  propose a change presale address
    function setPresale(address _presale) external {
        require(msg.sender == controller.admin());
        pendingPresale = _presale;
    }

    /// @notice confirm change to presale address
    function approvePresaleChange() external {
        require(msg.sender == controller.multisig());
        presale = pendingPresale;
    }

    /// @notice propose a change controller address
    function setController(address _controller) external {
        require(msg.sender == controller.admin());
        pendingController = _controller;
    }

    /// @notice confirm change to controller address
    function approveControllerChange() external {
        require(msg.sender == controller.multisig());
        controller = AbacusController(pendingController);
    }

    /* ======== TOKEN INTERACTIONS ======== */
    /// @notice purely for testing purposes
    function faucet() external {
        require(counterForNextClaim[msg.sender] <= block.timestamp);
        counterForNextClaim[msg.sender] = block.timestamp + 24 hours;
        _mint(msg.sender, 10000e18);
    }

    function mint(address _user, uint _amount) external {
        require(msg.sender == controller.epochVault());
        _mint(_user, _amount);
    }

    function bypassTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) public returns(bool) {
        require(
            msg.sender == controller.epochVault()
            || msg.sender == controller.veAbcToken()
            || msg.sender == controller.creditBonds()
            || controller.accreditedAddresses(msg.sender)
        );

        _transfer(sender, recipient, amount);
        return true;
    }

    function burn(address _user, uint256 amount) public virtual {
        require(
            msg.sender == controller.abcTreasury()
            || controller.accreditedAddresses(msg.sender)
        );
        _burn(_user, amount);
    }
    
}