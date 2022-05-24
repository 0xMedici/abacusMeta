//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ABCToken } from "./AbcToken.sol";
import { AbacusController } from "./AbacusController.sol";
import { VeABC } from "./VeAbcToken.sol";
import { ICreditBonds } from "./interfaces/ICreditBond.sol";
import { IVeAbc } from "./interfaces/IVeAbc.sol";

import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

/// @title Epoch Vault
/// @author Gio Medici
/// @notice Mints user reward tokens per epoch
contract EpochVault is ReentrancyGuard {

    /* ======== ADDRESS ======== */

    /// @notice protocol directory contract
    AbacusController public controller;

    /* ======== UINT ======== */

    /// @notice start time of Abacus
    uint256 public startTime;

    /// @notice length of each epoch
    uint256 public epochLength;

    /* ======== BOOL ======== */

    /// @notice set to true once Abacus started
    bool public started;

    /* ======== MAPPING ======== */

    /// @notice track information per epoch (see Epoch struct below for what information)
    mapping(uint256 => Epoch) public epochTracker;

    /// @notice track a users personal boost per epoch based on credit bonds
    mapping(uint256 => mapping(address => uint256)) public personalBoost;

    /* ======== STRUCT ======== */

    /// @notice hold information about each epoch that passes
    /** 
    @dev (1) totaCredits -> total amount of credits purchased in an epoch
         (2) startTime -> time the epoch began 
         (3) abcEmissionSize -> size of that epochs emissions for retroactive claims
         (4) userCredits -> each users amount of credits in each epoch 
    */
    struct Epoch {
        uint256 totalCredits;
        uint256 startTime;
        uint256 abcEmissionSize;
        mapping(address => uint256) userCredits;
    }

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller, uint256 _epochLength) {
        epochLength = _epochLength;
        controller = AbacusController(_controller);
    }

    /* ======== EPOCH INTERACTION ======== */

    /// @notice kick off the Abacus protocol
    function begin() nonReentrant external {
        require(msg.sender == controller.admin() && !started);
        ICreditBonds(payable(controller.creditBonds())).begin();
        startTime = block.timestamp;
        started = true;
    }

    /// @notice Used as information intake function for Spot pool contracts to update a users credit count
    /// @param _nft the nft address that corresponds to the pool the user is buying credits from
    /// @param _user the user that is buying the credits in the Spot pool
    /// @param _amount total amount of credits being purchased
    function updateEpoch(address _nft, address _user, uint256 _amount) nonReentrant external {
        
        //query veABC contract for boost that NFT collection holds based on allocation gauge
        (uint256 numerator, uint256 denominator) = VeABC(controller.veAbcToken()).calculateBoost(_nft);
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;

        //check the msg.sender is either a Spot pool or closure contract
        require(controller.accreditedAddresses(msg.sender)); 


        uint256 boost = ICreditBonds(payable(controller.creditBonds())).getPersonalBoost(_user, currentEpoch == 0? 0: currentEpoch - 1);
        
        /** 
        User credits automatically vest for 1 full epoch. When _amount is submitted in the function, the contract checks the multiplier
        based on the gauge to determine what multiple to apply to the users _amount which is to be added to their credit balance
        */
        uint256 creditsToAdd = 
            _amount * (10_000e18 + boost * 1e18)
            * (denominator == 0 ? 100 : (100 + 100 * numerator / denominator)) / 100 
            * (1e18 + personalBoost[currentEpoch + 1][_user] * 1e18/ 10_000) / 1e18 / 10_000e18;
        epochTracker[currentEpoch].totalCredits += creditsToAdd;
        epochTracker[currentEpoch].userCredits[_user] += creditsToAdd;
    }

    /* ======== ABC REWARDS ======== */

    /// @notice Allow credit holders to claim their portion of the epochs emissions
    /** 
    @dev portion of an epochs emissions that a user receives is based on their proportional 
    ownership of total the total credits that were purchased in that epoch
    */
    /// @param _user the user who is receiving their abc rewards
    /// @param _epoch the epoch they are calling the rewards from
    function claimAbcReward(address _user, uint256 _epoch) external returns(uint256 amountClaimed){
        require(_epoch < (block.timestamp - startTime) / epochLength);

        //calculate epoch emissions size 
        uint256 epochEmission = this.getBaseEmission(_epoch) + epochTracker[_epoch].abcEmissionSize;

        //check _user proportional ownership of the epoch
        uint256 abcReward = epochTracker[_epoch].userCredits[_user] * epochEmission / epochTracker[_epoch].totalCredits;
        
        //clear _user credit balance
        epochTracker[_epoch].userCredits[_user] = 0;

        //mint new ABC emission from the epoch
        ABCToken(payable(controller.abcToken())).mint(_user, abcReward);

        amountClaimed = abcReward;
    }

    /// @notice used to receive and log network fees paid to be paid out in upcoming epoch emission
    function receiveAbc(uint256 _amount) nonReentrant external {
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        require(controller.accreditedAddresses(msg.sender) || controller.veAbcToken() == msg.sender);
        epochTracker[currentEpoch].abcEmissionSize += _amount;
    }

    /// @notice Calculate (pre-ABC spent) epoch emission size
    /// @return emission size of current epoch
    function getBaseEmission(uint256 epoch) view external returns(uint256) {
        if(epoch < 2) return 26_900_000e18;
        else if (epoch < 4) return 13_500_000e18;
        else if (epoch < 6) return 5_800_000e18;
        else return controller.inflationRate() * ABCToken(payable(controller.abcToken())).totalSupply() / 2600;
    }

    /// @notice return a past epochs emission 
    function getPastAbcEmission(uint256 _epoch) view external returns(uint256) {
        uint256 baseEmission = this.getBaseEmission(_epoch);
        return baseEmission + epochTracker[_epoch].abcEmissionSize;
    }

    /// @notice returns epoch end time
    function getEpochEndTime(uint256 _epoch) view external returns(uint256 endTime) {
        endTime = startTime + epochLength * (_epoch + 1);
    }

    /// @notice returns a users epoch distribution credits
    /// @param _epoch check the chosen epoch for EDC
    /// @param _user the user in question
    function getUserCredits(uint256 _epoch, address _user) view external returns(uint256 credits) {
        credits = epochTracker[_epoch].userCredits[_user];
    }

    /// @notice return the current epoch
    function getCurrentEpoch() view external returns(uint256 epochNumber) {
        if(startTime == 0) epochNumber = 0;
        else epochNumber = (block.timestamp - startTime) / epochLength;
    }
}