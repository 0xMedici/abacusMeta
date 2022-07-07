//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ILendMulti {

    function proposeFlashWL(address _addr) external;

    function flashWLApproved() external;

    function flashWLRejected() external;

    function borrow(address _pool, address nft, uint256 id, uint256 _amount) external;

    function repay(address nft, uint256 id, uint256 _amount) external;

    function liquidate(address nft, uint256 id) external;

    function transferLoanOwnership(address recipient, address nft, uint256 id) external;

    function approveFlashloanTransfer(address _flashAddr, address nft, uint256 id) external;

    function flashloanTransfer(address nft, uint256 id) external;

    function getLiqStatus(address nft, uint256 id) external view returns(bool);

    function getPosition(
        address nft, 
        uint256 id
    ) external view returns(address borrower, address pool, uint256 outstandingAmount);
}