//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Vault } from "./Vault.sol";
import { IVault } from "./interfaces/IVault.sol";
import { Closure } from "./Closure.sol";
import { AbacusController } from "./AbacusController.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
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

    /* ======== MAPPING ======== */
    /// @notice ETH to be returned from all vaults is routed this mapping
    /// [address] -> User
    /// [uint256] -> Return amount 
    mapping(address => uint256) public pendingReturns;

    /// @notice Track each pool using a unique multi asset mapping nonce
    /// [uint256] -> nonce
    mapping(string => SpotPool) public poolMapping;

    /* ======== MAPPING ======== */
    /// @notice Store information regarding a multi asset pool
    /// [slots] -> amount of NFTs that can be borrowed against at once
    /// [nftsInPool] -> total amount of NFTs linked to a pool
    /// [pool] -> pool address
    struct SpotPool {
        uint32 slots;
        uint64 nftsInPool;
        address pool;
    }

    /* ======== EVENT ======== */
    event VaultCreated(string name, address _creator, address _pool);
    event VaultSigned(address _pool, address _signer, address[] nftAddress, uint256[] ids);
    event NftInclusion(address _pool, uint256[] nfts);
    event VaultBegun(address _pool, uint256 _collateralSlots, uint256 _ticketSize, uint256 _interest, uint256 _epoch);
    event NftRemoved(address _pool, address removedAddress, uint256 removedId);
    event PendingReturnsUpdated(address _user, uint256 _amount);
    event PendingReturnsClaimed(address _user, uint256 _amount);
    event Purchase(address _pool, address _buyer, uint256[] tickets, uint256[] amountPerTicket, uint256 nonce, uint256 startEpoch, uint256 finalEpoch);
    event SaleComplete(address _pool,  address _seller, uint256 nonce, uint256 ticketsSold, uint256 creditsPurchased);
    event SpotReserved(address _pool, uint256 reservationId, uint256 startEpoch, uint256 endEpoch);
    event NftClosed(address _pool, address _collection, uint256 _id, address _caller, uint256 payout, address closePoolContract); 
    event NewBid(address _pool, address _closePoolContract, address _collection, uint256 _id, address _bidder, uint256 _bid);
    event AuctionEnded(address _pool, address _closePoolContract, address _collection, uint256 _id, address _winner, uint256 _highestBid);
    event PrincipalCalculated(address _pool, address _closePoolContract, address _collection, uint256 _id, address _user, uint256 _nonce, uint256 _closureNonce);
    event Payout(address _pool, address _closePoolContract, address _user, uint256 _payoutAmount);
    event LPTransferAllowanceChanged(address _pool, address from, address to);
    event LPTransferred(address _pool, address from, address to, uint256 nonce);

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
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== POOL CREATION ======== */
    /// SEE IFactory.sol FOR COMMENTS
    function initiateMultiAssetVault(
        string memory name
    ) external nonReentrant {
        uint256 beta = controller.beta();
        if(beta == 1) {
            require(controller.userWhitelist(msg.sender));
        }

        SpotPool storage pool = poolMapping[name];
        require(pool.pool == address(0));
        IVault vaultMultiDeployment = IVault(
            Clones.clone(_vaultMultiImplementation)
        );

        vaultMultiDeployment.initialize(
            name,
            address(controller),
            _closePoolImplementation,
            msg.sender
        );

        controller.addAccreditedAddressesMulti(address(vaultMultiDeployment));
        pool.pool = address(vaultMultiDeployment);
        emit VaultCreated(name, msg.sender, address(vaultMultiDeployment));
    }

    /// SEE IFactory.sol FOR COMMENTS
    function updateSlotCount(string memory name, uint256 slots, uint256 amountNfts) external {
        require(controller.accreditedAddresses(msg.sender));
        poolMapping[name].slots = uint32(slots);
        poolMapping[name].nftsInPool = uint64(amountNfts);
    }

    /* ======== CLAIMING RETURNED FUNDS/EARNED FEES ======== */
    /// SEE IFactory.sol FOR COMMENTS
    function updatePendingReturns(address _user) external payable nonReentrant {
        require(controller.accreditedAddresses(msg.sender), "NA");
        pendingReturns[_user] += msg.value;
        emit PendingReturnsUpdated(_user, msg.value);
    }

    /// SEE IFactory.sol FOR COMMENTS
    function claimPendingReturns() external nonReentrant {
        uint256 payout = pendingReturns[msg.sender];
        delete pendingReturns[msg.sender];
        payable(msg.sender).transfer(payout);
        emit PendingReturnsClaimed(msg.sender, payout);
    }

    /* ======== EVENT PROPAGATION ======== */
    function emitNftInclusion(
        uint256[] calldata encodedNfts
    ) external onlyAccredited {
        emit NftInclusion(msg.sender, encodedNfts);
    }

    function emitPoolBegun(
        uint256 _collateralSlots,
        uint256 _ticketSize,
        uint256 _interestRate,
        uint256 _epochLength
    ) external onlyAccredited {
        emit VaultBegun(
            msg.sender,
            _collateralSlots,
            _ticketSize,
            _interestRate,
            _epochLength
        );
    }

    function emitPurchase(
        address _buyer, 
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket,
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
        uint256 _interestEarned
    ) external onlyAccredited {
        emit SaleComplete(
            msg.sender, 
            _seller, 
            _nonce,
            _ticketsSold, 
            _interestEarned
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
        uint256 _nonce,
        uint256 _closureNonce
    ) external onlyAccredited {
        emit PrincipalCalculated(
            _pool, 
            msg.sender, 
            _callerToken, 
            _id, 
            _user, 
            _nonce,
            _closureNonce
        );
    }

    function emitLPTransfer(
        address from,
        address to,
        uint256 nonce
    ) external onlyAccredited {
        emit LPTransferred(
            msg.sender, 
            from, 
            to, 
            nonce
        );
    }

    function emitPositionAllowance(
        address from,
        address to
    ) external onlyAccredited {
        emit LPTransferAllowanceChanged(
            msg.sender, 
            from, 
            to
        );
    }

    /* ======== GETTERS ======== */
    function getSqrt(uint x) external pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function getPoolAddress(string memory name) external view returns(address) {
        return poolMapping[name].pool;
    }

    function getEncodedCompressedValue(
        address[] calldata nft,
        uint256[] calldata id
    ) external pure returns(
        uint256[] memory _compTokenInfo
    ) {
        _compTokenInfo = id;
        uint256 length = id.length;
        for(uint256 i = 0; i < length; i++) {
            uint256 _compVal;
            _compVal |= uint160(nft[i]);
            _compVal <<= 95;
            _compVal |= id[i];
            _compTokenInfo[i] = _compVal;
        }
    }

    function getDecodedCompressedValue(
        uint256 _compTokenInfo
    ) external pure returns(address _nft, uint256 _id) {
        _id = _compTokenInfo & (2**95-1);
        uint256 temp = _compTokenInfo >> 95;
        _nft = address(uint160(temp & (2**160-1)));
    }

    function getDecodedCompressedTickets(
        uint256 comTickets
    ) external pure returns(
        uint256 stopIndex,
        uint256[10] memory tickets 
    ) {
        uint256 i;
        uint256 tracker = 1;
        while(tracker > 0) {
            tracker = comTickets;
            uint256 ticket = comTickets & (2**25 - 1);
            comTickets >>= 25;

            if(tracker != 0) {
                tickets[i] = ticket;
            } else {
                stopIndex = i;
            }
            i++;
        }
    }
}