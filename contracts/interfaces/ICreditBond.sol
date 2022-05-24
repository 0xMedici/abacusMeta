//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ICreditBonds {

    function begin() external;

    function sendToVault(address _caller, address _vault, address _user, uint256 _amount) external returns(uint256);

    function bond() payable external;

    function purchase(address _vault, uint256[] memory tickets, uint256[] memory amounts, uint256 lockTime) external;

    function getPersonalBoost(address _user, uint256 epoch) view external returns(uint256);

}