//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { ABCToken } from "./AbcToken.sol";
import { IAllocator } from "./interfaces/IAllocator.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";

import { IERC20 } from "./interfaces/IERC20.sol";
import "hardhat/console.sol";

contract Governor {

    AbacusController public controller;
    ABCToken public token;

    uint256 public voteFor;
    uint256 public voteAgainst;
    uint256 public voteEndTime;

    uint256 public pendingPositionalMovement;
    uint256 public totalPositionalMovement;
    uint256 public positionalMovement;
    uint256 public positionalChanges;

    bool public challengeUsed;

    mapping(address => uint256) public credit;
    mapping(address => uint256) public timeCreditsUnlock;
    mapping(address => uint256) public votingCredit;
    mapping(address => uint256) public timeVotingCreditsUnlock;

    constructor(address _controller, address _token) {
        controller = AbacusController(_controller);
        token = ABCToken(_token);
        positionalMovement = 2_000_000e18;
    }

    function lockCredit(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount));
        credit[msg.sender] += amount;
    }

    function claimVoteLocked() external {
        require(block.timestamp > timeVotingCreditsUnlock[msg.sender]);
        uint256 payout = votingCredit[msg.sender];
        delete votingCredit[msg.sender];
        delete timeVotingCreditsUnlock[msg.sender];
        token.transfer(msg.sender, payout);
    }

    function claimCredit() external {
        require(block.timestamp > timeCreditsUnlock[msg.sender]);
        uint256 payout = credit[msg.sender];
        delete credit[msg.sender];
        delete timeCreditsUnlock[msg.sender];
        token.transfer(msg.sender, payout);
    }

    function proposePositionalMovement(uint256 _proposedSize) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(block.timestamp > voteEndTime + 7 days);
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

    function movementAcceptance() external {
        require(pendingPositionalMovement != 0);
        require(block.timestamp > voteEndTime);
        require(voteFor + voteAgainst > 250_000_000e18 + 25_000_000e18 * positionalChanges);
        delete voteFor;
        delete voteAgainst;
        positionalMovement = pendingPositionalMovement;
        delete pendingPositionalMovement;
    }

    function movementRejection() external {
        require(pendingPositionalMovement != 0);
        require(block.timestamp > voteEndTime);
        require(
            voteAgainst > voteFor
            || voteFor + voteAgainst < 250_000_000e18 + 25_000_000e18 * positionalChanges
        );
        delete voteFor;
        delete voteAgainst;
        delete pendingPositionalMovement;
    }

    function proposeNewCollection(address[] memory collections) external {
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
        uint256 currentEpoch;
        if(IEpochVault(controller.epochVault()).getStartTime() == 0) currentEpoch == 0;
        else currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        require(IEpochVault(controller.epochVault()).getEpochEndTime(currentEpoch) > block.timestamp + 14 days);
        timeCreditsUnlock[msg.sender] = block.timestamp + 10 days;
        controller.proposeWLAddresses(collections);
    } 

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

    function newCollectionRejection() external {
        require(controller.changeLive());
        require(controller.pendingWLAdditions(0) != address(0));
        require(block.timestamp > controller.voteEndTime());
        require(voteAgainst > voteFor);
        delete voteFor;
        delete voteAgainst;
        controller.rejectWLAddresses();
    }

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
        uint256 currentEpoch;
        if(IEpochVault(controller.epochVault()).getStartTime() == 0) currentEpoch == 0;
        else currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch();
        require(IEpochVault(controller.epochVault()).getEpochEndTime(currentEpoch) > block.timestamp + 14 days);
        timeCreditsUnlock[msg.sender] = block.timestamp + 10 days;
        controller.proposeWLRemoval(collections);
    }

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

    function removeCollectionRejection() external {
        require(controller.changeLive());
        require(controller.pendingWLRemoval(0) != address(0));
        require(block.timestamp > controller.voteEndTime());
        require(
            voteFor + voteAgainst < (100_000_000e18 > (2 * token.totalSupply() / 100) ? 100_000_000e18 : (2 * token.totalSupply() / 100))
            || voteAgainst > voteFor
        );
        delete voteFor;
        delete voteAgainst;
        controller.rejectWLRemoval();
    }

    function proposeFactoryAddition(address factory) external {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0);
        require(block.timestamp > controller.voteEndTime() + 7 days);
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

    function challengeAdditionVote() external {
        require(!challengeUsed);
        require(controller.changeLive());
        require(controller.pendingFactory() != address(0));
        require(
            block.timestamp > controller.voteEndTime()
            && block.timestamp < controller.voteEndTime() + 7 days
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

    function factoryAdditionAcceptance() external {
        require(controller.changeLive());
        require(controller.pendingFactory() != address(0));
        if(!challengeUsed) {
            require(block.timestamp > controller.voteEndTime() + 7 days);
        } else {
            require(block.timestamp > controller.voteEndTime());
        }
        require(voteFor + voteAgainst > 500_000_000e18 + totalPositionalMovement);
        require(voteAgainst < 20 * token.totalSupply() / 100);
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

    function factoryAdditionRejection() external {
        require(controller.changeLive());
        require(controller.pendingFactory() != address(0));
        require(block.timestamp > controller.voteEndTime());
        require(
            voteAgainst > voteFor
            || voteAgainst > 20 * token.totalSupply() / 100
            || voteFor + voteAgainst < 500_000_000e18 + totalPositionalMovement
        );
        delete voteFor;
        delete voteAgainst;
        delete challengeUsed;
        controller.rejectFactoryAddition();
    }
}