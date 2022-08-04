// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./helpers/ERC20.sol";
import { AbacusController } from "./AbacusController.sol";

/// @title ABC Token
/// @author Gio Medici
/// @notice ABC token contract
contract ABCToken is ERC20 {

    /* ======== ADDRESS ======== */
    AbacusController public immutable controller;

    /* ======== MAPPING ======== */

    /// @notice purely for testing
    mapping(address => uint256) public counterForNextClaim;

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller) ERC20("Abacus Token", "ABC") {
        ///for testing
        _mint(msg.sender, 10000000000e18);
        controller = AbacusController(_controller);
    }

    /* ======== TOKEN INTERACTIONS ======== */
    /// @notice allows the epoch vault to mint ABC for post-epoch emissions
    function mint(address _user, uint _amount) external {
        require(msg.sender == controller.epochVault());
        _mint(_user, _amount);
    }

    /// @notice allows for the epoch vault to take the designated ABC fee
    /// without requiring an approval
    function bypassTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) external returns(bool) {
        require(
            msg.sender == controller.epochVault()
            || msg.sender == controller.allocator()
        );

        _transfer(sender, recipient, amount);
        return true;
    }
}