//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ABCToken } from "./AbcToken.sol";
import { AbacusController } from "./AbacusController.sol";
import { IAllocator } from "./interfaces/IAllocator.sol";
import { ICreditBonds } from "./interfaces/ICreditBond.sol";

import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

               //\\                 ||||||||||||||||||||||||||                   //\\                 ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
              ///\\\                |||||||||||||||||||||||||||                 ///\\\                ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
             ////\\\\               |||||||             ||||||||               ////\\\\               ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
            /////\\\\\              |||||||             ||||||||              /////\\\\\              |||||||                       ||||||||            ||||||||  ||||||||||
           //////\\\\\\             |||||||             ||||||||             //////\\\\\\             |||||||                       ||||||||            ||||||||  ||||||||||
          ///////\\\\\\\            |||||||             ||||||||            ///////\\\\\\\            |||||||                       ||||||||            ||||||||  ||||||||||
         ////////\\\\\\\\           ||||||||||||||||||||||||||||           ////////\\\\\\\\           |||||||                       ||||||||            ||||||||  ||||||||||
        /////////\\\\\\\\\          ||||||||||||||                        /////////\\\\\\\\\          |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
       /////////  \\\\\\\\\         ||||||||||||||||||||||||||||         /////////  \\\\\\\\\         |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
      /////////    \\\\\\\\\        |||||||             ||||||||        /////////    \\\\\\\\\        |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
     /////////||||||\\\\\\\\\       |||||||             ||||||||       /////////||||||\\\\\\\\\       |||||||                       ||||||||            ||||||||                    ||||||||||
    /////////||||||||\\\\\\\\\      |||||||             ||||||||      /////////||||||||\\\\\\\\\      |||||||                       ||||||||            ||||||||                    ||||||||||
   /////////          \\\\\\\\\     |||||||             ||||||||     /////////          \\\\\\\\\     |||||||                       ||||||||            ||||||||                    ||||||||||
  /////////            \\\\\\\\\    |||||||             ||||||||    /////////            \\\\\\\\\    ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||
 /////////              \\\\\\\\\   |||||||||||||||||||||||||||    /////////              \\\\\\\\\   ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||
/////////                \\\\\\\\\  ||||||||||||||||||||||||||    /////////                \\\\\\\\\  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||

