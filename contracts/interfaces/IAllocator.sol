//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAllocator {

    /// @notice Donate ETH to an epochs for reward distribution
    /// @param epoch The desired epoch during which these funds should be distributed
    function donateToEpoch(uint256 epoch) external payable;

    /// @notice Receive fees from protocol based fee generators
    function receiveFees() external payable;

    /// @notice Deposit ABC credit to be used in allocation
    /// @param _amount The amount of ABC that a user would like to deposit 
    function depositAbc(uint256 _amount) external;

    /// @notice Withdraw ABC credit
    /// @dev The users allocation credit must be completely cleared during the epoch of withdrawal
    function withdrawAbc() external;

    /// @notice Allocate ABC credit to a collection during the current epoch
    /// @dev This allocation choice can be switched any time before the epoch ends but not withdrawn
    /// @param _collection The collection to allocate the ABC credit towards
    /// @param _amount The amount of ABC to allocate towards the chosen collection
    function allocateToCollection(address _collection, uint256 _amount) external;

    /// @notice Change ABC allocation during an epoch
    /// @param _oldCollection The collection that allocation is being redirected from
    /// @param _newCollection The collection that allocation is being redirected to
    /// @param _amount Amount of ABC allocation to redirect from old to new
    function changeAllocation(
        address _oldCollection, 
        address _newCollection,
        uint256 _amount
    ) external;

    /// @notice Auto allocate ABC
    /// @dev This ABC will be automatically directed dependent on the ending proportional bribe
    /// per collection during the epoch. Auto allocation cannot be switched to explicit allocation
    /// once added. 
    /// @param _amount The amount of ABC to be auto allocated
    function addAutoAllocation(uint256 _amount) external;

    /// @notice Bribe auto allocators to direct auto allocated ABC towards a chosen collection
    /// @dev If there are no auto allocators, the briber can reclaim the submitted bribe
    /// @param _collection The collection to direct auto allocated ABC towards
    function bribeAuto(address _collection) external payable;

    /// @notice Claim accrued fees (from bribes and protocol generated fees)
    /// @dev If fees go unclaimed for 25 epochs of allocation, this will be automagically called
    /// @param _user The user that is claiming rewards
    function claimReward(address _user) external;

    /// @notice For bribers to reclaim any unused bribes (if auto allocation was 0)
    /// @param _epoch The desired epoch to claim unused bribes from
    function reclaimUnusedBribe(uint256 _epoch) external;

    /// @notice Used to clear protocol generated fees to treasury
    /// @dev This also includes any fees that have been directed towards an epoch where
    /// there were no EDC earned. The caller receives 0.5% of the empty epoch fees
    /// @param _epoch The desired epoch to clear funds from
    function clearToTreasury(uint256 _epoch) external;

    /// @notice Calculates a collections boost based on ABC allocation
    /// @dev This function returns the result as a numerator and denominator in an 
    /// attempt to savor precision on the receiving contract
    /// @param _collection The collection of interest 
    /// @return numerator The total amount of ABC allocated towards the collection (includes auto)
    /// @return denominator The total amount of ABC allocated
    function calculateBoost(address _collection) external view returns(
        uint256 numerator, 
        uint256 denominator
    );

    /// @notice Returns total ETH fees that have been accumulated during the current epoch
    function getEpochFeesAccumulated() external view returns(uint256);

    /// @notice The total ABC deposited by a user
    /// @param _user The user of interest
    /// @return amount Amount of ABC deposited
    function getTokensLocked(address _user) external view returns(uint256 amount);

    /// @notice The amount of ABC that a user auto allocted during an epoch 
    /// @param _user User of interest
    /// @param _epoch Epoch of interest
    /// @return amount Amount of ABC auto allocated
    function getAmountAutoAllocated(
        address _user, 
        uint256 _epoch
    ) external view returns(uint256 amount);

    /// @notice The total amount of ABC that a user has allocated (auto and explicit)
    /// @param _user User of interest
    /// @param _epoch Epoch of interest
    /// @return amount The amount of allocated ABC
    function getAmountAllocated(
        address _user, 
        uint256 _epoch
    ) external view returns(uint256 amount);

    /// @notice The amount of ABC that a user has allocated towards a collection in the 
    /// current epoch
    /// @param _collection Collection of interest
    /// @param _user User of interest 
    /// @param _epoch Epoch of interest
    /// @return allocation The amount of ABC allocated to the collection
    function getAllocationPerCollection(
        address _collection, 
        address _user, 
        uint256 _epoch
    ) external view returns(uint256 allocation);

    /// @notice The rewards that a user has currently earned
    /// @param _user User of interest
    /// @return rewards Amount of rewards earned
    function getRewards(address _user) external view returns(uint256 rewards);
}