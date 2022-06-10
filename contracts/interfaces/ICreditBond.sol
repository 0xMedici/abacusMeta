//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ICreditBonds {

    function begin() external;

    function allowTransferAddress(address allowee, uint256 allowance) external;

    function resetAllowance(address allowee) external;

    function clearUnusedBond(uint256 _epoch) external;

    function bond() external payable;

    function sendToVault(
        address _caller, 
        address _vault, 
        address _user, 
        uint256 _amount
    ) external returns(uint256);

    function getPersonalBoost(address _user, uint256 epoch) view external returns(uint256);
}