//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IEpochVault {

    /// @notice Start the protocol epoch counter
    /// @dev This function allows pools to start being created and traded in as well
    /// as incrementing the mod value tracker on credit bonds to increment bond epoch
    /// tracker by 1
    function begin() external;

    /// @notice Adjust the base tracker and base percentage
    /// @dev This function adjusts the base and base percentage based on the following criterea:
    /// 1) If total EDC purchased >= base 
        /// => base * (1 + 0.125) | base percentage * (1 + 0.25)
    /// 2) If total EDC purchased >= 0.5 * base
        /// => base * (1 + 0.125 * (base - EDC) / base) | 
            /// base percentage * (1 + 0.25 * (base - EDC) / base)
    /// 3) If total EDC purchased < 0.5 * base
        /// => base * (1 - 0.125 * (1 - (base - EDC) / base)) |
            /// => base percentage * (1 - 0.25 * (1 - (base - EDC) / base))
    /// HOWEVER base can never go below 1000e18 (1000 EDC) and base percentage 50 (0.5%)
    function adjustBase() external;

    /// @notice Update the EDC counts of the current epoch
    /// @dev The received nft address will be checked for level of boost to apply before
    /// logging the EDC
    /// @param _nft The nft that will be checked for the boost
    /// @param _user User who will receive the credits
    /// @param _amountCredits Amount of base credits to be received 
    function updateEpoch(
        address _nft,
        address _user,
        uint256 _amountCredits
    ) external;

    /// @notice Claim abc reward from an epoch
    /// @param _user The reward recipient
    /// @param _epoch The epoch of interest
    /// @return amountClaimed Reward size
    function claimAbcReward(
        address _user, 
        uint256 _epoch
    ) external returns(uint256 amountClaimed);

    /// @notice Get the epoch at a certain time
    function getEpoch(uint256 _time) external view returns(uint256);

    /// @notice Get the protocols start time
    function getStartTime() external view returns(uint256);

    /// @notice Get base adjustment status for the current epoch
    function getBaseAdjustmentStatus() external view returns(bool);

    /// @notice Get the base value
    function getBase() external view returns(uint256);

    /// @notice Get the base percentage
    function getBasePercentage() external view returns(uint256);

    /// @notice Get the total distribution credits in the current epoch 
    function getTotalDistributionCredits() external view returns(uint256);

    /// @notice Get a collections boost
    /// @param nft Collection of interest
    function getCollectionBoost(address nft) external view returns(uint256);

    /// @notice Get an epochs end time
    /// @param _epoch Epoch of interest
    function getEpochEndTime(uint256 _epoch) external view returns(uint256 endTime);

    /// @notice Get user credit count during an epoch
    /// @param _epoch Epoch of interest
    /// @param _user User of interest
    function getUserCredits(
        uint256 _epoch, 
        address _user
    ) external view returns(uint256 credits);

    /// @notice Get the current epoch
    function getCurrentEpoch() external view returns(uint256 epochNumber);
}