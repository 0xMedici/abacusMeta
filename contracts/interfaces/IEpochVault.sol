//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IEpochVault {
    
    function begin() external;

    function adjustBase() external;

    function updateEpoch(
        address _nft, 
        address _user, 
        uint256 _amountCredits
    ) external;

    function receiveAbc(address _user, uint256 _amount) external;

    function claimAbcReward(
        address _user, 
        uint256 _epoch
    ) external returns(uint256 amountClaimed);

    function getEpoch(uint256 _time) external view returns(uint256);

    function getStartTime() external view returns(uint256);

    function getBaseAdjustmentStatus() external view returns(bool);

    function getBase() external view returns(uint256);

    function getBasePercentage() external view returns(uint256);

    function getTotalDistributionCredits() external view returns(uint256);

    function getCollectionBoost(address nft) external view returns(uint256);

    function getPastAbcEmission(uint256 _epoch) external view returns(uint256);

    function getEpochEndTime(uint256 _epoch) external view returns(uint256 endTime);

    function getUserCredits(
        uint256 _epoch, 
        address _user
    ) external view returns(uint256 credits);

    function getCurrentEpoch() external view returns(uint256 epochNumber);
}