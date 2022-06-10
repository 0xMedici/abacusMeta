//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./helpers/ERC20.sol";

import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

/// @title NFT ETH (nETH)
/// @notice NFT ETH is fully backed by Abacus spot pools and exchangable at a 1:1 ratio with ETH
contract NftEth is ERC20, ReentrancyGuard {

    /* ======== ADDRESSES ======== */
    AbacusController public immutable controller;

    /// @notice Propose an address to grant access NFT ETH mint access
    address public proposedToWl;

    /* ======== UINT ======== */
    /// @notice Contract start time (used to track epoch for fee distribution)
    uint256 public startTime;

    /* ======== MAPPINGS ======== */
    /// @notice Track fees generated during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> fee amount
    mapping(uint256 => uint256) public feesPerEpoch;

    /// @notice Track NFT ETH locked by a user
    /// [address] -> user
    /// [uint256] -> NFT ETH locked
    mapping(address => uint256) public nLocked;

    /// @notice Track total NFT ETH locked during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> NFT ETH locked
    mapping(uint256 => uint256) public totalLockedPerEpoch;

    /// @notice Whitelist of addresses with NFT ETH mint access
    /// [address] -> lender address
    /// [bool] -> Whitelist status
    mapping(address => bool) public lenderWL;

    /// @notice Track a users staked NFT ETH position
    /// [address] -> user
    mapping(address => Staker) public stakers;

    /* ======== STRUCT ======== */
    /// @notice Holds staker metrics
    /// [startEpoch] -> Starting lock epoch
    /// [unlockTime] -> Unlock epoch
    /// [lockedPerEpoch] -> NFT ETH locked per epoch
        /// [uint256] -> epoch
        /// [uint256] -> NFT ETH locked during an epoch
    struct Staker {
        uint256 startEpoch;
        uint256 unlockTime;
        mapping(uint256 => uint256) lockedPerEpoch;
    }

    /* ======== EVENT ======== */
    event WLAdditionProposed(address _addition);
    event WLAdditionApproved(address _addition);
    event WLAdditionRejected(address _addition);
    event NEthStaked(address _user, uint256 _amount, uint256 _time);
    event NEthUnstaked(address _user, uint256 _amount);
    event NEthFeesReceived(address _sender, uint256 _epoch, uint256 _amount);
    event NEthMinted(address _minter, uint256 _amount);
    event EthExchangedForNEth(address _user, uint256 _amount);
    event NEthExchangedForEth(address _user, uint256 _amount);

    /* ======== CONSTRUCTOR ======== */
    constructor(address _controller) ERC20("NFT ETH", "nETH") {
        controller = AbacusController(_controller);
        startTime = block.timestamp;
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}

    /* ======== PROPOSALS ======== */
    function proposeAdditionWL(address _addition) external {
        require(proposedToWl == address(0));
        require(msg.sender == controller.multisig());
        proposedToWl = _addition;

        emit WLAdditionProposed(_addition);
    }

    function confirmAdditionWL() external {
        require(msg.sender == controller.admin());
        lenderWL[proposedToWl] = true;
        emit WLAdditionApproved(proposedToWl);
        delete proposedToWl;
    }

    function denyAdditionWL() external {
        require(msg.sender == controller.admin());
        emit WLAdditionRejected(proposedToWl);
        delete proposedToWl;
    }

    /* ======== STAKING ======== */
    /// @notice Stake NFT ETH
    /// @param _amount Amount of NFT ETH to stake
    /// @param _time Amount of time to stake for
    function stakeN(uint256 _amount, uint256 _time) external nonReentrant {
        require(_time >= 1 days);
        Staker storage staker = stakers[msg.sender];
        uint256 currentEpoch = (block.timestamp - startTime) / 1 days;
        uint256 unlockEpoch;
        if(staker.unlockTime == 0) {
            unlockEpoch = (block.timestamp + _time - startTime) / 1 days;
            staker.unlockTime = block.timestamp + _time;
            staker.startEpoch = currentEpoch;
        } else {
            unlockEpoch = (staker.unlockTime - startTime) / 1 days;
        }
        _transfer(msg.sender, address(this), _amount);
        nLocked[msg.sender] += _amount;
        for(currentEpoch; currentEpoch <= unlockEpoch; currentEpoch++) {
            staker.lockedPerEpoch[currentEpoch] = nLocked[msg.sender];
            totalLockedPerEpoch[currentEpoch] = nLocked[msg.sender];
        }
        emit NEthStaked(msg.sender, _amount, _time);
    }

    /// @notice Unstake NFT ETH
    function unstakeN() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.unlockTime < block.timestamp);
        uint256 unlockEpoch = (staker.unlockTime - startTime) / 1 days;
        claimFees(msg.sender, unlockEpoch);
        uint256 payout = nLocked[msg.sender];
        delete stakers[msg.sender];
        delete nLocked[msg.sender];
        _transfer(address(this), msg.sender, payout);

        emit NEthUnstaked(msg.sender, payout);
    }

    /* ======== FEES ======== */
    /// @notice Receive fees to be distributed to NFT ETH stakers
    function receiveFees() external payable nonReentrant {
        require(
            controller.accreditedAddresses(msg.sender) 
            || controller.specialPermissions(msg.sender)
        );
        uint256 currentEpoch = (block.timestamp - startTime) / 1 days;
        feesPerEpoch[currentEpoch] += msg.value;

        emit NEthFeesReceived(msg.sender, currentEpoch, msg.value);
    }

    /* ======== MINT & EXCHANGE ======== */
    /// @notice Mint new NFT ETH
    /// @dev Permission reserved for WL lender addresses
    /// @param _user User that is receiving newly minted NFT ETH
    /// @param _amount Amount of NFT ETH being minted
    function mintNewN(address _user, uint256 _amount) external nonReentrant {
        require(lenderWL[msg.sender]);
        _mint(_user, _amount);

        emit NEthMinted(_user, _amount);
    }

    /// @notice Exchange ETH to NFT ETH
    /// @dev This exchange rate in this pool will always be 1 ETH:1 NFT ETH
    function exchangeEtoN() external payable nonReentrant {
        _mint(msg.sender, msg.value);

        emit EthExchangedForNEth(msg.sender, msg.value);
    }

    /// @notice Exchange NFT ETH to ETH
    /// @dev This exchange rate in this pool will always be 1 NFT ETH:1 ETH
    /// In the case where all of the ETH is removed from the pool, this implies the following:
    /// NFT ETH has been minted against pools and exchanged for ETH
        /// => The only way to pay back a loan is by clearing the outstanding NFT ETH balance
        /// which means that either a EITHER a live trading pool or this exchange pool will be
        /// replenished by the borrower paying back the loan or the borrower getting liquidated
        /// and the funds from the backing pool being deployed to cover the outstanding NFT ETH
    function exchangeNtoE(uint256 _amount) external nonReentrant {
        _burn(msg.sender, _amount);
        payable(msg.sender).transfer(_amount);

        emit NEthExchangedForEth(msg.sender, _amount);
    }

    /* ======== INTERNAL ======== */
    function claimFees(address _user, uint256 unlockEpoch) internal {
        Staker storage staker = stakers[_user];
        uint256 startEpoch = staker.startEpoch;
        uint256 feePayout;
        for(uint256 i = startEpoch; i < unlockEpoch; i++) {
            uint256 amount = staker.lockedPerEpoch[i];
            delete staker.lockedPerEpoch[i];
            feePayout += feesPerEpoch[i] * amount / totalLockedPerEpoch[i];
        }

        payable(_user).transfer(feePayout);
    }

    /* ======== GETTER ======== */
    /// @notice Get fees collected in the current epoch
    function getFeeCount() external view returns(uint256){
        uint256 currentEpoch = (block.timestamp - startTime) / 1 days;
        return(feesPerEpoch[currentEpoch]);
    }
}