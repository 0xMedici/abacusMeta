//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { ABCToken } from "./AbcToken.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { IAllocator } from "./interfaces/IAllocator.sol";

import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

/// @title Credit Bonds
/// @author Gio Medici
/// @notice Allow users to bond LP credit in exchange for a boosted EDC emission rate
contract CreditBonds is ReentrancyGuard {

    /* ======== ADDRESSES ======== */

    AbacusController public immutable controller;

    IEpochVault immutable epochVault;

    /* ======== UINTS ======== */
    /// @notice Used to keep credit bond epoch tracker 1 above protocol epoch tracker after start
    uint256 public modVal;

    /* ======== MAPPINGS ======== */
    /// @notice Track epochs that have had their credit bond balance cleared 
    /// [uint256] -> epoch
    /// [bool] -> clearance status
    mapping(uint256 => bool) public epochCleared;

    /// @notice Track total amount of credits bonds purchased in an epoch
    /// [uint256] -> epoch
    /// [uint256] -> credits purchased
    mapping(uint256 => uint256) public totalCreditPerEpoch;

    /// @notice Store final credit bonds purchase amount in an epoch
    /// [uint256] -> epoch
    /// [address] -> user
    /// [uint256] -> final credit bond purchase credit amount
    mapping(uint256 => mapping(address => uint256)) public finalUserCredit;

    /// @notice Track credit bond credit in an epoch
    /// [uint256] -> epoch
    /// [address] -> user
    /// [uint256] -> current credit bond purchase credit amount
    mapping(uint256 => mapping(address => uint256)) public userCredit;

    /// @notice Track a users transfer allowance in connection to another user during an epoch
    /// [uint256] -> epoch
    /// [address] -> allower
    /// [address] -> allowee
    /// [uint256] -> allowance
    mapping(uint256 => mapping(address => mapping(address => uint256))) public transferAllowance;

    /* ======== EVENTS ======== */

    event AllowanceIncreased(address _holder, address _allowee, uint256 _allowance);
    event BondsCleared(uint256 _epoch, uint256 _amount);
    event EthBonded(address _user, uint256 _epoch, uint256 _amount);
    event BondsUsed(address _user, address _vault, uint256 _amount);
    
    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller, address _epochVault) {
        controller = AbacusController(_controller);
        epochVault = IEpochVault(_epochVault);
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}

    /* ======== CONFIGURATION ======== */

    /// @notice Increment the modVal when the protocol begins
    /// @dev This is done to allow the first wave of credit bonds to be purchased before the first
    /// protocol-wide epoch begins
    function begin() external nonReentrant {
        require(msg.sender == controller.epochVault());
        modVal = 1;
    }

    /* ======== BOND INTERACTION ======== */
    /// @notice Allow a separate user to open positions for the credit bond holder
    /// @dev This functions similarly to the ERC20 standard 'approve' function 
    /// @param allowee The recipient of the allowance
    /// @param allowance The amount to be added to the allowance size
    function allowTransferAddress(address allowee, uint256 allowance) external nonReentrant {
        uint256 currentEpoch;
        if(epochVault.getStartTime() == 0) {
            currentEpoch == 0;
        } else {
            currentEpoch = epochVault.getCurrentEpoch() + modVal;
        }

        transferAllowance[currentEpoch][msg.sender][allowee] += allowance;

        emit AllowanceIncreased(
            msg.sender,
            allowee, 
            transferAllowance[currentEpoch][msg.sender][allowee]
        );
    }

    /// @notice This function can be used to reset an allowees allowance to 0
    /// @param allowee The user targeted with the allowance reset 
    function resetAllowance(address allowee) external nonReentrant {
        uint256 currentEpoch;
        if(epochVault.getStartTime() == 0) {
            currentEpoch == 0;
        } else {
            currentEpoch = epochVault.getCurrentEpoch() + modVal;
        }

        delete transferAllowance[currentEpoch][msg.sender][allowee];
        emit AllowanceIncreased(
            msg.sender, 
            allowee, 
            transferAllowance[currentEpoch][msg.sender][allowee]
        );
    }

    /// @notice Clears any unused bonds to the Treasury
    /// @dev Any remaining bond balance after the conclusion of an epoch is cleared to the 
    /// treasury. The caller receives 0.5% of the amount being cleared. 
    /// @param _epoch The epoch of interest
    function clearUnusedBond(uint256 _epoch) external nonReentrant {
        uint256 currentEpoch;
        if(epochVault.getStartTime() == 0) {
            currentEpoch == 0;
        } else {
            currentEpoch = epochVault.getCurrentEpoch() + modVal;
        }
        require(!epochCleared[_epoch]);
        epochCleared[_epoch] = true;
        uint256 payout = totalCreditPerEpoch[_epoch];
        delete totalCreditPerEpoch[_epoch];

        require(_epoch < currentEpoch - modVal);
        payable(msg.sender).transfer(5 * payout / 1000);
        IAllocator(controller.allocator())
            .donateToEpoch{ value: 995 * payout / 1000 }(
                currentEpoch - modVal
            );
        emit BondsCleared(_epoch, payout);
    }

    /// @notice Allow a user to purchase credit bonds
    /// @dev Purchasing credits bonds is a form of pledging to use the bonded amount in the
    /// upcoming epoch
    function bond() external payable nonReentrant {
        uint256 currentEpoch;
        if(epochVault.getStartTime() == 0) {
            currentEpoch == 0;
        } else {
            currentEpoch = epochVault.getCurrentEpoch() + modVal;
        }

        userCredit[currentEpoch][msg.sender] += msg.value;
        finalUserCredit[currentEpoch][msg.sender] += msg.value;
        totalCreditPerEpoch[currentEpoch] += msg.value;

        emit EthBonded(msg.sender, currentEpoch, msg.value);
    }
    
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
    ) external returns(uint256) {
        require(controller.accreditedAddresses(msg.sender));
        uint256 currentEpoch;
        if(epochVault.getStartTime() == 0) {
            currentEpoch == 0;
        } else {
            currentEpoch = epochVault.getCurrentEpoch() + modVal;
        }
        uint256 payload;

        if(_caller != _user) {
            if(transferAllowance[currentEpoch][_user][_caller] < _amount) {
                payload = transferAllowance[currentEpoch][_user][_caller];
                transferAllowance[currentEpoch][_user][_caller] = 0;
            }
            else {
                payload = _amount;
                transferAllowance[currentEpoch][_user][_caller] -= _amount;
            }
            userCredit[currentEpoch - 1][_user] -= payload;
            payable(_vault).transfer(payload);
            emit BondsUsed(_user, _vault, payload);
            return payload;
        }

        if(_amount >= userCredit[currentEpoch - 1][_user]) {
            payload = userCredit[currentEpoch - 1][_user];
        }
        else {
            payload = _amount;
        }

        userCredit[currentEpoch - 1][_user] -= payload;
        payable(_vault).transfer(payload);
        emit BondsUsed(_user, _vault, payload);
        return payload;
    }

    /* ======== GETTERS ======== */
    /// @notice Get a user's credit bond based boost in an epoch 
    /// @dev The boost is denominated in units of 0.01%
    /// @param _user User of interest
    /// @param epoch Epoch of interest
    function getPersonalBoost(address _user, uint256 epoch) view external returns(uint256) {
        if(finalUserCredit[epoch][_user] >= controller.bondMaxPremiumThreshold()) return 10_000;
        return 10_000 * finalUserCredit[epoch][_user] / controller.bondMaxPremiumThreshold();
    }
}