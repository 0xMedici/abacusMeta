//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { ABCToken } from "./AbcToken.sol";
import { VaultMulti } from "./VaultMulti.sol";
import { IVaultMulti } from "./interfaces/IVaultMulti.sol";
import { VaultFactoryMulti } from "./VaultFactoryMulti.sol";
import { IVaultFactoryMulti } from "./interfaces/IVaultFactoryMulti.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { IAllocator } from "./interfaces/IAllocator.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

/// @title Bribe Factory
/// @author Gio Medici
/// @notice Facilitate bribes paid to owners
contract BribeFactory is ReentrancyGuard {

    /* ======== CONFIG ADDRESSES ======== */

    AbacusController public immutable controller;

    /* ======== ARRAYS ======== */

    uint256[] tempStorage;

    /* ======== MAPPINGS ======== */
    /// @notice bribes earned by a user
    /// [address] -> user
    /// [uint256] -> bribe amount
    mapping(address => uint256) public bribesEarned;

    /// @notice bribes offered to a pool
    /// [address] -> pool
    /// [uint256] -> bribe amount
    mapping(address => uint256) public offeredBribeSize;

    /// @notice bribes offered to a pool by a user
    /// [address] -> user
    /// [address] -> pool
    /// [uint256] -> bribe amount
    mapping(address => mapping(address => uint256)) public bribePerAccount;

    /// @notice bribes claimed per NFT
    /// [address] -> pool
    /// [address] -> NFT collection address
    /// [uint256] -> NFT ID
    /// [bool] -> claimed status
    mapping(address => mapping(address => mapping(uint256 => bool))) public bribeClaimed;

    /* ======== EVENTS ======== */

    event BribeIncreased(address briber, address _pool, uint256 increaseAmount);
    event BribeDecreased(address briber, address _pool, uint256 decreaseAmount);
    event BribeAccepted(address owner, address _pool, address token, uint256 id, uint256 bribeSize);
    event VauleEmissionSigned(address owner, address token, uint256 id, address vault);

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller) {
        controller = AbacusController(_controller);
    }

    /* ======== BRIBES ======== */
    /// @notice Add bribes offered to a pool
    /// @param _pool Pool of interest 
    function addToBribe(address _pool) external payable nonReentrant {
        offeredBribeSize[_pool] += msg.value;
        bribePerAccount[msg.sender][_pool] += msg.value;
        emit BribeIncreased(msg.sender, _pool, msg.value);
    }

    /// @notice Withdraw bribes offered to a pool
    /// @dev The pools emissions must be off in order to withdraw offered bribes
    /// @param _pool Pool of interest
    /// @param amount Amount of the bribe to remove
    function withdrawBribe(address _pool, uint256 amount) external nonReentrant {
        require(offeredBribeSize[_pool] >= amount);
        require(bribePerAccount[msg.sender][_pool] >= amount);
        require(!VaultMulti(payable(_pool)).emissionsStarted());
        IAllocator(controller.allocator())
            .donateToEpoch{ value: 1 * amount / 100 }(
                IEpochVault(controller.epochVault()).getCurrentEpoch()
            );
        uint256 returnAmount = 99 * amount / 100;
        offeredBribeSize[_pool] -= amount;
        bribePerAccount[msg.sender][_pool] -= amount;
        payable(msg.sender).transfer(returnAmount);
        emit BribeDecreased(msg.sender, _pool, amount);
    }

    /// @notice Collect offered bribe
    /// @dev Once a bribe is collected, the NFT and ID are tagged as claimed and can no longer
    /// claim from this bribe offering
    /// This adds bribe amount to a mapping to allow users to execute multiple claims and withdraw
    /// eared funds all at once instead of paying transfer fee on every collection
    /// @param _pool Pool of interest
    /// @param _nft NFT collection of interest
    /// @param _id Token ID of interest
    function collectBribe(address _pool, address _nft, uint256 _id) external nonReentrant {
        require(VaultMulti(payable(_pool)).emissionsStarted());
        require(msg.sender == IERC721(_nft).ownerOf(_id));
        require(controller.nftVaultSignedAddress(_nft, _id) == _pool);
        bribeClaimed[_pool][_nft][_id] = true;
        uint256 bribePayout;
        (, tempStorage) = IVaultMulti(payable(_pool)).getHeldTokens();
        if(tempStorage.length > 1 ) {
            bribePayout = offeredBribeSize[_pool] / (tempStorage.length / 2);
        } else {
            bribePayout = offeredBribeSize[_pool];
        }
        delete tempStorage;
        offeredBribeSize[_pool] -= bribePayout;
        bribesEarned[msg.sender] += bribePayout;
        emit BribeAccepted(msg.sender, _pool, _nft, _id, bribePayout);
    }

    /* ======== ACTIONS ON PROFIT EARNED ======== */

    /// @notice Withdraw bribes earned in ETH
    /// @dev Bribe factory sends 1% of bribes facilitated through the contract to ABC allocators
    function withdrawBribesEarned() external nonReentrant {
        IAllocator(controller.allocator())
            .donateToEpoch{ value: 1 * bribesEarned[msg.sender] / 100 }(
                IEpochVault(controller.epochVault()).getCurrentEpoch()
            );
        uint256 returnAmount = 99 * bribesEarned[msg.sender] / 100;
        delete bribesEarned[msg.sender];
        payable(msg.sender).transfer(returnAmount);
    }
}