//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { ABCToken } from "./AbcToken.sol";
import { IAllocator } from "./interfaces/IAllocator.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";

import { IERC20 } from "./interfaces/IERC20.sol";
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

/// @title Governor
/// @author Gio Medici
/// @notice Governing contract where all Abacus voting will occur and execute
contract Governor {

    AbacusController public controller;
    ABCToken public token;

    /* ======== UINT ======== */
    /// @notice Votes in favor of current proposal
    uint256 public voteFor;

    /// @notice Votes against current proposal
    uint256 public voteAgainst;

    /// @notice Voting end time for positional movement proposal
    uint256 public voteEndTime;

    /// @notice Proposed positional movement value
    uint256 public pendingPositionalMovement;

    /// @notice Total amount of positional movement experienced
    uint256 public totalPositionalMovement;

    /// @notice Marginal postiional movement value
    uint256 public positionalMovement;

    /// @notice Amount of positional changes
    uint256 public positionalChanges;

    /* ======== BOOL ======== */
    /// @notice Tracks if challenge is active
    bool public challengeUsed;

    /* ======== MAPPINGS ======== */
    /// @notice User proposer credit locked
    mapping(address => uint256) public credit;

    /// @notice Time that user poroposer credits unlock
    mapping(address => uint256) public timeCreditsUnlock;

    /// @notice User voting credit locked
    mapping(address => uint256) public votingCredit;

    /// @notice Time that user voting credits unlock
    mapping(address => uint256) public timeVotingCreditsUnlock;

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller, address _token) {
        controller = AbacusController(_controller);
        token = ABCToken(_token);
        positionalMovement = 2_000_000e18;
    }

    /// @notice Lock in proposer credits
    /// @dev proposing a vote requires that the proposer has varying amounts of credit locked
    /// 1. Whitelisting collection - 20m ABC locked
    /// 2. Removing whitelisted collection - 20m ABC locked
    /// 3. Factory addition - 100m ABC locked 
    /// 4. Positional movement update - 50m ABC locked
    function lockCredit(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount));
        credit[msg.sender] += amount;
    }

    /// @notice Claim tokens that have unlocked since their original vote locking following a vote
    function claimVoteLocked() external {
        require(block.timestamp > timeVotingCreditsUnlock[msg.sender]);
        uint256 payout = votingCredit[msg.sender];
        delete votingCredit[msg.sender];
        delete timeVotingCreditsUnlock[msg.sender];
        token.transfer(msg.sender, payout);
    }

    /// @notice Claim credits that have unlocked since their original locking following a proposal
    function claimCredit() external {
        require(block.timestamp > timeCreditsUnlock[msg.sender]);
        uint256 payout = credit[msg.sender];
        delete credit[msg.sender];
        delete timeCreditsUnlock[msg.sender];
        token.transfer(msg.sender, payout);
    }

    /// @notice Propose a new positional marginal positional movement
    /// @dev Positional movement determines how much the required quorum increases after each
    /// factory addition. This value can only be increased. 
    /// - The proposer will need to have 50m ABC which will be locked for 21 days.
    /// - This proposal can only be submitted in the first 7 days of an epoch. 
    function proposePositionalMovement(uint256 _proposedSize) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(!controller.changeLive());
        require(credit[msg.sender] >= 50_000_000e18);
        require(_proposedSize > positionalMovement);
        require(pendingPositionalMovement == 0);
        uint256 currentEpoch;
        if(IEpochVault(controller.epochVault()).getStartTime() == 0) currentEpoch == 0;
        else currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        require(IEpochVault(controller.epochVault()).getEpochEndTime(currentEpoch) > block.timestamp + 23 days);
        timeCreditsUnlock[msg.sender] = block.timestamp + 21 days;
        pendingPositionalMovement = _proposedSize;
        voteEndTime = block.timestamp + 7 days;
    }
    
    /// @notice Vote on a positional movement proposal
    /// @dev Any ABC used to vote will be locked for 9 days
    function votePositionalMovement(bool vote, uint256 amount) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(voteEndTime > block.timestamp);
        require(pendingPositionalMovement != 0);
        require(token.transferFrom(msg.sender, address(this), amount));
        votingCredit[msg.sender] += amount;
        timeVotingCreditsUnlock[msg.sender] = block.timestamp + 9 days;
        if(vote) {
            voteFor += amount;
        } else {
            voteAgainst += amount;
        }
    }

    /// @notice Approve the positional movement proposal
    /// @dev Requirements for approval
    /// 1. 250m + 25m * total amount of positional changes worth of quorum
    /// 2. More votes in favor than votes against
    function movementAcceptance() external {
        require(pendingPositionalMovement != 0);
        require(block.timestamp > voteEndTime);
        require(voteFor + voteAgainst > 250_000_000e18 + 25_000_000e18 * positionalChanges);
        require(voteFor > voteAgainst);
        delete voteFor;
        delete voteAgainst;
        positionalMovement = pendingPositionalMovement;
        positionalChanges++;
        delete pendingPositionalMovement;
    }

    /// @notice Reject the positional movement proposal 
    function movementRejection() external {
        require(pendingPositionalMovement != 0);
        require(block.timestamp > voteEndTime);
        require(
            voteAgainst >= voteFor
            || voteFor + voteAgainst <= 250_000_000e18 + 25_000_000e18 * positionalChanges
        );
        delete voteFor;
        delete voteAgainst;
        delete pendingPositionalMovement;
    }

    /// @notice Propose a new set of collections to be whitelisted
    /// @dev
    /// - The proposer will need to have 20m ABC which will be locked for 10 days.
    /// - This proposal can only be submitted in the first 16 days of an epoch. 
    function proposeNewCollection(address[] memory collections) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(collections.length > 0);
        require(!controller.changeLive());
        require(pendingPositionalMovement == 0);
        require(credit[msg.sender] >= 20_000_000e18);
        require(collections[0] != address(0));
        uint256 currentEpoch;
        if(IEpochVault(controller.epochVault()).getStartTime() == 0) currentEpoch == 0;
        else currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        require(IEpochVault(controller.epochVault()).getEpochEndTime(currentEpoch) > block.timestamp + 14 days);
        timeCreditsUnlock[msg.sender] = block.timestamp + 10 days;
        controller.proposeWLAddresses(collections);
    } 

    /// @notice Vote on a whitelist proposal
    /// @dev Any ABC used to vote will be locked for 7 days
    function voteNewCollections(bool vote, uint256 amount) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(block.timestamp < controller.voteEndTime());
        require(controller.changeLive());
        require(controller.pendingWLAdditions(0) != address(0));
        require(token.transferFrom(msg.sender, address(this), amount));
        votingCredit[msg.sender] += amount;
        timeVotingCreditsUnlock[msg.sender] = block.timestamp + 7 days;
        if(vote) {
            voteFor += amount;
        } else {
            voteAgainst += amount;
        }
    }

    /// @notice Approve the whitelist collection proposal
    /// @dev Requirements for approval
    /// 1. 100m or 2% of the supply (whichever is greater) of ABC worth of quorum
    /// 2. More votes in favor than votes against
    function newCollectionAcceptance() external {
        require(controller.changeLive());
        require(controller.pendingWLAdditions(0) != address(0));
        require(block.timestamp > controller.voteEndTime());
        require(voteFor + voteAgainst > (100_000_000e18 > (2 * token.totalSupply() / 100) ? 100_000_000e18 : (2 * token.totalSupply() / 100)));
        require(voteFor > voteAgainst);
        delete voteFor;
        delete voteAgainst;
        controller.approveWLAddresses();
    }

    /// @notice Reject the collection whitelist proposal
    function newCollectionRejection() external {
        require(controller.changeLive());
        require(controller.pendingWLAdditions(0) != address(0));
        require(block.timestamp > controller.voteEndTime());
        require(
            voteFor + voteAgainst <= (100_000_000e18 > (2 * token.totalSupply() / 100) ? 100_000_000e18 : (2 * token.totalSupply() / 100))
            || voteAgainst >= voteFor
        );
        delete voteFor;
        delete voteAgainst;
        controller.rejectWLAddresses();
    }

    /// @notice Propose a collection to be removed from the whitelist
    /// @dev
    /// - The proposer will need to have 20m ABC which will be locked for 10 days.
    /// - This proposal can only be submitted in the first 16 days of an epoch. 
    function proposeRemoveCollection(address[] memory collections) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(block.timestamp > controller.voteEndTime() + 7 days);
        require(!controller.changeLive());
        require(pendingPositionalMovement == 0);
        require(credit[msg.sender] >= 20_000_000e18);
        require(collections[0] != address(0));
        uint256 currentEpoch;
        if(IEpochVault(controller.epochVault()).getStartTime() == 0) currentEpoch == 0;
        else currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        require(IEpochVault(controller.epochVault()).getEpochEndTime(currentEpoch) > block.timestamp + 14 days);
        timeCreditsUnlock[msg.sender] = block.timestamp + 10 days;
        controller.proposeWLRemoval(collections);
    }

    /// @notice Vote on a whitelist removal proposal
    /// @dev Any ABC used to vote will be locked for 7 days
    function voteRemoveCollection(bool vote, uint256 amount) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(controller.changeLive());
        require(block.timestamp < controller.voteEndTime());
        require(controller.pendingWLRemoval(0) != address(0));
        require(token.transferFrom(msg.sender, address(this), amount));
        votingCredit[msg.sender] += amount;
        timeVotingCreditsUnlock[msg.sender] = block.timestamp + 7 days;
        if(vote) {
            voteFor += amount;
        } else {
            voteAgainst += amount;
        }
    }

    /// @notice Approve the whitelist removal proposal
    /// @dev Requirements for approval
    /// 1. 100m or 2% of the supply (whichever is greater) of ABC worth of quorum
    /// 2. More votes in favor than votes against
    function removeCollectionAcceptance() external {
        require(controller.changeLive());
        require(controller.pendingWLRemoval(0) != address(0));
        require(block.timestamp > controller.voteEndTime());
        require(voteFor + voteAgainst > (100_000_000e18 > (2 * token.totalSupply() / 100) ? 100_000_000e18 : (2 * token.totalSupply() / 100)));
        require(voteFor > voteAgainst);
        delete voteFor;
        delete voteAgainst;
        controller.approveWLRemoval();
    }

    /// @notice Reject the collection removal proposal
    function removeCollectionRejection() external {
        require(controller.changeLive());
        require(controller.pendingWLRemoval(0) != address(0));
        require(block.timestamp > controller.voteEndTime());
        require(
            voteFor + voteAgainst <= (100_000_000e18 > (2 * token.totalSupply() / 100) ? 100_000_000e18 : (2 * token.totalSupply() / 100))
            || voteAgainst >= voteFor
        );
        delete voteFor;
        delete voteAgainst;
        controller.rejectWLRemoval();
    }

    /// @notice Propose the addition of a new factory contract
    /// @dev Factory contracts are responsible for creating new Spot pools
    /// and have the ability to create accredited addresses which can create  
    /// new epoch distribution credits. 
    /// - The proposer will need to have 100m ABC which will be locked for 30 days.
    /// - This proposal can only be submitted in the first 7 days of an epoch. 
    function proposeFactoryAddition(address factory) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(!controller.changeLive());
        require(pendingPositionalMovement == 0);
        require(credit[msg.sender] >= 100_000_000e18);
        uint256 currentEpoch;
        if(IEpochVault(controller.epochVault()).getStartTime() == 0) currentEpoch == 0;
        else currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        require(IEpochVault(controller.epochVault()).getEpochEndTime(currentEpoch) > block.timestamp + 23 days);
        timeCreditsUnlock[msg.sender] = block.timestamp + 30 days;
        controller.proposeFactoryAddition(factory);
    }

    /// @notice Vote on whether or not to instate the proposed factory
    /// @dev Any ABC used to vote will be locked for 20 days
    function voteFactoryAddition(bool vote, uint256 amount) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(controller.changeLive());
        require(block.timestamp < controller.voteEndTime());
        require(controller.pendingFactory() != address(0));

        if(challengeUsed) require(controller.voteEndTime() + 10 days > timeVotingCreditsUnlock[msg.sender]);
        if(challengeUsed && amount > votingCredit[msg.sender]) {
            require(
                token.transferFrom(
                    msg.sender,
                    address(this),
                    amount - votingCredit[msg.sender]
                )
            );
            votingCredit[msg.sender] += amount - votingCredit[msg.sender];
        } else if(!challengeUsed) {
            require(token.transferFrom(msg.sender, address(this), amount));
            votingCredit[msg.sender] += amount;
        }
        timeVotingCreditsUnlock[msg.sender] = block.timestamp + 20 days;
        if(vote) {
            voteFor += amount;
        } else {
            voteAgainst += amount;
        }
    }

    /// @notice In the case that a factory is approved, anyone can come challenge the vote.
    /// @dev When a vote is challenged the old vote is erased and a new vote is started.
    /// the result of this new vote will be finalized upon completion without a 30 day
    /// grace period or ability to challenge. 
    function challengeAdditionVote() external {
        require(!challengeUsed);
        require(controller.changeLive());
        require(controller.pendingFactory() != address(0));
        require(
            block.timestamp > controller.voteEndTime()
            && block.timestamp < controller.voteEndTime() + 30 days
        );
        require(voteFor + voteAgainst > 500_000_000e18 + totalPositionalMovement);
        require(voteAgainst < 20 * token.totalSupply() / 100);
        require(voteFor > voteAgainst);
        delete voteFor;
        delete voteAgainst;
        address factory = controller.pendingFactory();
        controller.rejectFactoryAddition();
        controller.proposeFactoryAddition(factory);
        challengeUsed = true;
    }

    /// @notice Approve the factory to have Spot pool production rights
    /// @dev Requirements for approval
    /// 1. 500m + total positional movement of ABC worth of quorum
    /// 2. More votes in favor than votes against
    /// 3. Less than 300m ABC voting against the proposal
    /// 4. Challenge issued and lost OR 30 day grace period passed
    /// After the vote is accepted, the total positional movement requirement updates
    /// and the required quorum increases. 
    function factoryAdditionAcceptance() external {
        require(controller.changeLive());
        require(controller.pendingFactory() != address(0));
        if(!challengeUsed) {
            require(block.timestamp > controller.voteEndTime() + 30 days);
        } else {
            require(block.timestamp > controller.voteEndTime());
        }
        require(voteFor + voteAgainst > 500_000_000e18 + totalPositionalMovement);
        require(
            voteAgainst < (
                (20 * token.totalSupply() / 100) >= 300_000_000e18 ? 
                    (20 * token.totalSupply() / 100) : 300_000_000e18
            )
        );
        require(voteFor > voteAgainst);
        delete voteFor;
        delete voteAgainst;
        uint256 quorumFactor;
        uint256 volume = controller.totalVolumeTraversed();
        uint256 monthlyRev = IAllocator(controller.allocator()).getEpochFeesAccumulated();
        if(volume > 50_000_000e18) {
            quorumFactor = 1200;
        } else if(volume > 20_000_000e18) {
            quorumFactor = 500;
        } else if(volume > 5_000_000e18) {
            quorumFactor = 250;
        } else if(volume > 1_000_000e18) {
            quorumFactor = 150;
        } else {
            quorumFactor = 100;
        }
        if(monthlyRev > 50_000e18) {
            quorumFactor *= 1200;
        } else if(monthlyRev > 20_000e18) {
            quorumFactor *= 500;
        } else if(monthlyRev > 5_000e18) {
            quorumFactor *= 250;
        } else if(monthlyRev > 1_000e18) {
            quorumFactor *= 150;
        } else {
            quorumFactor *= 100;
        }
        totalPositionalMovement += positionalMovement * quorumFactor / 10_000;
        controller.approveFactoryAddition();
        delete challengeUsed;
    }

    /// @notice Reject the factory addition proposal
    function factoryAdditionRejection() external {
        require(controller.changeLive());
        require(controller.pendingFactory() != address(0));
        require(block.timestamp > controller.voteEndTime());
        require(
            voteAgainst >= voteFor
            || voteAgainst >= (
                (20 * token.totalSupply() / 100) >= 300_000_000e18 ? 
                    (20 * token.totalSupply() / 100) : 300_000_000e18
            )
            || voteFor + voteAgainst <= 500_000_000e18 + totalPositionalMovement
        );
        delete voteFor;
        delete voteAgainst;
        delete challengeUsed;
        controller.rejectFactoryAddition();
    }
}