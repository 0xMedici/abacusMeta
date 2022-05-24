//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { ABCToken } from "./AbcToken.sol";
import { Vault } from "./Vault.sol";
import { IVault } from "./interfaces/IVault.sol";
import { VaultFactory } from "./VaultFactory.sol";
import { IVaultFactory } from "./interfaces/IVaultFactory.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { IVeAbc } from "./interfaces/IVeAbc.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./helpers/ReentrancyGuard.sol";

/// @title Bribe Factory
/// @author Gio Medici
/// @notice Facilitate bribes paid to owners
contract BribeFactory is ReentrancyGuard {

    /* ======== CONFIG ADDRESSES ======== */

    /// @notice Abacus contract directory
    AbacusController public controller;

    /* ======== MAPPING ======== */

    /// @notice track bribes earned per user
    mapping(address => uint256) public bribesEarned;

    /// @notice current bribe offered to the owner
    mapping(address => mapping(uint256 => uint256)) public offeredBribeSize;

    /// @notice index each bribe tranche
    mapping(address => mapping(uint256 => uint256)) public bribePerUserIndex;

    /// @notice track how much each user has contributed to the bribe 
    mapping(uint256 => mapping(address => mapping(uint256 => mapping(address => uint256)))) public bribePerAccount;

    /* ======== EVENTS ======== */

    event BribeIncreased(address briber, address token, uint256 id, uint256 increaseAmount);
    event BribeDecreased(address briber, address token, uint256 id, uint256 decreaseAmount);
    event BribeAccepted(address owner, address token, uint256 id, uint256 bribeSize);
    event VauleEmissionSigned(address owner, address token, uint256 id, address vault);

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller) {
        controller = AbacusController(_controller);
    }

    /* ======== SETTER ======== */

    /// @notice configure directory contract
    function setController(address _controller) external {
        require(msg.sender == controller.admin());
        controller = AbacusController(_controller);
    }

    /* ======== BRIBES ======== */

    /// @notice Add to total offered bribe amount for targeted NFT
    /// @param token address of targeted NFT
    /// @param id id of targeted NFT
    function addToBribe(address token, uint256 id) nonReentrant payable external {
        offeredBribeSize[token][id] += msg.value;
        bribePerAccount[bribePerUserIndex[token][id]][token][id][msg.sender] += msg.value;
        emit BribeIncreased(msg.sender, token, id, msg.value);
    }

    /// @notice Briber witdraws a portion of their bribe
    /// @param token address of targeted NFT
    /// @param id id of targeted NFT
    /// @param amount desired withdraw size
    function withdrawBribe(address token, uint256 id, uint256 amount) nonReentrant external {
        takeFee(amount);
        uint256 returnAmount = 99 * amount / 100;
        uint256 currentBribeSize = bribePerAccount[bribePerUserIndex[token][id]][token][id][msg.sender];
        require(currentBribeSize >= amount);
        offeredBribeSize[token][id] -= amount;
        bribePerAccount[bribePerUserIndex[token][id]][token][id][msg.sender] -= amount;
        payable(msg.sender).transfer(returnAmount);
        emit BribeDecreased(msg.sender, token, id, amount);
    }

    /// @notice NFT owner accepts bribe manually 
    /// @dev Triggers internal signature function which unlocks target NFT pool emissions
    /// @param token address of targeted NFT
    /// @param id id of targeted NFT
    function acceptBribe(address token, uint256 id) nonReentrant external {
        require(msg.sender == IERC721(token).ownerOf(id));
        uint256 bribe = offeredBribeSize[token][id];
        offeredBribeSize[token][id] = 0;
        bribesEarned[msg.sender] += bribe;
        signVaultEmission(msg.sender, token, id);
        emit BribeAccepted(msg.sender, token, id, bribe);
    }

    /* ======== ACTIONS ON PROFIT EARNED ======== */

    /// @notice Withdraw bribes earned in ETH
    /// @param amount desired withdrawal size
    function withdrawBribesEarned(uint256 amount) nonReentrant external {
        takeFee(amount);
        uint256 returnAmount = 99 * amount / 100;
        require(amount <= bribesEarned[msg.sender]);
        bribesEarned[msg.sender] -= amount;
        payable(msg.sender).transfer(returnAmount);
    }

    /* ======== INTERNAL ======== */

    /// @notice Triggers vault signature 
    /** 
    @dev finds vault -> signs off on emissions -> returns NFT to owner -> increases the index
    */
    /// @param token address of targeted NFT
    /// @param id id of targeted NFT
    function signVaultEmission(address _owner, address token, uint256 id) internal {
        require(IERC721(token).ownerOf(id) == _owner);
        VaultFactory factory = VaultFactory(payable(controller.factoryVersions(controller.nftVaultVersion(token, id))));
        uint256 nextIndex = factory.nextVaultIndex(token, id);
        address nftVault = factory.nftVault(nextIndex - 1, token, id);
        IERC721(token).transferFrom(_owner, address(this), id);
        IVault(payable(nftVault)).startEmission();
        require(Vault(payable(nftVault)).emissionsStarted());
        IERC721(token).transferFrom(address(this), _owner, id); 
        bribePerUserIndex[token][id]++;
        emit VauleEmissionSigned(_owner, token, id, nftVault);
    }

    /// @notice 1% fee enforced for core actions taken
    function takeFee(uint256 _amount) internal {
        uint256 gasPayment = 1 * _amount / 100;
        IVeAbc(controller.veAbcToken()).donateToEpoch{ value: gasPayment }(IEpochVault(controller.epochVault()).getCurrentEpoch());
    } 
}