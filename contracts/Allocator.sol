// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { ABCToken } from "./AbcToken.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { ICreditBonds } from "./interfaces/ICreditBond.sol";

import "./helpers/ReentrancyGuard.sol";
import "./helpers/ReentrancyGuard2.sol";
import "./helpers/ERC20.sol";
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

/// @title Allocator contract
/// @author Gio Medici
/// @notice Allow users to allocate their ABC to collection (explicit or auto)
contract Allocator is ReentrancyGuard, ReentrancyGuard2 {

    /* ======== ADDRESS ======== */
    
    /// @notice controller contract address   
    AbacusController public immutable controller;

    /// @notice epoch vault contract address
    IEpochVault immutable epochVault;

    /* ======== UINT ======== */

    uint256 public fundsSentToT;

    /// @notice fees received that are designated for the treasury 
    uint256 public fundsForTreasury;

    /* ======== MAPPING ======== */

    /// @notice ABC holders lockup history for retroactive fee claims
    /// [address] -> user
    /// [Holder] -> holder history struct
    mapping(address => Holder) public holderHistory;

    /// @notice total fees received during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> fees accumulated
    mapping(uint256 => uint256) public epochFeesAccumulated;

    /// @notice ABC auto allocated during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> ABC auto allocated
    mapping(uint256 => uint256) public totalAmountAutoAllocated;

    /// @notice ABC allocated to collections (explicit or auto) 
    /// during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> total ABC allocated
    mapping(uint256 => uint256) public totalAllocationPerEpoch;
    
    /// @notice total bribes paid to auto allocators during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> total bribe amount
    mapping(uint256 => uint256) public totalBribesPerEpoch;

    /// @notice bribes offered by an address during an epoch
    /// [address] -> briber
    /// [uint256] -> epoch
    /// [uint256] -> bribe amount
    mapping(address => mapping(uint256 => uint256)) public bribeOffered;

    /// @notice ABC allocated to a specific collection during an epoch
    /// [uint256] -> epoch
    /// [address] -> collection
    /// [uint256] -> ABC allocated
    mapping(uint256 => mapping(address => uint256)) public totalAllocationPerCollection;

    /// @notice bribes put towards a specific collection during an epoch
    /// [uint256] -> epoch
    /// [address] -> collection
    /// [uint256] -> bribe amount
    mapping(uint256 => mapping(address => uint256)) public bribesPerCollectionPerEpoch;

    /* ======== STRUCT ======== */
    /// @notice contains information of a users locked position and chosen allocations
    /// [amountLocked] -> total amount of ABC deposited 
    /// [listOfEpochs] -> list of epochs during which a holder has allocated ABC
    /// [amountAllocated] -> total amount allocated by a holder 
        /// [uint256] -> epoch
        /// [uint256] -> amount ABC allocated
    /// [amountAutoAllocated] -> total amount auto allocated by a holder
        /// [uint256] -> epoch
        /// [uint256] -> amount ABC auto allocated
    /// [allocationPerCollection] -> amount of ABC allocated per collection
        /// [uint256] -> epoch
        /// [address] -> collection
        /// [uint256] -> amount ABC allocated
    struct Holder {
        uint256 amountLocked;
        uint256[] listOfEpochs;
        mapping(uint256 => uint256) amountAllocated;
        mapping(uint256 => uint256) amountAutoAllocated;
        mapping(uint256 => mapping(address => uint256)) allocationPerCollection;
    }

    /* ======== STRUCT ======== */

    event DonatedToEpoch(uint256 _epoch, uint256 _amount);
    event ReceivedFees(uint256 _epoch, uint256 _amount);
    event TokensLocked(address _user, uint256 epochsLocked, uint256 _amount);
    event AllocatedToCollection(address _user, address _collection, uint256 _epoch, uint256 _amount);
    event AllocationChanged(address _user, address _oldCollection, address _newCollection, uint256 _epoch, uint256 _amount);
    event AutoAllocate(address _user, uint256 _epoch, uint256 _amount);
    event BribeOffered(address _user, address _collection, uint256 _epoch, uint256 _amount);
    event RewardClaimed(address _user, uint256 _amount);
    event FundsClearedToTreasury(address _caller, uint256 _epoch, uint256 _amount); 

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller, address _epochVault) {
        controller = AbacusController(_controller);
        epochVault = IEpochVault(_epochVault);
    }

    /* ======== EPOCH CONFIG ======== */
    /// @notice Donate ETH to an epochs for reward distribution
    /// @param epoch The desired epoch during which these funds should be distributed
    function donateToEpoch(uint256 epoch) external payable nonReentrant {
        epochFeesAccumulated[epoch] += msg.value;
        emit DonatedToEpoch(epoch, msg.value);
    }

    /// @notice Receive fees from protocol based fee generators
    function receiveFees() external payable nonReentrant {
        require(
            controller.factoryWhitelist(msg.sender)
            || controller.accreditedAddresses(msg.sender)
        );
        uint256 treasuryRate;
        if(fundsSentToT >= 100_000e18) {
            treasuryRate = 0;
        } else {
            treasuryRate = 10_000 - 500 * (controller.multisig()).balance / 10_000e18;
        }
    
        uint256 payout = (100_000 - treasuryRate) * msg.value / 100_000;
        epochFeesAccumulated[epochVault.getCurrentEpoch()] += payout;
        fundsForTreasury += msg.value - payout;
        fundsSentToT += msg.value - payout;
        emit ReceivedFees(
            epochVault.getCurrentEpoch(), 
            payout
        );
    }

    /* ======== ABC CREDIT ======== */
    /// @notice Deposit ABC credit to be used in allocation
    /// @param _amount The amount of ABC that a user would like to deposit 
    function depositAbc(uint256 _amount) external nonReentrant {
        Holder storage holder = holderHistory[msg.sender];
        ABCToken(controller.abcToken()).bypassTransfer(msg.sender, address(this), _amount);
        holder.amountLocked += _amount;
    }

    /// @notice Withdraw ABC credit
    /// @dev The users allocation credit must be completely cleared during the epoch of withdrawal
    function withdrawAbc() external nonReentrant {
        Holder storage holder = holderHistory[msg.sender];
        uint256 currentEpoch;
        if(epochVault.getStartTime() == 0) {
            currentEpoch == 0;
        } else {
            currentEpoch = epochVault.getCurrentEpoch();
        }
        require(holder.amountAllocated[currentEpoch] == 0);

        uint256 returnAmount = holder.amountLocked;
        if(holder.listOfEpochs.length > 0) {
            this.claimReward(msg.sender);
        }
        delete holderHistory[msg.sender];
        ABCToken(controller.abcToken()).bypassTransfer(address(this), msg.sender, returnAmount);
    }

    /* ======== ALLOCATION ======== */
    /// @notice Allocate ABC credit to a collection during the current epoch
    /// @dev This allocation choice can be switched any time before the epoch ends but not withdrawn
    /// @param _collection The collection to allocate the ABC credit towards
    /// @param _amount The amount of ABC to allocate towards the chosen collection
    function allocateToCollection(address _collection, uint256 _amount) external nonReentrant {
        require(_amount != 0);
        Holder storage holder = holderHistory[msg.sender];
        if(holder.listOfEpochs.length == 25) {
            this.claimReward(msg.sender);
        }
        uint256 currentEpoch;
        if(epochVault.getStartTime() != 0) {
            currentEpoch = epochVault.getCurrentEpoch();
        } 
        uint256 boost = ICreditBonds(payable(controller.creditBonds())).getPersonalBoost(
            msg.sender, 
            currentEpoch
        );
        uint256 nominalAllocationPower = 
            (10_000e18 + boost * 1e18) * holder.amountLocked / 10_000e18;
        require(
            holder.amountAllocated[currentEpoch] + _amount <= nominalAllocationPower
        );
        if(
            holder.listOfEpochs.length == 0 
            || holder.listOfEpochs[holder.listOfEpochs.length - 1] != currentEpoch
        ) {
            holder.listOfEpochs.push(currentEpoch);
        }
        
        holder.amountAllocated[currentEpoch] += _amount;
        holder.allocationPerCollection[currentEpoch][_collection] += _amount;
        totalAllocationPerCollection[currentEpoch][_collection] += _amount;
        totalAllocationPerEpoch[currentEpoch] += _amount;
        
        emit AllocatedToCollection(msg.sender, _collection, currentEpoch, _amount);
    }

    /// @notice Change ABC allocation during an epoch
    /// @param _oldCollection The collection that allocation is being redirected from
    /// @param _newCollection The collection that allocation is being redirected to
    /// @param _amount Amount of ABC allocation to redirect from old to new
    function changeAllocation(
        address _oldCollection, 
        address _newCollection,
        uint256 _amount
    ) external nonReentrant {
        Holder storage holder = holderHistory[msg.sender];
        uint256 currentEpoch;
        if(epochVault.getStartTime() != 0) {
            currentEpoch = epochVault.getCurrentEpoch();
        } 
        require(holder.allocationPerCollection[currentEpoch][_oldCollection] >= _amount);
        
        holder.allocationPerCollection[currentEpoch][_oldCollection] -= _amount;
        totalAllocationPerCollection[currentEpoch][_oldCollection] -= _amount;
        holder.allocationPerCollection[currentEpoch][_newCollection] += _amount;
        totalAllocationPerCollection[currentEpoch][_newCollection] += _amount;

        emit AllocationChanged(msg.sender, _oldCollection, _newCollection, currentEpoch, _amount);
    }

    /// @notice Auto allocate ABC
    /// @dev This ABC will be automatically directed dependent on the ending proportional bribe
    /// per collection during the epoch. Auto allocation cannot be switched to explicit allocation
    /// once added. 
    /// @param _amount The amount of ABC to be auto allocated
    function addAutoAllocation(uint256 _amount) external nonReentrant {
        require(_amount != 0);
        Holder storage holder = holderHistory[msg.sender];
        uint256 currentEpoch;
        if(epochVault.getStartTime() != 0) {
            currentEpoch = epochVault.getCurrentEpoch();
        } 
        uint256 boost = ICreditBonds(payable(controller.creditBonds())).getPersonalBoost(
            msg.sender, 
            currentEpoch
        );
        uint256 nominalAllocationPower = 
            (10_000e18 + boost * 1e18) * holder.amountLocked / 10_000e18;
        require(
            holder.amountAllocated[currentEpoch] + _amount <= nominalAllocationPower
        );
        if(
            holder.listOfEpochs.length == 0 
            || holder.listOfEpochs[holder.listOfEpochs.length - 1] != currentEpoch
        ) {
            holder.listOfEpochs.push(currentEpoch);
        }
        holder.amountAllocated[currentEpoch] += _amount;
        holder.amountAutoAllocated[currentEpoch] += _amount;
        totalAllocationPerEpoch[currentEpoch] += _amount;
        totalAmountAutoAllocated[currentEpoch] += _amount;
        
        emit AutoAllocate(msg.sender, currentEpoch, _amount);
    }

    /* ======== BRIBE ======== */
    /// @notice Bribe auto allocators to direct auto allocated ABC towards a chosen collection
    /// @dev If there are no auto allocators, the briber can reclaim the submitted bribe
    /// @param _collection The collection to direct auto allocated ABC towards
    function bribeAuto(address _collection) external payable nonReentrant {
        uint256 currentEpoch;
        if(epochVault.getStartTime() != 0) {
            currentEpoch = epochVault.getCurrentEpoch();
        } 

        bribeOffered[msg.sender][currentEpoch] += msg.value;
        bribesPerCollectionPerEpoch[currentEpoch][_collection] += msg.value;
        totalBribesPerEpoch[currentEpoch] += msg.value;
        
        emit BribeOffered(msg.sender, _collection, currentEpoch, msg.value);
    }

    /* ======== REWARDS ======== */
    /// @notice Claim accrued fees (from bribes and protocol generated fees)
    /// @dev If fees go unclaimed for 25 epochs of allocation, this will be automagically called
    /// @param _user The user that is claiming rewards
    function claimReward(address _user) external nonReentrant2 {
        uint256 currentEpoch;
        if(epochVault.getStartTime() != 0) {
            currentEpoch = epochVault.getCurrentEpoch();
        } 
        require(
            msg.sender == _user
            || msg.sender == address(this)
        );
        Holder storage holder = holderHistory[_user];
        uint256 totalPayout;
        uint256 length = holder.listOfEpochs.length;
        for(uint256 j = 0; j < length; j++) {
            uint256 epochNum = holder.listOfEpochs[j];
            require(currentEpoch > epochNum);
            if(holder.amountAutoAllocated[epochNum] == 0) {
                totalPayout += 0;
            } else {
                totalPayout += totalBribesPerEpoch[epochNum] * holder.amountAutoAllocated[epochNum] 
                    / totalAmountAutoAllocated[epochNum];
            }
            totalPayout += epochFeesAccumulated[epochNum] * holder.amountAllocated[epochNum] 
                / totalAllocationPerEpoch[epochNum];
        }

        delete holder.listOfEpochs;
        payable(_user).transfer(totalPayout);
        emit RewardClaimed(_user, totalPayout);
    }

    /* ======== BOOST & VOTING ======== */
    /// @notice For bribers to reclaim any unused bribes (if auto allocation was 0)
    /// @param _epoch The desired epoch to claim unused bribes from
    function reclaimUnusedBribe(uint256 _epoch) external nonReentrant {
        uint256 currentEpoch;
        if(epochVault.getStartTime() != 0) {
            currentEpoch = epochVault.getCurrentEpoch();
        } 
        require(_epoch < currentEpoch);
        require(totalAmountAutoAllocated[_epoch] == 0);
        uint256 payout = bribeOffered[msg.sender][_epoch];
        delete bribeOffered[msg.sender][_epoch];
        payable(msg.sender).transfer(payout);
    }

    /// @notice Used to clear protocol generated fees to treasury
    /// @dev This also includes any fees that have been directed towards an epoch where
    /// there were no EDC earned. The caller receives 0.5% of the empty epoch fees
    /// @param _epoch The desired epoch to clear funds from
    function clearToTreasury(uint256 _epoch) external nonReentrant {
        uint256 currentEpoch;
        if(epochVault.getStartTime() != 0) {
            currentEpoch = epochVault.getCurrentEpoch();
        } 
        require(_epoch < currentEpoch);
        uint256 payout;
        if(totalAllocationPerEpoch[_epoch] == 0) {
            payout = epochFeesAccumulated[_epoch];
            epochFeesAccumulated[_epoch] = 0;
        }

        uint256 multisigPayout = 995 * (payout + fundsForTreasury) / 1000;
        payable(controller.multisig()).transfer(multisigPayout);
        payable(msg.sender).transfer(payout + fundsForTreasury - multisigPayout);
        fundsForTreasury = 0;

        emit FundsClearedToTreasury(msg.sender, _epoch, payout);
    }

    /* ======== GETTERS ======== */
    /// @notice Calculates a collections boost based on ABC allocation
    /// @dev This function returns the result as a numerator and denominator in an 
    /// attempt to savor precision on the receiving contract
    /// @param _collection The collection of interest 
    /// @return numerator The total amount of ABC allocated towards the collection (includes auto)
    /// @return denominator The total amount of ABC allocated
    function calculateBoost(address _collection) external view returns(
        uint256 numerator, 
        uint256 denominator
    ) {
        if(epochVault.getCurrentEpoch() == 0) {
            return(0,0);
        }
        uint256 recentEpoch = epochVault.getCurrentEpoch()-1;
        uint256 _autoAllocation = totalAmountAutoAllocated[recentEpoch];
        uint256 _collectionBribe = bribesPerCollectionPerEpoch[recentEpoch][_collection];
        uint256 _totalBribe = totalBribesPerEpoch[recentEpoch];
        uint256 _collectionAllocation = totalAllocationPerCollection[recentEpoch][_collection];

        if(_autoAllocation * _collectionBribe * _totalBribe == 0) {
            numerator = _collectionAllocation;
        } else {
            numerator = _collectionAllocation + _autoAllocation * _collectionBribe / _totalBribe;
        }
        denominator = totalAllocationPerEpoch[recentEpoch];
    }

    /// @notice Returns total ETH fees that have been accumulated during the current epoch
    function getEpochFeesAccumulated() external view returns(uint256) {
        uint256 currentEpoch;
        if(epochVault.getStartTime() != 0) {
            currentEpoch = epochVault.getCurrentEpoch();
        } 
        return epochFeesAccumulated[currentEpoch];
    }

    /// @notice The total ABC deposited by a user
    /// @param _user The user of interest
    /// @return amount Amount of ABC deposited
    function getTokensLocked(address _user) external view returns(uint256 amount) {
        amount = holderHistory[_user].amountLocked;
    }

    /// @notice The amount of ABC that a user auto allocted during an epoch 
    /// @param _user User of interest
    /// @param _epoch Epoch of interest
    /// @return amount Amount of ABC auto allocated
    function getAmountAutoAllocated(
        address _user, 
        uint256 _epoch
    ) external view returns(uint256 amount) {
        amount = holderHistory[_user].amountAutoAllocated[_epoch];
    }

    /// @notice The total amount of ABC that a user has allocated (auto and explicit)
    /// @param _user User of interest
    /// @param _epoch Epoch of interest
    /// @return amount The amount of allocated ABC
    function getAmountAllocated(
        address _user, 
        uint256 _epoch
    ) external view returns(uint256 amount) {
        amount = holderHistory[_user].amountAllocated[_epoch];
    }

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
    ) external view returns(uint256 allocation) {
        allocation = holderHistory[_user].allocationPerCollection[_epoch][_collection];
    }

    /// @notice The rewards that a user has currently earned
    /// @param _user User of interest
    /// @return rewards Amount of rewards earned
    function getRewards(address _user) external view returns(uint256 rewards) {
        Holder storage holder = holderHistory[_user];
        uint256 length = holder.listOfEpochs.length;
        for(uint256 j = 0; j < length; j++) {
            uint256 epochNum = holder.listOfEpochs[j];
            if(totalAmountAutoAllocated[epochNum] == 0) {
                rewards += 0;
            } else {
                rewards += totalBribesPerEpoch[epochNum] * holder.amountAutoAllocated[epochNum] 
                    / totalAmountAutoAllocated[epochNum];
            }
            rewards += epochFeesAccumulated[epochNum] * holder.amountAllocated[epochNum] 
                / totalAllocationPerEpoch[epochNum];
            if(epochNum == 0) break;
        }
    }
}