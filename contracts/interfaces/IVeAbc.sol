//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IVeAbc {
    
    function receiveFees() payable external;

    function lockTokens(uint256 _amount, uint256 _time) external;

    function addTokens(uint256 _amount) external;

    function unlockTokens() external;

    function allocateToCollection(address _collection, uint256 _amount) external;

    function addAutoAllocation(uint256 _amount) external;

    function bribeAuto(address _collection) payable external;

    function claimRewards(address _user) external;

    function calculateBoost(address _collection) view external returns(uint256 numerator, uint256 denominator);

    function clearToTreasury() external;

    function donateToEpoch(uint256 epoch) payable external;

    function updateVeSize(address _user, uint256 epoch) external;

    function getAmountAllocated(address _user) view external returns(uint256 amount);
}