//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ABC Treasury
/// @author Gio Medici
/// @notice Holds the eth earned by Abacus for operational costs
contract Treasury {

    /* ======== ADDRESS ======== */

    //admin of treasury (will be changed to multisig after phase 1 beta and then DAO voting after phase 2)
    address public pendingController;

    //multisig of treasury (takes power from admin address after phase 1)
    AbacusController public controller;

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller) {
        controller = AbacusController(_controller);
    }

    /* ======== SETTERS ======== */

    /// @notice request change of controller
    function setController(address _controller) external {
        require(msg.sender == controller.admin());
        pendingController = _controller;
    }

    /// @notice approve change of controller
    function approveControllerChange() external {
        require(msg.sender == controller.multisig());
        controller = AbacusController(pendingController);
    }

    /* ======== TREASURY ENGAGEMENT ======== */

    /// @notice withdraw eth in treasury
    function withdrawEth(uint256 amount) external {
        require(msg.sender == controller.admin() || msg.sender == controller.multisig());
        payable(controller.multisig()).transfer(amount);
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}