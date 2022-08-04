//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ICreditBonds {

    /// @notice Increment the modVal when the protocol begins
    /// @dev This is done to allow the first wave of credit bonds to be purchased before the first
    /// protocol-wide epoch begins
    function begin() external;

    /// @notice Allow a separate user to open positions for the credit bond holder
    /// @dev This functions similarly to the ERC20 standard 'approve' function 
    /// @param allowee The recipient of the allowance
    /// @param allowance The amount to be added to the allowance size
    function allowTransferAddress(address allowee, uint256 allowance) external;

    /// @notice This function can be used to reset an allowees allowance to 0
    /// @param allowee The user targeted with the allowance reset 
    function resetAllowance(address allowee) external;

    /// @notice Clears any unused bonds to the Treasury
    /// @dev Any remaining bond balance after the conclusion of an epoch is cleared to the 
    /// treasury. The caller receives 0.5% of the amount being cleared. 
    /// @param _epoch The epoch of interest
    function clearUnusedBond(uint256 _epoch) external;

    /// @notice Allow a user to purchase credit bonds
    /// @dev Purchasing credits bonds is a form of pledging to use the bonded amount in the
    /// upcoming epoch
    function bond() external payable;

    /// @notice Allow spot pools to automagically route available credit bonds to fill the 
    /// purchase cost of a position in pools
    /// @dev Only callable by accredited addresses
    /// @param _caller User calling the purchase function (used to check allowance)
    /// @param _vault Pool where the purchase is being executed
    /// @param _user Position buyer 
    /// @param _amount Purchase size
    function sendToVault(
        address _caller, 
        address _vault, 
        address _user, 
        uint256 _amount
    ) external returns(uint256);

    /// @notice Get a user's credit bond based boost in an epoch 
    /// @dev The boost is denominated in units of 0.01%
    /// @param _user User of interest
    /// @param epoch Epoch of interest
    function getPersonalBoost(address _user, uint256 epoch) view external returns(uint256);
}