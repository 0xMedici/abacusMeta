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

/// @title veABC Token
/// @author Gio Medici
/// @notice Voting escrowed ABC token
contract VeABC is ERC20, ReentrancyGuard, ReentrancyGuard2 {

    /* ======== ADDRESS ======== */
    
    /// @notice configure directory contract
    AbacusController public controller;

    /* ======== UINT ======== */

    /// @notice funds available for treasury
    uint256 public fundsForTreasury;

    /* ======== MAPPING ======== */

    /// @notice track history of each address
    mapping(address => Holder) public veHolderHistory;

    /// @notice track fees accumulated in each epoch
    mapping(uint256 => uint256) public epochFeesAccumulated;

    /// @notice veABC volume in each epoch 
    mapping(uint256 => uint256) public veAbcVolPerEpoch;

    /// @notice total amount of auto allocated veABC
    mapping(uint256 => uint256) public totalAmountAutoAllocated;

    /// @notice total amount of allocated veABC
    mapping(uint256 => uint256) public totalAllocationPerEpoch;
    
    /// @notice total bribes in each epoch 
    mapping(uint256 => uint256) public totalBribesPerEpoch;

    /// @notice track allocation per collection per epoch
    mapping(uint256 => mapping(address => uint256)) public totalAllocationPerCollection;

    /// @notice track bribes per collection per epoch 
    mapping(uint256 => mapping(address => uint256)) public bribesPerCollectionPerEpoch;

    /* ======== STRUCT ======== */

    /// @notice veABC holder profile
    /** 
    @dev (1) lastEpochClaimed -> used as a claim checkpoint
         (2) concludingEpoch -> log users last locked epoch
         (3) timeUnlock -> time at which ABC unlocks
         (4) amountLocked -> amount of ABC locked
         (5) vePerEpoch -> ve holdings per epoch
         (6) amountAllocated -> total amount allocated to collections
         (7) amountAutoAllocated -> total amount auto allocated
         (8) allocationPerCollection -> track allocation per collection
    */
    struct Holder {
        uint256 lastEpochClaimed;
        uint256 concludingEpoch;
        uint256 timeUnlock;
        uint256 amountLocked;
        mapping(uint256 => uint256) vePerEpoch;
        mapping(uint256 => uint256) amountAllocated;
        mapping(uint256 => uint256) amountAutoAllocated;
        mapping(uint256 => mapping(address => uint256)) allocationPerCollection;
    }

    /* ======== STRUCT ======== */

    event TokensLocked(address _user, uint256 _lockTime, uint256 _amountLocked);
    event TokensAdded(address _user, uint256 _amountLocked);
    event TokensUnlocked(address _user, uint256 _amountUnlocked);
    event AllocatedToCollection(uint256 epoch, address _user, address _collection, uint256 _amountAdded);
    event ChangedAllocation(uint256 epoch, address _user, address _oldCollection, address _newCollection, uint256 _amountChanged); 
    event AutoAllocated(address _user, uint256 _amountAdded);
    event BribePaid(address _user, address _collection, uint256 _amount);
    event StakeRewardClaimed(address _user, uint256 _reward);
    event BribeRewardClaimed(address _user, uint256 _reward);

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller) ERC20("Voting Escrowed ABC", "veABC") {
        controller = AbacusController(_controller);
    }

    /* ======== SETTER ======== */

    function setController(address _controller) external {
        require(msg.sender == controller.admin());
        controller = AbacusController(_controller);
    }

    /* ======== TOKEN INTERACTION ======== */

    /// @notice restrict trasnfer from call to veABC contract
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        require(msg.sender == address(this));
        _transfer(sender, recipient, amount);

        return true;
    }

    /// @notice these tokens are non-transferrable
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(false);
    }

    /* ======== EPOCH CONFIG ======== */

    /// @notice add on to veABC holder ETH distribution reward for `epoch` of choice
    function donateToEpoch(uint256 epoch) payable external {
        epochFeesAccumulated[epoch] += msg.value;
    }

    /// @notice receive and log fees generated
    function receiveFees() payable external {
        require(controller.accreditedAddresses(msg.sender));
        epochFeesAccumulated[IEpochVault(controller.epochVault()).getCurrentEpoch()] += msg.value;
    }

    /* ======== LOCKING ======== */

    /// @notice lock tokens for set amount of time in exchange for veABC
    /// @dev function can only be called if the user currently has no locked token balance
    /// @param _amount how much ABC the user would like to lock
    /// @param _time amount of time they'd like to lock it for
    function lockTokens(uint256 _amount, uint256 _time) nonReentrant external {
        takePayment(msg.sender);
        
        Holder storage holder = veHolderHistory[msg.sender];

        //max lock time is 16 weeks
        require(_time <= 10 days);
        require(_time / 2 days != 0);
        require(holder.timeUnlock == 0);

        //configure lock as rounded the the 2 weeks mark and calculate multiplier
        uint256 _timeLock = (_time / 2 days) * 2 days;
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        holder.timeUnlock = block.timestamp + _timeLock;
        holder.amountLocked = _amount;
        holder.lastEpochClaimed = currentEpoch;
        holder.concludingEpoch = currentEpoch + (_time / 2 days);
        uint256 veAmount = (holder.concludingEpoch - currentEpoch) * _amount;

        //lock user tokens
        ABCToken(controller.abcToken()).bypassTransfer(msg.sender, address(this), _amount);

        //mint new veABC and update ve epoch log
        _mint(msg.sender, veAmount);

        uint256 boost;

        //Record increase in total veAbc locked in the current epoch.
        for(uint256 i = currentEpoch; i < holder.concludingEpoch; i++) {
            if(i == currentEpoch) boost = ICreditBonds(payable(controller.creditBonds())).getPersonalBoost(msg.sender, currentEpoch);
            else boost = 0;
            veAbcVolPerEpoch[i] += (10_000e18 + boost * 1e18) * veAmount / 10_000e18;
            holder.vePerEpoch[i] += (10_000e18 + boost * 1e18) * veAmount / 10_000e18;
        }
        
        emit TokensLocked(msg.sender, _timeLock, _amount);
    }

    /// @notice lock tokens for set amount of time in exchange for veABC
    /// @dev function can only be called if the user currently has a locked token balance
    /// @param _amount how much ABC the user would like to lock
    function addTokens(uint256 _amount) nonReentrant external {
        takePayment(msg.sender);

        Holder storage holder = veHolderHistory[msg.sender];

        //make sure that the user already has tokens locked
        require(holder.timeUnlock != 0);
        require(holder.timeUnlock > block.timestamp);
        
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        uint256 veAmount = (holder.concludingEpoch - currentEpoch) * _amount;

        //lock user tokens
        ABCToken(controller.abcToken()).bypassTransfer(msg.sender, address(this), _amount);
        holder.amountLocked += _amount;

        //mint new veABC and update epoch log
        _mint(msg.sender, veAmount);

        uint256 boost;

        //Record increase in total veAbc locked in the current epoch.
        for(uint256 i = currentEpoch; i < holder.concludingEpoch; i++) {
            if(i == currentEpoch) boost = ICreditBonds(payable(controller.creditBonds())).getPersonalBoost(msg.sender, currentEpoch);
            else boost = 0;
            veAbcVolPerEpoch[i] += (10_000e18 + boost * 1e18) * (holder.concludingEpoch - i) * _amount / 10_000e18;
            holder.vePerEpoch[i] += (10_000e18 + boost * 1e18) * (holder.concludingEpoch - i) * _amount / 10_000e18;
        }

        emit TokensAdded(msg.sender, _amount);
    }

    /// @notice unlock all locked tokens
    /// @dev only callable after the users maturity has completed
    function unlockTokens() nonReentrant2 external {
        Holder storage holder = veHolderHistory[msg.sender];

        require(holder.timeUnlock <= block.timestamp);
        if(holder.lastEpochClaimed != holder.concludingEpoch) {
            this.claimRewards(msg.sender);
        }

        takePayment(msg.sender);

        //verify unlock time has passed and user has removed all allocation
        uint256 tokensLocked = holder.amountLocked;
        
        //clear position cache
        delete holder.amountLocked;
        delete holder.timeUnlock;
        delete holder.concludingEpoch;

        //burn veABC tokens and return ABC
        _burn(msg.sender, balanceOf(msg.sender));
        ABCToken(controller.abcToken()).bypassTransfer(address(this), msg.sender, tokensLocked);

        emit TokensUnlocked(msg.sender, tokensLocked);
    }

    /// @notice updates a users amount of ve in a given epoch based on their credit bond boost
    function updateVeSize(address _user, uint256 epoch) external {
        require(msg.sender == controller.creditBonds());
        Holder storage holder = veHolderHistory[msg.sender];
        uint256 boost = ICreditBonds(payable(controller.creditBonds())).getPersonalBoost(_user, IEpochVault(controller.epochVault()).getCurrentEpoch());
        uint256 amountBeforeBoost = holder.vePerEpoch[epoch];

        holder.vePerEpoch[epoch] = (10_000e18 + boost * 1e18) * holder.vePerEpoch[epoch] / 10_000e18;
        veAbcVolPerEpoch[epoch] += holder.vePerEpoch[epoch] - amountBeforeBoost;
    }

    /* ======== ALLOCATING ======== */

    /// @notice allocate veABC to collection gauge
    /// @dev increase the total allocation for a collection of user choice
    /// @param _collection the address of chosen NFT
    /// @param _amount the amount of veABC power to be allocated
    function allocateToCollection(address _collection, uint256 _amount) nonReentrant external {
        takePayment(msg.sender);

        Holder storage holder = veHolderHistory[msg.sender];
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        require(holder.amountAllocated[currentEpoch] + _amount <= balanceOf(msg.sender));
        
        // adjust allocation trackers
        holder.amountAllocated[currentEpoch] += _amount;
        holder.allocationPerCollection[currentEpoch][_collection] += _amount;
        totalAllocationPerCollection[currentEpoch][_collection] += _amount;
        totalAllocationPerEpoch[currentEpoch] += _amount;
        
        emit AllocatedToCollection(currentEpoch, msg.sender, _collection, _amount);
    }

    function changeAllocation(address _oldCollection, address _newCollection, uint256 _amount) nonReentrant external {
        takePayment(msg.sender);

        Holder storage holder = veHolderHistory[msg.sender];
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        require(holder.amountAllocated[currentEpoch] + _amount <= balanceOf(msg.sender));
        
        // adjust allocation trackers
        holder.allocationPerCollection[currentEpoch][_oldCollection] -= _amount;
        totalAllocationPerCollection[currentEpoch][_oldCollection] -= _amount;
        holder.allocationPerCollection[currentEpoch][_newCollection] += _amount;
        totalAllocationPerCollection[currentEpoch][_newCollection] += _amount;

        emit ChangedAllocation(currentEpoch, msg.sender, _oldCollection, _newCollection, _amount);
    }

    /// @notice add voting power to auto allocation pot
    /// @param _amount total amount of veABC voting power that user would like to auto allocate
    function addAutoAllocation(uint256 _amount) nonReentrant external {
        takePayment(msg.sender);

        Holder storage holder = veHolderHistory[msg.sender];
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        require(holder.amountAllocated[currentEpoch] + _amount <= balanceOf(msg.sender));

        // collection marked to be checked for allocation balance
        holder.amountAllocated[currentEpoch] += _amount;
        holder.amountAutoAllocated[currentEpoch] += _amount;
        totalAllocationPerEpoch[currentEpoch] += _amount;
        totalAmountAutoAllocated[currentEpoch] += _amount;
        
        emit AutoAllocated(msg.sender, _amount);
    }

    /* ======== BRIBE ======== */

    /// @notice bribe auto allocation
    /// @dev add bribe for auto allocators to decide which collection gets their vote in next gauge reset
    /// @param _collection which collection to submit the bribe for
    function bribeAuto(address _collection) nonReentrant payable external {
        takePayment(msg.sender);

        IEpochVault eVault = IEpochVault(controller.epochVault());
        uint256 currentEpoch = eVault.getCurrentEpoch();

        // record bribe allocation
        bribesPerCollectionPerEpoch[currentEpoch][_collection] += msg.value;
        totalBribesPerEpoch[eVault.getCurrentEpoch()] += msg.value;
        
        emit BribePaid(msg.sender, _collection, msg.value);
    }

    /// @notice encompasses reward claims for auto and ve rewards
    function claimRewards(address _user) external {
        require(msg.sender == _user || msg.sender == address(this));
        IEpochVault eVault = IEpochVault(controller.epochVault());
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        if(eVault.getEpochEndTime(currentEpoch) < block.timestamp) {
            eVault.endEpoch();
        }
        claimAutoReward(_user);
        claimVeHolderReward(_user);
    } 

    /* ======== REWARDS ======== */

    /// @notice claim rewards for auto allocation
    function claimAutoReward(address _user) nonReentrant internal {
        takePayment(_user);

        Holder storage holder = veHolderHistory[_user]; 
        uint256 lastEpochClaimed = holder.lastEpochClaimed;
        uint256 totalPayout;

        // claim rewards up to current epoch 
        for(uint256 j = holder.lastEpochClaimed; j < holder.concludingEpoch; j++) {
            if(lastEpochClaimed == IEpochVault(controller.epochVault()).getCurrentEpoch() - 1) {
                holder.lastEpochClaimed = lastEpochClaimed;
                break;
            }
            totalPayout += totalBribesPerEpoch[j] * holder.amountAutoAllocated[j] / totalAmountAutoAllocated[j];
            lastEpochClaimed++;
        }

        // send reward to holder
        payable(_user).transfer(totalPayout);
        
        emit BribeRewardClaimed(_user, totalPayout);
    }

    /// @notice claim rewards for holding veABC
    function claimVeHolderReward(address _user) nonReentrant internal {
        takePayment(_user);

        Holder storage holder = veHolderHistory[_user];
        uint256 lastEpochClaimed = holder.lastEpochClaimed;
        uint256 totalPayout;

        // claim rewards up to current epoch 
        for(uint256 j = holder.lastEpochClaimed; j < holder.concludingEpoch; j++) {
            if(lastEpochClaimed == IEpochVault(controller.epochVault()).getCurrentEpoch() - 1) {
                holder.lastEpochClaimed = lastEpochClaimed;
                break;
            }
            totalPayout += epochFeesAccumulated[j] * holder.vePerEpoch[j] / veAbcVolPerEpoch[j];
            lastEpochClaimed++;
        }

        // send reward to holder
        payable(_user).transfer(totalPayout);
        
        emit StakeRewardClaimed(_user, totalPayout);
    }

    /* ======== BOOST & VOTING ======== */

    /// @notice calculate the collections credit generation boost
    /// @param _collection the collection whos boost is being queried
    /// @return numerator used for higher precision on boost calculation side
    /// @return denominator used for higher precision on boost calculation side
    function calculateBoost(address _collection) view external returns(uint256 numerator, uint256 denominator) {
        if(IEpochVault(controller.epochVault()).getCurrentEpoch() == 0) {
            return(0,0);
        }
        uint256 recentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch()-1;

        // total auto allocation in the epoch in question
        uint256 _autoAllocation = totalAmountAutoAllocated[recentEpoch];
        
        // total bribes aimed at this collection
        uint256 _collectionBribe = bribesPerCollectionPerEpoch[recentEpoch][_collection];

        // total bribes in the epoch
        uint256 _totalBribe = totalBribesPerEpoch[recentEpoch];

        // total amount allocated to collection
        uint256 _collectionAllocation = totalAllocationPerCollection[recentEpoch][_collection];

        uint256 _totalAllocation = totalAllocationPerEpoch[recentEpoch];

        // return a numerator and denominator for multiplier to calculate
        if(_autoAllocation * _collectionBribe * _totalBribe == 0) numerator = _collectionAllocation;
        else numerator = _collectionAllocation + _autoAllocation * _collectionBribe / _totalBribe;
        denominator = _totalAllocation;
    }

    /// @notice clears any "funds without a home" to treasury
    function clearToTreasury() nonReentrant external {
        payable(controller.abcTreasury()).transfer(fundsForTreasury);
        fundsForTreasury = 0;
    }

    /// @notice take the abc gas fee when users execute core action functions
    function takePayment(address _user) internal {
        ABCToken(controller.abcToken()).bypassTransfer(_user, controller.epochVault(), controller.abcGasFee());
        IEpochVault(controller.epochVault()).receiveAbc(controller.abcGasFee());
    }

    /// @notice returns `_user` ve amount for an `_epoch` of choice
    function getVeAmount(address _user, uint256 _epoch) view external returns(uint256 amount) {
        amount = veHolderHistory[_user].vePerEpoch[_epoch];
    }

    /// @notice returns `_user` amount auto allocated in an `_epoch`
    function getAmountAutoAllocated(address _user, uint256 _epoch) view external returns(uint256 amount) {
        amount = veHolderHistory[_user].amountAutoAllocated[_epoch];
    }

    /// @notice returns the amount a user has allocated to a pool
    function getAmountAllocated(address _user) view external returns(uint256 amount) {
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        amount = veHolderHistory[_user].amountAllocated[currentEpoch];
    }

    /// @notice return total allocation per NFT collection
    function getAllocationPerCollection(address _collection, address _user) view external returns(uint256 allocation) {
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        allocation = veHolderHistory[_user].allocationPerCollection[currentEpoch][_collection];
    }
}