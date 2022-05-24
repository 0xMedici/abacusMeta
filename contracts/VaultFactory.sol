//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Vault } from "./Vault.sol";
import { IVault } from "./interfaces/IVault.sol";
import { ClosePool } from "./ClosePool.sol";
import { IClosePool } from "./interfaces/IClosePool.sol";
import { Treasury } from "./Treasury.sol";
import { AbacusController } from "./AbacusController.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ClonesUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "hardhat/console.sol";
import "./helpers/ReentrancyGuard.sol";

/// @title ABC Token
/// @author Gio Medici
/// @notice Spot pool factory
contract VaultFactory is ReentrancyGuard {

    /* ======== ADDRESS ======== */

    address private immutable _vaultImplementation;
    address private immutable _closePoolImplementation;
    address public pendingController;
    AbacusController public controller;

    /* ======== BOOLEAN ======== */

    uint256 public vaultVersion;

    /* ======== MAPPING ======== */

    /// @notice whitelist of valid creation collections 
    mapping(address => bool) public collectionWhitelist;

    /// @notice beta whitelist
    mapping(address => bool) public earlyMemberWhitelist;

    mapping(address => uint256) public pendingReturns;

    /// @notice track vaults by index
    mapping(address => mapping(uint256 => uint256)) public nextVaultIndex;

    /// @notice mapping used to track current vault address of an NFT
    mapping(uint256 => mapping(address => mapping(uint => address))) public nftVault;

    /* ======== EVENT ======== */

    event VaultCreated(address _creator, address _token, uint256 _tokenId, uint256 _nonce);
    event CollectionWhitelisted(address _collection);
    event EmissionsSigned(address _callingContract, address _callerToken, uint256 _callerId, address _signer);
    event TokensPurchased(address _callingContract, address _callerToken, uint256 _callerId, address _buyer, uint256 tickets, uint256 amounts, uint256 _lockTime);
    event TokensSold(address _callingContract, address _callerToken, uint256 _callerId, address _seller, uint256 ticket);
    event PendingOrderSubmitted(address _callingContract, address _callerToken, uint256 _callerId, address buyer, uint256 ticket, uint256 executorReward);
    event SaleComplete(address _callingContract, address _callerToken, uint256 _calledId, address _seller, uint256 creditsPurchased);
    event FeesRedeemed(address _callingContract, address _callerToken, uint256 _callerId, uint256 toVeHolders);
    event PoolClosed(address _callingContract, address _callerToken, uint256 _callerId, uint256 _finalVal, address _closePoolContract, address _vault);
    event NewBid(address _callingContract, address _callerToken, uint256 _callerId, uint256 _bidAmount, address _bidder, address _closePoolContract, address _vault);
    event AuctionedEnded(address _callingContract, address _callerToken, uint256 _callerId, uint256 _finalVal, uint256 _auctionVal, address _closePoolContract, address _vault);
    event AccountClosed(address _callingContract, address _callerToken, uint256 _callerId, uint256 _finalVal, uint256 _auctionVal, uint256 _payoutCredits, uint256 _payoutEth, address _closePoolContract, address _vault);
    event OwnerFeesDistributed(address _callingContract, address _callerToken, uint256 _callerId, address _ownerAddress, uint256 _ownerFees);

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller) {
        _vaultImplementation = address(new Vault());
        _closePoolImplementation = address(new ClosePool());
        controller = AbacusController(_controller);
        vaultVersion = 1;
    }

    /* ======== WHITELISTS ======== */

    /// @notice allow early members create a vault
    function addToEarlyMemberWhitelist(address _earlyAccess) external {
        require(msg.sender == controller.admin());
        earlyMemberWhitelist[_earlyAccess] = true;
    }

    /// @notice allow vaults to be made for a new collection 
    function addToCollectionWhitelist(address _collection) external {
        require(msg.sender == controller.admin());
        collectionWhitelist[_collection] = true;
        emit CollectionWhitelisted(_collection);
    }

    /* ======== ADDRESS CONFIGURATION ======== */

    /// @notice propose controller change
    function setController(address _controller) external {
        require(msg.sender == controller.admin());
        pendingController = _controller;
    }
    
    /// @notice confirm controller change
    function approveControllerChange() external {
        require(msg.sender == controller.multisig());
        controller = AbacusController(pendingController);
    }

    /* ======== VAULT CREATION ======== */
    
    /// @notice Vault creation
    /**
    @dev produces a Abacus Spot vault.
    It then proceeds to populate the vault with
    necessary information and then allows them to function
    properly.
    */
    /**
    @param _heldToken address of NFT in vault created
    @param _heldTokenId id of NFT in vault created
    */
    function createVault(
        IERC721 _heldToken,
        uint256 _heldTokenId
    ) external {
        require(_heldToken.ownerOf(_heldTokenId) != address(0));
        uint256 beta = controller.beta();
        if(beta == 1) {
            require(earlyMemberWhitelist[msg.sender]);
        }
        else if(beta == 2) {
            require(collectionWhitelist[address(_heldToken)]);
        }

        if(nextVaultIndex[address(_heldToken)][_heldTokenId] != 0) {
            address vaultAddress = nftVault[nextVaultIndex[address(_heldToken)][_heldTokenId] - 1][address(_heldToken)][_heldTokenId];
            require(IVault(payable(vaultAddress)).getClosePoolContract() != address(0));
        }

        IVault vaultDeployment = IVault(ClonesUpgradeable.clone(_vaultImplementation));
        

        // deploy vault token
        vaultDeployment.initialize(
            _heldToken,
            _heldTokenId,
            vaultVersion,
            address(controller),
            _closePoolImplementation
        );
        

        // configure newly created vault and owner token
        nftVault[nextVaultIndex[address(_heldToken)][_heldTokenId]][address(_heldToken)][_heldTokenId] = address(vaultDeployment);
        nextVaultIndex[address(_heldToken)][_heldTokenId]++;
        controller.addAccreditedAddresses(address(vaultDeployment), address(_heldToken), _heldTokenId, vaultVersion);

        emit VaultCreated(
            msg.sender, 
            address(_heldToken), 
            _heldTokenId,
            nextVaultIndex[address(_heldToken)][_heldTokenId] - 1
        );
    }

    /* ======== CLAIMING RETURNED FUNDS/EARNED FEES ======== */

    /// @notice receive updates for user return balances
    function updatePendingReturns(address _user) payable external {
        require(controller.accreditedAddresses(msg.sender));
        pendingReturns[_user] += msg.value;
    }

    /// @notice pay out pending return funds
    function claimPendingReturns() nonReentrant external {
        uint256 payout = pendingReturns[msg.sender];
        delete pendingReturns[msg.sender];
        payable(msg.sender).transfer(payout);
    }

    /* ======== EVENT PROPAGATION ======== */

    /// @notice emit propagated event to show an owner activated a pool
    function emitEmissionSigning(
        address _callerToken,
        uint256 _callerId,
        address _signer
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit EmissionsSigned(msg.sender, _callerToken, _callerId, _signer);
    }

    /// @notice emit propagated event to show tokens were purchased in a pool
    function emitTokenPurchase(
        address _callerToken,
        uint256 _callerId,
        address _buyer,
        uint256 ticket,
        uint256 amount,
        uint256 _lockTime
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit TokensPurchased(msg.sender, _callerToken, _callerId, _buyer, ticket, amount, _lockTime);
    }

    /// @notice emit propagated event to show tokens were sold in a pool
    function emitTokenSale(
        address _callerToken,
        uint256 _callerId,
        address _seller, 
        uint256 ticket
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit TokensSold(msg.sender, _callerToken, _callerId, _seller, ticket);
    }

    /// @notice emit propagated event to show token sale was complete
    function emitSaleComplete(
        address _callerToken,
        uint256 _callerId,
        address _seller,
        uint256 creditsPurchased
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit SaleComplete(msg.sender, _callerToken, _callerId, _seller, creditsPurchased);
    } 
    
    /// @notice emit propagated event to show a new pending order bid was submitted
    function emitPendingOrderSubmitted(
        address _callerToken, 
        uint256 _callerId,
        address _buyer,
        uint256 ticket,
        uint256 executorReward
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit PendingOrderSubmitted(msg.sender, _callerToken, _callerId, _buyer, ticket, executorReward);
    }

    /// @notice emit propagated event to show fees were redeemed
    function emitFeeRedemption(
        address _callerToken,
        uint256 _callerId,
        uint256 toVeHolders
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit FeesRedeemed(msg.sender, _callerToken, _callerId, toVeHolders);
    }

    /// @notice emit propagated event to show a pool was closed
    function emitPoolClosure(
        address _callerToken,
        uint256 _callerId,
        uint256 _finalVal, 
        address _closePoolContract, 
        address _vault 
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit PoolClosed(msg.sender, _callerToken, _callerId, _finalVal, _closePoolContract, _vault);
    }

    /// @notice emit propagated event to show a new bid was submitted
    function emitNewBid(
        address _callerToken,
        uint256 _callerId,
        uint256 _bid,
        address _bidder,
        address _closePoolContract,
        address _vault
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit NewBid(msg.sender, _callerToken, _callerId, _bid, _bidder, _closePoolContract, _vault);
    }

    /// @notice emit propagated event to show an auction ended
    function emitAuctionEnded(
        address _callerToken,
        uint256 _callerId,
        uint256 _finalVal,
        uint256 _auctionVal,
        address _closePoolContract,
        address _vault
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit AuctionedEnded(msg.sender, _callerToken, _callerId, _finalVal, _auctionVal, _closePoolContract, _vault);
    }

    /// @notice emit propagated event to show an account closed
    function emitAccountClosed(
        address _callerToken,
        uint256 _callerId,
        uint256 _finalVal,
        uint256 _auctionVal,
        uint256 _payoutCredits,
        uint256 _payoutEth,
        address _closePoolContract,
        address _vault
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit AccountClosed(msg.sender, _callerToken, _callerId, _finalVal, _auctionVal, _payoutCredits, _payoutEth, _closePoolContract, _vault);
    }

    function emitOwnerFeesClaimed(
        address _callerToken,
        uint256 _callerId,
        address _ownerAddress,
        uint256 _feesPaid
    ) external {
        require(controller.accreditedAddresses(msg.sender));
        emit OwnerFeesDistributed(msg.sender, _callerToken, _callerId, _ownerAddress, _feesPaid);
    }

    /* ======== GETTER ======== */

    /// @notice returns vault address 
    function getVaultAddress(address nft, uint256 id) view external returns(address vaultAddress){
        if(nextVaultIndex[nft][id] == 0) return address(0);
        vaultAddress = nftVault[nextVaultIndex[nft][id] - 1][nft][id];
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}