//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ABCToken } from "./AbcToken.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { VaultMulti } from "./VaultMulti.sol";
import { IVaultMulti } from "./interfaces/IVaultMulti.sol";
import { ClosePoolMulti } from "./ClosePoolMulti.sol";
import { IClosePoolMulti } from "./interfaces/IClosePoolMulti.sol";
import { Treasury } from "./Treasury.sol";
import { AbacusController } from "./AbacusController.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ClonesUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "hardhat/console.sol";
import "./helpers/ReentrancyGuard.sol";

contract VaultFactoryMulti is ReentrancyGuard {

    ///TODO: add event propagation

    /* ======== ADDRESS ======== */

    address private immutable _vaultMultiImplementation;
    address private immutable _closePoolImplementation;
    address public pendingController;
    AbacusController public controller;

    /* ======== BOOLEAN ======== */

    uint256 public vaultVersion;

    uint256 public multiAssetVaultNonce;

    /* ======== MAPPING ======== */

    mapping(address => uint256) public pendingReturns;

    /// @notice track vaults by index
    mapping(address => mapping(uint256 => uint256)) public nextVaultIndex;

    mapping(address => mapping(uint256 => address[])) public listOfPoolsPerNftTEMP;

    mapping(address => mapping(uint256 => address[])) public listOfPoolsPerNft;

    mapping(address => mapping(uint256 => mapping(address => bool))) public presentInPool;

    /// @notice mapping used to track current vault address of an NFT
    mapping(uint256 => mapping(address => mapping(uint => address))) public nftVault;

    mapping(address => mapping(uint256 => uint256)) public nftInUse;

    mapping(uint256 => MultiAssetVault) public multiAssetMapping;

    mapping(address => uint256) closureVotes;

    /* ======== MAPPING ======== */

    struct MultiAssetVault {
        bool created;
        address proposer;
        address pool;
        uint32 originalAmountOfNfts;
        uint32 initiationEndTime;
        uint32 slots;
        uint32 amountLeftToSign;
        uint256[] ids;
        uint256[] newIds;
        address collection;
        mapping(uint256 => bool) idExistence;
        mapping(address => mapping(uint256 => bool)) vaultSignature;
    }

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
        _closePoolImplementation = address(new ClosePoolMulti());
        _vaultMultiImplementation = address(new VaultMulti());
        controller = AbacusController(_controller);
        vaultVersion = 2;
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

    /* ======== POOL CREATION ======== */
    
    function initiateMultiAssetVault(
        address _nft, 
        uint256[] memory _id, 
        uint256 amountSlots
    ) payable external {
        uint256 beta = controller.beta();
        if(beta == 1) {
            require(controller.userWhitelist(msg.sender));
        }

        MultiAssetVault storage mav = multiAssetMapping[multiAssetVaultNonce];
        uint256 length = _id.length;
        mav.slots = uint32(amountSlots);
        mav.originalAmountOfNfts = uint32(length);
        mav.amountLeftToSign = uint32(length);
        for(uint256 i = 0; i < length; i++) {
            mav.idExistence[_id[i]] = true;
            mav.ids.push(_id[i]);
            mav.collection = _nft;
        }

        IVaultMulti vaultMultiDeployment = IVaultMulti(ClonesUpgradeable.clone(_vaultMultiImplementation));

        vaultMultiDeployment.initialize(
            IERC721(mav.collection),
            _id,
            vaultVersion,
            amountSlots,
            multiAssetVaultNonce,
            msg.sender,
            address(controller),
            _closePoolImplementation
        );

        controller.addAccreditedAddressesMulti(address(vaultMultiDeployment));
        mav.pool = address(vaultMultiDeployment);
        length = _id.length;
        for(uint256 i = 0; i < length; i++) {
            listOfPoolsPerNft[mav.collection][_id[i]].push(address(vaultMultiDeployment));
            presentInPool[mav.collection][_id[i]][address(vaultMultiDeployment)] = true;
        }

        multiAssetVaultNonce++;
    }

    function signMultiAssetVault(uint256 multiVaultNonce, address nft, uint256[] memory id) external {
        MultiAssetVault storage mav = multiAssetMapping[multiVaultNonce];
        uint256 length = id.length;
        for(uint256 i = 0; i < length; i++) {
            require(msg.sender == IERC721(nft).ownerOf(id[i]));
            require(controller.collectionWhitelist(nft));
            require(nftInUse[nft][id[i]] == 0);
            nftInUse[nft][id[i]]++;
            mav.amountLeftToSign--;
        }

        if(mav.amountLeftToSign <= mav.ids.length / 2) IVaultMulti(mav.pool).startEmission();
    }

    function updateNftInUse(
        address nftToRemove,
        uint256 idToRemove,
        uint256 multiVaultNonce
    ) external returns(uint256[] memory newIds){
        MultiAssetVault storage mav = multiAssetMapping[multiVaultNonce];
        require(controller.accreditedAddresses(msg.sender));
        delete presentInPool[nftToRemove][idToRemove][msg.sender];
        delete mav.idExistence[idToRemove];
        nftInUse[nftToRemove][idToRemove]--;

        for(uint256 i = 0; i < mav.ids.length; i++) {
            if(mav.idExistence[mav.ids[i]]) mav.newIds.push(mav.ids[i]);
        }
        
        uint256 lengthPresentInPool = listOfPoolsPerNft[nftToRemove][idToRemove].length;
        for(uint256 k = 0; k < lengthPresentInPool; k++) {
            if(presentInPool[nftToRemove][idToRemove][listOfPoolsPerNft[nftToRemove][idToRemove][k]]) {
                listOfPoolsPerNftTEMP[nftToRemove][idToRemove].push(
                    listOfPoolsPerNft[nftToRemove][idToRemove][k]
                );
            }
        }
        listOfPoolsPerNft[nftToRemove][idToRemove] = listOfPoolsPerNftTEMP[nftToRemove][idToRemove];
        delete listOfPoolsPerNftTEMP[nftToRemove][idToRemove];

        newIds = mav.newIds;
        delete mav.newIds;
    }

    function closePool(address _pool, address nft, uint256[] memory ids) external {
        MultiAssetVault storage mav = multiAssetMapping[IVaultMulti(_pool).getNonce()];
        uint256 length = ids.length;
        for(uint256 i = 0; i < length; i++) {
            require(IERC721(nft).ownerOf(ids[i]) == msg.sender);
            closureVotes[_pool]++;
        }

        if(closureVotes[_pool] >= mav.ids.length / 2) {
            IVaultMulti(_pool).closePool();
        }
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

    /* ======== GETTER ======== */

    function getIdPresence(address nft, uint256 id) view external returns(bool) {
        return presentInPool[nft][id][msg.sender];
    } 

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}