/// @title Epoch Vault
/// @author Gio Medici
/// @notice Manages epoch metrics (includes: minting abc rewards, base, EDC earnings)
contract EpochVault is ReentrancyGuard {

    /* ======== ADDRESS ======== */

    AbacusController public immutable controller;

    /* ======== UINT ======== */
    /// @notice Target epoch distribution credit count to be reached in an epoch
    uint256 public base;

    /// @notice Percentage of liquidity used to farm epoch distribution credits required to
    /// purchase those credits
    uint256 public basePercentage;

    /// @notice Protocol start time
    uint256 public startTime;

    /// @notice The length of epochs
    uint256 public immutable epochLength;

    /* ======== MAPPING ======== */
    /// @notice Track if the base has been adjusted during an epoch
    /// [uint256] -> epoch
    /// [bool] -> adjustment status
    mapping(uint256 => bool) public baseAdjusted;

    /// @notice Track epoch details
    /// [uint256] -> epoch
    /// [Epoch] -> struct of epoch details
    mapping(uint256 => Epoch) public epochTracker;
    
    /* ======== STRUCT ======== */
    /// @notice Stores operational information of an epoch
    /// [totalCredits] -> total epoch distribution credits purchased in an epoch
    /// [userCredits] -> track a users credit count in an epoch
        /// [address] -> user
        /// [uint256] -> credit count
    struct Epoch {
        uint256 totalCredits;
        mapping(address => uint256) userCredits;
    }

    /* ======== EVENTS ======== */

    event PaymentMade(uint256 _epoch, uint256 _amount);
    event BaseAdjusted(uint256 _epoch, uint256 _base, uint256 _basePercentage);
    event EpochUpdated(address _user, address nft, uint256 _amountCredits);
    event AbcRewardClaimed(address _user, uint256 _epoch, uint256 _amount);
    event AbcReceived(uint256 _amountReceived, uint256 _totalEmissionSize);

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller, uint256 _epochLength) {
        epochLength = _epochLength;
        controller = AbacusController(_controller);
        base = 50_000_000e18;
        basePercentage = 100;
        baseAdjusted[0] = true;
    }

    /* ======== MANUAL EPOCH INTERACTION ======== */
    /// @notice Start the protocol epoch counter
    /// @dev This function allows pools to start being created and traded in as well
    /// as incrementing the mod value tracker on credit bonds to increment bond epoch
    /// tracker by 1
    function begin() external nonReentrant {
        require(msg.sender == controller.multisig() && startTime == 0);
        ICreditBonds(payable(controller.creditBonds())).begin();
        startTime = block.timestamp;
    }

    /* ======== AUTOMATED EPOCH INTERACTION (ACCREDITED ONLY) ======== */
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
    function adjustBase() external {
        require(controller.accreditedAddresses(msg.sender));
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        Epoch storage tracker = epochTracker[currentEpoch - 1];
        if(epochTracker[currentEpoch - 1].totalCredits > base) {
            base = 
                base * (10_000 + 1_250) / 10_000;
            basePercentage = 
                basePercentage * (10_000 + 2_500) / 10_000;
        } else if(tracker.totalCredits > 50 * base / 100) {
            base = 
                base 
                    * (10_000 + 1_250 * tracker.totalCredits / base) 
                        / 10_000;
            basePercentage = 
                basePercentage 
                    * (10_000 + 2_500 * tracker.totalCredits / base) 
                        / 10_000;
        } else if(tracker.totalCredits < 50 * base / 100) {
            base = 
                base 
                    * (10_000 - 1_250 * (1_000 - tracker.totalCredits * 1_000 / base) / 1_000)
                        / 10_000;
            basePercentage = 
                basePercentage 
                    * (10_000 - 2_500 * (1_000 - tracker.totalCredits * 1_000 / base) / 1_000)
                        / 10_000;
        }

        if(base < 30_000_000e18) {
            base = 30_000_000e18;
        }
        if(basePercentage < 50) {
            basePercentage = 50;
        } else if(basePercentage > 10_000) {
            basePercentage = 10_000;
        }

        baseAdjusted[currentEpoch] = true;
        emit BaseAdjusted(currentEpoch, base, basePercentage);
    }

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
    ) external nonReentrant {
        require(controller.accreditedAddresses(msg.sender));
        (uint256 numerator, uint256 denominator) = 
            IAllocator(controller.allocator()).calculateBoost(_nft);
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        uint256 boost = ICreditBonds(payable(controller.creditBonds())).getPersonalBoost(
            _user, 
            currentEpoch == 0? 0: currentEpoch - 1
        );
        uint256 creditsToAdd = 
            _amountCredits * (10_000e18 + boost * 1e18)
            * (denominator == 0 ? 100 : (100 + 100 * numerator / denominator)) / 1_000_000e18;
        epochTracker[currentEpoch].totalCredits += creditsToAdd;
        epochTracker[currentEpoch].userCredits[_user] += creditsToAdd;
        emit EpochUpdated(_user,  _nft, creditsToAdd);
    }

    /* ======== ABC REWARDS ======== */
    /// @notice Claim abc reward from an epoch
    /// @param _user The reward recipient
    /// @param _epoch The epoch of interest
    /// @return amountClaimed Reward size
    function claimAbcReward(
        address _user, 
        uint256 _epoch
    ) external nonReentrant returns(uint256 amountClaimed) {
        require(_epoch < (block.timestamp - startTime) / epochLength);
        Epoch storage tracker = epochTracker[_epoch];
        uint256 abcReward;
        if(tracker.totalCredits == 0) {
            abcReward = 0;
        } else {
            abcReward = 
                tracker.userCredits[_user] * 20_000_000e18 / tracker.totalCredits;
        }
        delete tracker.userCredits[_user];
        ABCToken(payable(controller.abcToken())).mint(_user, abcReward);
        amountClaimed = abcReward;
        emit AbcRewardClaimed(_user, _epoch, abcReward);
    }

    /* ======== GETTERS ======== */
    /// @notice Get the epoch at a certain time
    function getEpoch(uint256 _time) external view returns(uint256) {
        return (_time - startTime) / epochLength;
    }

    /// @notice Get the protocols start time
    function getStartTime() external view returns(uint256) {
        return startTime;
    }

    /// @notice Get base adjustment status for the current epoch
    function getBaseAdjustmentStatus() external view returns(bool) {
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        return(baseAdjusted[currentEpoch]);
    }

    /// @notice Get the base value
    function getBase() external view returns(uint256) {
        return base;
    }

    /// @notice Get the base percentage
    function getBasePercentage() external view returns(uint256) {
        return basePercentage;
    }

    /// @notice Get the total distribution credits in the current epoch 
    function getTotalDistributionCredits() external view returns(uint256) {
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        return epochTracker[currentEpoch].totalCredits;
    }

    /// @notice Get a collections boost
    /// @param nft Collection of interest
    function getCollectionBoost(address nft) external view returns(uint256) {
        (uint256 numerator, uint256 denominator) = IAllocator(
            controller.allocator()
        ).calculateBoost(nft);
        return (denominator == 0 ? 100 : (100 + 100 * numerator / denominator));
    }

    /// @notice Get an epochs end time
    /// @param _epoch Epoch of interest
    function getEpochEndTime(uint256 _epoch) external view returns(uint256 endTime) {
        endTime = startTime + epochLength * (_epoch + 1);
    }

    /// @notice Get user credit count during an epoch
    /// @param _epoch Epoch of interest
    /// @param _user User of interest
    function getUserCredits(
        uint256 _epoch, 
        address _user
    ) external view returns(uint256 credits) {
        credits = epochTracker[_epoch].userCredits[_user];
    }

    /// @notice Get the current epoch
    function getCurrentEpoch() external view returns(uint256 epochNumber) {
        epochNumber = (block.timestamp - startTime) / epochLength;
    }
}