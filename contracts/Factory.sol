//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ABCToken } from "./AbcToken.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { Vault } from "./Vault.sol";
import { IVault } from "./interfaces/IVault.sol";
import { Closure } from "./Closure.sol";
import { IClosure } from "./interfaces/IClosure.sol";
import { Treasury } from "./Treasury.sol";
import { AbacusController } from "./AbacusController.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import "hardhat/console.sol";
import "./helpers/ReentrancyGuard.sol";

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

/// @title Multi Asset Vault Factory
/// @author Gio Medici
/// @notice The factory is responsible for producing and managing spot pools
contract Factory is ReentrancyGuard {

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

    /// @notice Track each pool using a unique multi asset mapping nonce
    /// [uint256] -> nonce
    mapping(uint256 => MultiAssetVault) public multiAssetMapping;

    /// TODO: REMOVE FOR PROD
    mapping(address => mapping(uint256 => address)) public recentlyCreatedPool;

    mapping(string => address[]) public vaultNames;

    /* ======== MAPPING ======== */
    /// @notice Store information regarding a multi asset pool
    /// [pool] -> pool address
    /// [slots] -> amount of NFTs that can be borrowed against at once
    /// [amountSigned] -> amount of NFTs signed to turn on emissions
    struct MultiAssetVault {
        string name;
        address pool;
        uint32 slots;
        uint32 nftRemoved;
        uint32 amountSigned;
    }

    /* ======== EVENT ======== */

    event VaultCreated(string name, address _creator, address _pool);
    event VaultStarted(string name, address _pool, uint256 slots);
    event VaultSigned(address _pool, address _signer, address[] nftAddress, uint256[] ids);
    event NftInclusion(address _pool, uint256[] nfts);
    event VaultBegun(address _pool);
    event EmissionsStarted(address _pool);
    event EmissionsStopped(address _pool);
    event SignPoolClosure(address _pool, address _signer,address _collections, uint256 _idSigned);
    event NftRemoved(address _pool, address removedAddress, uint256 removedId);
    event PoolClosed(address _pool); 
    event PendingReturnsUpdated(address _user, uint256 _amount);
    event PendingReturnsClaimed(address _user, uint256 _amount);
    event PayoutRatioAdjusted(address _pool, address _user, uint256 _ratio);
    event Purchase(address _pool, address _buyer, uint256[] tickets, uint256[] amountPerTicket, uint256 nonce, uint256 startEpoch, uint256 finalEpoch);
    event SaleComplete(address _pool,  address _seller, uint256 nonce, uint256 ticketsSold, uint256 creditsPurchased);
    event GeneralBribeOffered(address _pool, address _briber, uint256 _bribeAmount, uint256 startEpoch, uint256 endEpoch);
    event ConcentratedBribeOffered(address _pool, address _briber, uint256[] tickets, uint256[] bribePerTicket, uint256 startEpoch, uint256 endEpoch);
    event PoolRestored(address _pool, uint256 newPayoutPerReservation);
    event SpotReserved(address _pool, uint256 reservationId, uint256 startEpoch, uint256 endEpoch);
    event NftClosed(address _pool, address _collection, uint256 _id, address _caller, uint256 payout, address closePoolContract); 
    event NewBid(address _pool, address _closePoolContract, address _collection, uint256 _id, address _bidder, uint256 _bid);
    event AuctionEnded(address _pool, address _closePoolContract, address _collection, uint256 _id, address _winner, uint256 _highestBid);
    event PrincipalCalculated(address _pool, address _closePoolContract, address _collection, uint256 _id, address _user, uint256 _nonce);
    event Payout(address _pool, address _closePoolContract, address _user, uint256 _payoutAmount);
    event LPTransferAllowanceGranted(address _pool, address from, address to);
    event LPTransferred(address _pool, address from, address to, uint256[] tickets, uint256[] amountPerTicket);


    /* ======== MODIFIER ======== */
    
    modifier onlyAccredited {
        require(controller.accreditedAddresses(msg.sender));
        _;
    }

    /* ======== CONSTRUCTOR ======== */

    constructor(address _controller) {
        _closePoolImplementation = address(new Closure());
        _vaultMultiImplementation = address(new Vault());
        controller = AbacusController(_controller);
        vaultVersion = 1;
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}

    /* ======== POOL CREATION ======== */
    /// @notice Create a multi asset vault
    /// @dev The creator will have to pay a creation fee (denominated in ABC)
    /// @param name Name of the pool
    function initiateMultiAssetVault(
        string memory name
    ) external nonReentrant {
        require(
            vaultNames[name].length == 0
            || IVault(vaultNames[name][vaultNames[name].length - 1]).getPoolClosedStatus()
        );
        uint256 beta = controller.beta();
        if(beta == 1) {
            require(controller.userWhitelist(msg.sender));
        }

        MultiAssetVault storage mav = multiAssetMapping[multiAssetVaultNonce];
        IVault vaultMultiDeployment = IVault(
            Clones.clone(_vaultMultiImplementation)
        );

        vaultMultiDeployment.initialize(
            vaultVersion,
            multiAssetVaultNonce,
            address(controller),
            _closePoolImplementation,
            msg.sender
        );

        controller.addAccreditedAddressesMulti(address(vaultMultiDeployment));
        mav.pool = address(vaultMultiDeployment);
        mav.name = name;
        vaultNames[name].push(address(vaultMultiDeployment));
        multiAssetVaultNonce++;
        emit VaultCreated(name, msg.sender, address(vaultMultiDeployment));
    }

    function updateSlotCount(uint256 mavNonce, uint256 slots) external {
        require(controller.accreditedAddresses(msg.sender));
        multiAssetMapping[mavNonce].slots = uint32(slots);
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
        for(uint256 i = 0; i < length; i++) {
            address collection = nft[i];
            uint256 _id = id[i];
            require(IVault(pool).getHeldTokenExistence(collection, _id));
            require(msg.sender == IERC721(collection).ownerOf(_id));
            require(controller.collectionWhitelist(collection));
            require(
                !controller.nftVaultSigned(collection, _id)
                || IVault(controller.nftVaultSignedAddress(collection, _id)).getPoolClosedStatus()
            );
            controller.updateNftUsage(pool, collection, _id, true);
            mav.amountSigned++;
        }
        emit VaultSigned(pool, msg.sender, nft, id);
        
        if(mav.amountSigned >= mav.slots) {
            IVault(mav.pool).toggleEmissions(boostedCollection, true);
            emit EmissionsStarted(pool);
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
    ) external {
        MultiAssetVault storage mav = multiAssetMapping[multiVaultNonce];
        require(controller.accreditedAddresses(msg.sender));
        require(IVault(mav.pool).getHeldTokenExistence(nftToRemove, idToRemove));
        controller.updateNftUsage(address(0), nftToRemove, idToRemove, false);
        mav.nftRemoved++;
        mav.amountSigned--;
        if(mav.amountSigned < mav.slots) {
            IVault(mav.pool).toggleEmissions(address(0), false);
            emit EmissionsStopped(mav.pool);
        }
        if(mav.nftRemoved == mav.slots) {
            IVault(mav.pool).closePool();
            emit PoolClosed(mav.pool);
        }

        emit NftRemoved(msg.sender, nftToRemove, idToRemove);
    }

    /* ======== CLAIMING RETURNED FUNDS/EARNED FEES ======== */
    /// @notice Update a users pending return count
    /// @dev Pending returns come from funds that need to be returned from
    /// various pool contracts
    /// @param _user The recipient of these returned funds
    function updatePendingReturns(address _user) external payable nonReentrant {
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

    function emitNftInclusion(
        uint256[] memory encodedNfts
    ) external onlyAccredited {
        emit NftInclusion(msg.sender, encodedNfts);
    }

    function emitPoolBegun() external onlyAccredited {
        emit VaultBegun(msg.sender);
    }

    function emitPurchase(
        address _buyer, 
        uint256[] memory tickets,
        uint256[] memory amountPerTicket,
        uint256 nonce,
        uint256 _startEpoch,
        uint256 _finalEpoch
    ) external onlyAccredited {
        emit Purchase(
            msg.sender, 
            _buyer, 
            tickets, 
            amountPerTicket, 
            nonce,
            _startEpoch, 
            _finalEpoch
        );
    }

    function emitSaleComplete(
        address _seller,
        uint256 _nonce,
        uint256 _ticketsSold,
        uint256 _creditsPurchased
    ) external onlyAccredited {
        emit SaleComplete(
            msg.sender, 
            _seller, 
            _nonce,
            _ticketsSold, 
            _creditsPurchased
        );
    }

    function emitGeneralBribe(
        address _briber,
        uint256 _bribeAmount,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external onlyAccredited {
        emit GeneralBribeOffered(
            msg.sender, 
            _briber,
            _bribeAmount, 
            _startEpoch, 
            _endEpoch
        );
    }

    function emitConcentratedBribe(
        address _briber,
        uint256[] memory tickets,
        uint256[] memory bribePerTicket,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external onlyAccredited {
        emit ConcentratedBribeOffered(
            msg.sender, 
            _briber, 
            tickets, 
            bribePerTicket, 
            _startEpoch, 
            _endEpoch
        );
    }

    function emitPoolRestored(
        uint256 _payoutPerReservation
    ) external onlyAccredited {
        emit PoolRestored(
            msg.sender, 
            _payoutPerReservation
        );
    }

    function emitSpotReserved(
        uint256 _reservationId,
        uint256 _startEpoch,
        uint256 _endEpoch
    ) external onlyAccredited {
        emit SpotReserved(
            msg.sender, 
            _reservationId, 
            _startEpoch,
            _endEpoch
        );
    }

    function emitNftClosed(
        address _caller,
        address _nft,
        uint256 _closedId,
        uint256 _payout,
        address _closePoolContract
    ) external onlyAccredited {
        emit NftClosed(
            msg.sender, 
            _nft,
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
        emit NewBid(
            _pool, 
            msg.sender, 
            _callerToken, 
            _id, 
            _bidder, 
            _bid
        );
    }

    function emitAuctionEnded(
        address _pool,
        address _callerToken,
        uint256 _id,
        address _bidder,
        uint256 _bid
    ) external onlyAccredited {
        emit AuctionEnded(
            _pool, 
            msg.sender, 
            _callerToken, 
            _id, 
            _bidder,
            _bid
        );
    }

    function emitPrincipalCalculated(
        address _pool,
        address _callerToken,
        uint256 _id,
        address _user,
        uint256 _nonce
    ) external onlyAccredited {
        emit PrincipalCalculated(
            _pool, 
            msg.sender, 
            _callerToken, 
            _id, 
            _user, 
            _nonce
        );
    }

    function emitPayout(
        address _pool,
        address _user,
        uint256 _payoutAmount
    ) external onlyAccredited {
        emit Payout(
            _pool, 
            msg.sender, 
            _user, 
            _payoutAmount
        );
    }

    function emitLPTransfer(
        address from,
        address to,
        uint256[] memory tickets,
        uint256[] memory amountPerTicket
    ) external onlyAccredited {
        emit LPTransferred(
            msg.sender, 
            from, 
            to, 
            tickets, 
            amountPerTicket
        );
    }

    function emitPositionAllowance(
        address from,
        address to
    ) external onlyAccredited {
        emit LPTransferAllowanceGranted(
            msg.sender, 
            from, 
            to
        );
    }

    /* ======== GETTERS ======== */

    function encodeCompressedValue(
        address[] memory nft,
        uint256[] memory id
    ) external pure returns(
        uint256[] memory _compTokenInfo
    ) {
        _compTokenInfo = id;
        uint256 length = id.length;
        for(uint256 i = 0; i < length; i++) {
            uint256 _compVal;
            _compVal |= id[i];
            _compVal <<= 160;
            _compVal |= uint160(nft[i]);
            _compTokenInfo[i] = _compVal;
        }
    }

    function decodeCompressedValue(
        uint256 _compTokenInfo
    ) external pure returns(address _nft, uint256 _id) {
        _nft = address(uint160(_compTokenInfo & (2**160-1)));
        _id = _compTokenInfo >> 160;
    }

    function decodeCompressedTickets(
        uint256 comTickets
    ) external pure returns(
        uint256 stopIndex,
        uint256[10] memory tickets 
    ) {
        uint256 i;
        uint256 tracker = 1;
        while(tracker > 0) {
            tracker = comTickets;
            uint256 ticket = comTickets & 0x7fff;
            comTickets >>= 16;

            if(tracker != 0) {
                tickets[i] = ticket;
            } else {
                stopIndex = i;
            }
            i++;
        }
    }
}