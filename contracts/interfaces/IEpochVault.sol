//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IEpochVault {
    
    function endEpoch() external;

    function updatePersonalBoost(address _user, uint256 epoch, uint256 _amount) external;

    function updateEpoch(address _nft, address _user, uint256 _amount) external;

    function claimAbcReward(address _user, uint256 _epoch) external returns(uint256 amountClaimed);

    function acceptAbcDonation(uint256 _amount) external;

    function receiveAbc(uint256 _amount) external;

    function getAbcEmission(uint256 _epoch) view external returns(uint256);

    function getEpochEndTime(uint256 _epoch) view external returns(uint256 endTime);

    function getUserCredits(uint256 _epoch, address _user) view external returns(uint256 credits);

    function getCurrentEpoch() view external returns(uint256 epochNumber);
}