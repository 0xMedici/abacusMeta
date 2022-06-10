//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface INftEth {

    function proposeAdditionWL(address _addition) external;

    function confirmAdditionWL() external;

    function denyAdditionWL() external;

    function stakeN(uint256 _amount, uint256 _time) external;
    
    function unstakeN() external;

    function receiveFees() external payable;

    function mintNewN(address _user, uint256 _amount) external;

    function exchangeEtoN() payable external;

    function exchangeNtoE(uint256 _amount) external;

    function getFeeCount() external view returns(uint256);
}