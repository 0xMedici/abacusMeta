//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFactory {

    /// @notice Create a Spot pool
    /// @param name Name of the pool
    function initiateMultiAssetVault(
        string memory name
    ) external;

    /// @notice Update a users pending return count
    /// @dev Pending returns come from funds that need to be returned from
    /// various pool contracts
    /// @param _user The recipient of these returned funds
    function updatePendingReturns(address _token, address _user, uint256 _amount) external;

    /// @notice Claim the pending returns that have been sent for the user
    function claimPendingReturns(address[] calldata _token) external;

    function getPoolAddress(string memory name) external view returns(address);

    function decodeCompressedTickets(
        uint256 comTickets
    ) external pure returns(
        uint256 stopIndex,
        uint256[10] memory tickets 
    );
}