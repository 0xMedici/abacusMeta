//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAbcToken {

    /// @notice allows the epoch vault to mint ABC for post-epoch emissions
    function mint(address _user, uint _amount) external;

    /// @notice allows for the epoch vault to take the designated ABC fee
    /// without requiring an approval
    function bypassTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) external returns(bool);
}