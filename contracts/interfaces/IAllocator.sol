//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAllocator {

    function addToWL(address _contract) external;

    function approveWLAddition() external;

    function rejectWLAddition() external;

    function removeFromWL(address _contract) external;

    function approveWLRemoval() external;

    function rejectWLRemoval() external;

    function donateToEpoch(uint256 epoch) external payable;

    function receiveFees() external payable;

    function distributeToN() external payable;

    function depositAbc(uint256 _amount) external;

    function withdrawAbc() external;

    function allocateToCollection(address _collection, uint256 _amount) external;

    function changeAllocation(
        address _oldCollection, 
        address _newCollection, 
        uint256 _amount
    ) external;

    function addAutoAllocation(uint256 _amount) external;

    function bribeAuto(address _collection) external payable;

    function reclaimUnusedBribe(uint256 _epoch) external;

    function clearToTreasury(uint256 _epoch) external;

    function calculateBoost(address _collection) external view returns(
        uint256 numerator, 
        uint256 denominator
    );

    function getEpochFeesAccumulated() external view returns(uint256);

    function getTokensLocked(address _user) external view returns(uint256 amount);

    function getAmountAutoAllocated(
        address _user, 
        uint256 _epoch
    ) external view returns(uint256 amount);

    function getAmountAllocated(
        address _user, 
        uint256 _epoch
    ) external view returns(uint256 amount);

    function getAllocationPerCollection(
        address _collection, 
        address _user, 
        uint256 _epoch
    ) external view returns(uint256 allocation);

    function getRewards(address _user) external view returns(uint256 rewards);
}