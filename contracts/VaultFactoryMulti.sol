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

/// @title Multi Asset Vault Factory
/// @author Gio Medici
/// @notice The factory is responsible for producing and managing spot pools
contract VaultFactoryMulti is ReentrancyGuard {

    /* ======== ADDRESS ======== */

    AbacusController public immutable controller;
    
    address private immutable _vaultMultiImplementation;
    address private immutable _closePoolImplementation;

    /* ======== BOOLEAN ======== */
    /// @notice Factory version of this vault factory
    uint256 public immutable vaultVersion;

    /// @notice Used to tag each vault with a unique value for tracking purposes
    uint256 public multiAssetVaultNonce;

    /* ======== MAPPING ======== */
    /// @notice ETH to be returned from all vaults is routed this mapping
    /// [address] -> User
    /// [uint256] -> Return amount 
    mapping(address => uint256) public pendingReturns;

    /// @notice Check the presence of an NFT in a pool
    /// [address] NFT Collection address
    /// [uint256] NFT ID
    /// [address] pool address
    /// [bool] -> presence status
    mapping(address => mapping(uint256 => mapping(address => bool))) public presentInPool;

    /// @notice Track each pool using a unique multi asset mapping nonce
    /// [uint256] -> nonce
    mapping(uint256 => MultiAssetVault) public multiAssetMapping;

    /// @notice Track votes for shutting down a pool
    /// [address] -> pool
    /// [uint256] -> votes for closing
    mapping(address => uint256) closureVotes;

    /// TODO: REMOVE FOR PROD
    mapping(address => mapping(uint256 => address)) public recentlyCreatedPool;

    /* ======== MAPPING ======== */
    /// @notice Store information regarding a multi asset pool
    /// [pool] -> pool address
    /// [slots] -> amount of NFTs that can be borrowed against at once
    /// [amountSigned] -> amount of NFTs signed to turn on emissions
    /// [collectionExistence] -> track existence in list of collections
        /// [address] -> collection
        /// [uint256] -> amount of times it comes up in vault
    struct MultiAssetVault {
        address pool;
        uint32 slots;
        uint32 nftRemoved;
        uint32 amountSigned;
        mapping(address => uint256) collectionExistence;
    }

    /* ======== EVENT ======== */

    event VaultCreated(address _creator, address indexed _pool, address[] _collections, uint256[] heldIds, uint256 amountOfSlots);
    event VaultSigned(address _pool, address _signer, address[] _collections, uint256[] _ids);
    event EmissionsStarted(address _pool, address[] _collections, uint256[] heldIds);
    event EmissionsStopped(address _pool, address[] _collections, uint256[] heldIds);
    event SignPoolClosure(address _pool, address _signer,address _collections, uint256 _idSigned);
    event NftRemoved(address _pool, address[] _collections, uint256[] heldIds, uint256 removedId);
    event PoolClosed(address _pool, address[] _collections, uint256[] heldIds); 
    event PendingReturnsUpdated(address _user, uint256 _amount);
    event PendingReturnsClaimed(address _user, uint256 _amount);
    event PayoutRatioAdjusted(address _pool, address[] _collections, uint256[] heldIds, address _user, uint256 _ratio);
    event Purchase(address _pool, address[] _collections, uint256[] heldIds, address _buyer, uint256[] tickets, uint256[] amountPerTicket, uint256 startEpoch, uint256 finalEpoch);
    event SaleComplete(address _pool, address[] _collections, uint256[] heldIds, address _seller, uint256 creditsPurchased);
    event GeneralBribeOffered(address _pool, address[] _collections, uint256[] heldIds, address _briber, uint256 _bribeAmount, uint256 startEpoch, uint256 endEpoch);
    event ConcentratedBribeOffered(address _pool,  address[] _collections, uint256[] heldIds, address _briber, uint256[] tickets, uint256[] bribePerTicket, uint256 startEpoch, uint256 endEpoch);
    event PoolRestored(address _pool, address[] _collections, uint256[] heldIds, uint256 newPayoutPerReservation);
    event SpotReserved(address _pool, address[] _collections, uint256[] heldIds, uint256 reservationId, uint256 startEpoch, uint256 endEpoch);
    event NftClosed(address _pool, address[] _collections, uint256[] heldIds, uint256 _id, address _caller, uint256 payout, address closePoolContract); 
    event NewBid(address _pool, address _closePoolContract, address _collection, uint256 _id, address _bidder, uint256 _bid);
    event AuctionEnded(address _pool, address _closePoolContract, address _collection, uint256 _id, address _winner, uint256 _highestBid);
    event PrincipalCalculated(address _pool, address _closePoolContract, address _collection, uint256 _id, address _user);
    event Payout(address _pool, address _closePoolContract, address _user, uint256 _payoutAmount);
    event LPInitiated(address _pool, address[] _collections, uint256[] heldIds, address initiater);
    event LPTransferAllowanceGranted(address _pool, address[] _collections, uint256[] heldIds, address from, address to);
    event LPTransferred(address _pool, address[] _collections, uint256[] heldIds, address from, address to, uint256[] tickets, uint256[] amountPerTicket);


    /* ======== MODIFIER ======== */
    
    modifier onlyAccredited {
        require(controller.accreditedAddresses(msg.sender));
        _;
    }

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller) {
        _closePoolImplementation = address(new ClosePoolMulti());
        _vaultMultiImplementation = address(new VaultMulti());
        controller = AbacusController(_controller);
        vaultVersion = 1;
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}

    /* ======== POOL CREATION ======== */
    /// @notice Create a multi asset vault
    /// @dev The creator will have to pay a creation fee (denominated in ABC)
    /// @param _nft List of NFTs with access to the vault
    /// @param _id List of NFT IDs (matched with list of NFTs) with access to vault
    /// @param amountSlots Amount of NFTs that can be collateralized at once
    function initiateMultiAssetVault(
        address[] memory _nft, 
        uint256[] memory _id, 
        uint256 amountSlots
    ) external nonReentrant {
        require(_nft.length >= amountSlots);
        require(_nft.length == _id.length);
        require(_nft.length <= controller.poolSizeLimit());
        if(controller.gasFeeStatus()) {
            IEpochVault(controller.epochVault()).receiveAbc(
                msg.sender,
                controller.creationFee()
            );
        }
        uint256 beta = controller.beta();
        if(beta == 1) {
            require(controller.userWhitelist(msg.sender));
        }

        MultiAssetVault storage mav = multiAssetMapping[multiAssetVaultNonce];
        mav.slots = uint32(amountSlots);

        IVaultMulti vaultMultiDeployment = IVaultMulti(
            ClonesUpgradeable.clone(_vaultMultiImplementation)
        );

        vaultMultiDeployment.initialize(
            _nft,
            _id,
            vaultVersion,
            amountSlots,
            multiAssetVaultNonce,
            address(controller),
            _closePoolImplementation
        );

        controller.addAccreditedAddressesMulti(address(vaultMultiDeployment));
        mav.pool = address(vaultMultiDeployment);
        uint256 length = _id.length;
        for(uint256 i = 0; i < length; i++) {
            if(beta == 2) require(controller.collectionWhitelist(_nft[i]));
            mav.collectionExistence[_nft[i]]++;
            presentInPool[_nft[i]][_id[i]][address(vaultMultiDeployment)] = true;
            /// TODO: REMOVE FOR PROD
            recentlyCreatedPool[_nft[i]][_id[i]] = address(vaultMultiDeployment);
        }
        multiAssetVaultNonce++;
        emit VaultCreated(msg.sender, address(vaultMultiDeployment), _nft, _id, amountSlots);
    }

    /// @notice Sign off on starting a vaults emissions
    /// @dev Each NFT can only have its signature attached to one vault at a time
    /// @param multiVaultNonce Nonce corresponding to desired vault
    /// @param nft List of NFTs (must be in the vault and owned by the caller)
    /// @param id List of NFT IDs (must be in the vault and owned by the caller)
    /// @param boostedCollection The collection that the vaults EDC emission boost will 
    /// be tied too (must be in the vault)
    function signMultiAssetVault(
        uint256 multiVaultNonce,
        address[] memory nft,
        uint256[] memory id,
        address boostedCollection
    ) external nonReentrant {
        MultiAssetVault storage mav = multiAssetMapping[multiVaultNonce];
        uint256 length = id.length;
        address pool = mav.pool;
        if(controller.gasFeeStatus()) {
            IEpochVault(controller.epochVault()).receiveAbc(
                msg.sender, 
                nft.length * controller.removalFee()
            );
        }
        for(uint256 i = 0; i < length; i++) {
            address collection = nft[i];
            uint256 _id = id[i];
            require(presentInPool[collection][_id][pool]);
            require(msg.sender == IERC721(collection).ownerOf(_id));
            require(controller.collectionWhitelist(collection));
            require(!controller.nftVaultSigned(collection, _id));
            controller.updateNftUsage(pool, collection, _id, true);
            mav.amountSigned++;
        }
        emit VaultSigned(pool, msg.sender, nft, id);
        
        if(mav.amountSigned >= mav.slots) {
            require(mav.collectionExistence[boostedCollection] > 0);
            IVaultMulti(mav.pool).toggleEmissions(boostedCollection, true);
            emit EmissionsStarted(pool, nft, id);
        }
    }

    /// @notice Sever ties between an NFT and a pool
    /// @dev Only callable by an accredited address (an existing pool)
    /// @param nftToRemove NFT address to be removed
    /// @param idToRemove NFT ID to be removed
    /// @param multiVaultNonce Nonce corresponding to desired vault 
    function updateNftInUse(
        address nftToRemove,
        uint256 idToRemove,
        uint256 multiVaultNonce
    ) external returns(address[] memory newCollections, uint256[] memory newIds) {
        MultiAssetVault storage mav = multiAssetMapping[multiVaultNonce];
        require(controller.accreditedAddresses(msg.sender));
        controller.updateNftUsage(address(0), nftToRemove, idToRemove, false);
        uint256 mod;
        (newCollections, newIds) = IVaultMulti(mav.pool).getHeldTokens();
        uint256 length = newIds.length - mav.nftRemoved;
        for(uint256 i = 0; i < length; i++) {
            if(newIds[i] == idToRemove && newCollections[i] == nftToRemove) {
                mod = 1;
            } else if(mod == 1) {
                newCollections[i - mod] = newCollections[i];
                newIds[i - mod] = newIds[i];
            }
        }
        mav.nftRemoved++;
        mav.collectionExistence[nftToRemove]--;
        mav.amountSigned--;
        delete presentInPool[nftToRemove][idToRemove][msg.sender];
        delete newCollections[newCollections.length - mav.nftRemoved];
        delete newIds[newIds.length - mav.nftRemoved];
        if(mav.amountSigned < mav.slots) {
            IVaultMulti(mav.pool).toggleEmissions(address(0), false);
            emit EmissionsStopped(mav.pool, newCollections, newIds);
        }

        emit NftRemoved(msg.sender, newCollections, newIds, idToRemove);
    }

    /// @notice Vote to shut down a pool 
    /// @dev Only NFTs that are actively held by the pool can vote to close
    /// @param _pool Pool targeted for closure
    /// @param _nft List of NFTs to vote for closure with (Must be owned by the caller)
    /// @param _ids List of IDs to vote for closure with (Must correspond with NFT list 
    /// and be owned by caller)
    function closePool(
        address _pool,
        address[] memory _nft,
        uint256[] memory _ids
    ) external nonReentrant {
        require(
            IVaultMulti(_pool)
                .getAmountOfReservations(IVaultMulti(_pool).getEpoch(block.timestamp)) == 0
        );
        uint256 length = _ids.length;
        for(uint256 i = 0; i < length; i++) {
            require(presentInPool[ _nft[i]][_ids[i]][_pool]);
            require(IERC721(_nft[i]).ownerOf(_ids[i]) == msg.sender);
            closureVotes[_pool]++;
            emit SignPoolClosure(_pool, msg.sender, _nft[i], _ids[i]);
        }

        (address[] memory collections, uint256[] memory ids) = IVaultMulti(_pool).getHeldTokens();
        if(closureVotes[_pool] >= multiAssetMapping[IVaultMulti(_pool).getNonce()].slots) {
            IVaultMulti(_pool).closePool();
            for(uint256 i = 0; i < collections.length; i++) {
                controller.updateNftUsage(address(0), collections[i], ids[i], false);
                delete presentInPool[collections[i]][ids[i]][msg.sender];
            }
            emit PoolClosed(_pool, collections, ids);
        }
    }

    /* ======== CLAIMING RETURNED FUNDS/EARNED FEES ======== */
    /// @notice Update a users pending return count
    /// @dev Pending returns come from funds that need to be returned from
    /// various pool contracts
    /// @param _user The recipient of these returned funds
    function updatePendingReturns(address _user) external payable {
        require(controller.accreditedAddresses(msg.sender));
        pendingReturns[_user] += msg.value;

        emit PendingReturnsUpdated(_user, msg.value);
    }

    /// @notice Claim the pending returns that have been sent for the user
    function claimPendingReturns() external nonReentrant {
        uint256 payout = pendingReturns[msg.sender];
        delete pendingReturns[msg.sender];
        payable(msg.sender).transfer(payout);

        emit PendingReturnsClaimed(msg.sender, payout);
    }

    /* ======== EVENT PROPAGATION ======== */

    function emitPayoutRatioAdjusted(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _user,
        uint256 _ratio
    ) external onlyAccredited {
        emit PayoutRatioAdjusted(msg.sender, _callerTokens, _callerTokenIds, _user, _ratio);
    }

    function emitPurchase(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _buyer, 
        uint256[] memory tickets,
        uint256[] memory amountPerTicket,
        uint256 _startEpoch,
        uint256 _finalEpoch
    ) external onlyAccredited {
        emit Purchase(
            msg.sender, 
            _callerTokens, 
            _callerTokenIds, 
            _buyer, tickets, 
            amountPerTicket, 
            _startEpoch, 
            _finalEpoch
        );
    }

    function emitSaleComplete(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _seller,
        uint256 _creditsPurchased
    ) external onlyAccredited {
        emit SaleComplete(msg.sender, _callerTokens, _callerTokenIds, _seller, _creditsPurchased);
    }

    function emitGeneralBribe(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _briber,
        uint256 _bribeAmount,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external onlyAccredited {
        emit GeneralBribeOffered(
            msg.sender, 
            _callerTokens, 
            _callerTokenIds, 
            _briber,
            _bribeAmount, 
            _startEpoch, 
            _endEpoch
        );
    }

    function emitConcentratedBribe(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _briber,
        uint256[] memory tickets,
        uint256[] memory bribePerTicket,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external onlyAccredited {
        emit ConcentratedBribeOffered(
            msg.sender, 
            _callerTokens, 
            _callerTokenIds, 
            _briber, tickets, 
            bribePerTicket, 
            _startEpoch, 
            _endEpoch
        );
    }

    function emitPoolRestored(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        uint256 _payoutPerReservation
    ) external onlyAccredited {
        emit PoolRestored(msg.sender, _callerTokens, _callerTokenIds, _payoutPerReservation);
    }

    function emitSpotReserved(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        uint256 _reservationId,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external onlyAccredited {
        emit SpotReserved(
            msg.sender, 
            _callerTokens, 
            _callerTokenIds, 
            _reservationId, 
            _startEpoch,
            _endEpoch
        );
    }

    function emitNftClosed(
        address[] memory _callerTokens,
        uint256[] memory _callerTokenIds,
        address _caller,
        uint256 _closedId,
        uint256 _payout,
        address _closePoolContract
    ) external onlyAccredited {
        emit NftClosed(
            msg.sender, 
            _callerTokens, 
            _callerTokenIds, 
            _closedId, 
            _caller, 
            _payout, 
            _closePoolContract
        ); 
    }

    function emitNewBid(
        address _pool,
        address _callerToken,
        uint256 _id,
        address _bidder,
        uint256 _bid
    ) external onlyAccredited {
        emit NewBid(_pool, msg.sender, _callerToken, _id, _bidder, _bid);
    }

    function emitAuctionEnded(
        address _pool,
        address _callerToken,
        uint256 _id,
        address _bidder,
        uint256 _bid
    ) external onlyAccredited {
        emit AuctionEnded(_pool, msg.sender, _callerToken, _id, _bidder, _bid);
    }

    function emitPrincipalCalculated(
        address _pool,
        address _callerToken,
        uint256 _id,
        address _user
    ) external onlyAccredited {
        emit PrincipalCalculated(_pool, msg.sender, _callerToken, _id, _user);
    }

    function emitPayout(
        address _pool,
        address _user,
        uint256 _payoutAmount
    ) external onlyAccredited {
        emit Payout(_pool, msg.sender, _user, _payoutAmount);
    }

    function emitLPTransfer(
        address[] memory _collections,
        uint256[] memory heldIds,
        address from,
        address to,
        uint256[] memory tickets,
        uint256[] memory amountPerTicket
    ) external onlyAccredited {
        emit LPTransferred(msg.sender, _collections, heldIds, from, to, tickets, amountPerTicket);
    }

    function emitPositionAllowance(
        address[] memory _collections,
        uint256[] memory heldIds,
        address from,
        address to
    ) external onlyAccredited {
        emit LPTransferAllowanceGranted(msg.sender, _collections, heldIds, from, to);
    }

    function emitLPInitiated(
        address[] memory _collections,
        uint256[] memory heldIds,
        address initiater
    ) external onlyAccredited {
        emit LPInitiated(msg.sender, _collections, heldIds, initiater);
    }
}