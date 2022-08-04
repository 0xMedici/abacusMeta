//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAllocator {

    function mint(address _user, uint _amount) external;

    function bypassTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) external returns(bool);
}