//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./helpers/ReentrancyGuard.sol";
import { AbacusController } from "./AbacusController.sol";
import { ABCToken } from "./AbcToken.sol";
import { IVaultFactory } from "./interfaces/IVaultFactory.sol";
import { IVaultFactoryMulti } from "./interfaces/IVaultFactoryMulti.sol";
import { IVaultMulti } from "./interfaces/IVaultMulti.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { IVeAbc } from "./interfaces/IVeAbc.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "hardhat/console.sol";

contract ClosePoolMulti is ReentrancyGuard, Initializable {

    ///TODO: add events
    
    /* ======== ADDRESS ======== */

    /// @notice factory contract for Spot pools
    IVaultFactoryMulti public factory;

    /// @notice parent Spot pool
    IVaultMulti public vault;

    /// @notice protocol directory
    AbacusController public controller;

    address public heldCollection;

    /* ======== UINT ======== */

    uint256 public liveAuctions;

    /* ======== MAPPING ======== */

    mapping(uint256 => address) public highestBidder;

    mapping(uint256 => uint256) public auctionEndTime;

    mapping(uint256 => uint256) public nftVal;

    mapping(uint256 => uint256) public highestBid;

    mapping(uint256 => uint256) public auctionPremium;

    mapping(uint256 => bool) public auctionComplete;
    
    /// @notice track available credits based on when pool closed
    mapping(address => uint256) public availableCredits;

    /// @notice user principal
    mapping(address => uint256) public principal;

    /// @notice user profit
    mapping(address => uint256) public profit;
    
    /// @notice was a users principal calculated
    mapping(uint256 => mapping(address => bool)) public principalCalculated;

    /// @notice track whether a user has already calculated their available credit count
    mapping(address => bool) public availableCreditsCalculated;

    /// @notice did a user close their account already
    mapping(address => bool) public claimed;

    /* ======== CONSTRUCTOR ======== */

    function initialize(
        address _vault,
        address _controller,
        address _heldCollection,
        uint256 _version
    ) external initializer {
        vault = IVaultMulti(payable(_vault));
        controller = AbacusController(_controller);
        factory = IVaultFactoryMulti(controller.factoryVersions(_version));

        heldCollection = _heldCollection;
    }

    /* ======== AUCTION ======== */

    function startAuction(uint256 _nftVal, uint256 _id) nonReentrant external {
        require(msg.sender == address(vault));
        auctionEndTime[_id] = block.timestamp + 12 hours;
        nftVal[_id] = _nftVal;
        vault.updateRestorationNonce();
        liveAuctions++;
    }

    /// @notice submit new bid in NFT auction
    function newBid(uint256 _id) nonReentrant payable external {
        // take gas fee
        ABCToken(controller.abcToken()).bypassTransfer(msg.sender, controller.epochVault(), controller.abcGasFee());
        IEpochVault(controller.epochVault()).receiveAbc(controller.abcGasFee());

        // check that user bid is higher than previous and that auction is ongoing 
        require(msg.value > highestBid[_id]);
        require(block.timestamp < auctionEndTime[_id]);

        factory.updatePendingReturns{ 
            value:highestBid[_id]
        } ( highestBidder[_id] );

        // update most recent bid, highest bid, highest bidder
        highestBid[_id] = msg.value;
        highestBidder[_id] = msg.sender;
    }

    /// @notice end auction once time concludes
    function endAuction(uint256 _id) nonReentrant external {
        require(
            block.timestamp > auctionEndTime[_id]
            && !auctionComplete[_id]
        );

        // check if the NFT sold at a premium
        if(highestBid[_id] > nftVal[_id]) {
            auctionPremium[_id] = highestBid[_id] - nftVal[_id];
        }

        // auction concludes, send NFT to winner
        auctionComplete[_id] = true;
        IERC721(heldCollection).transferFrom(
            address(this), 
            highestBidder[_id], 
            _id
        );

        vault.updateAvailFunds(_id, highestBid[_id]);
        liveAuctions--;
    }

    /* ======== ACCOUNT CLOSURE ======== */

    /// @notice Calculate a users principal based on their open tickets
    /** 
    @dev (1) If user ticket is completely over the value of the ending auction price they lose their entire ticket balance.
         (2) If user ticket is partially over final nft value then the holders of that ticket receive a discounted return per token
            - Ex: NFT val -> 62 E. Any ticket up to 60 E will be made whole, but anyone who holds position in ticket 60 - 63 E will
                             receive 2/3 of their position in the 60 - 63 E ticket.
         (3) If user ticket is within price range they receive entire position. 
            - Ex: NFT val -> 65 E and user position 0 - 3 E, they'll be made whole.
    */
    function calculatePrincipal(address _user, uint256 _id) nonReentrant external {
        require(!principalCalculated[_id][_user]);
        require(auctionComplete[_id]);
        principalCalculated[_id][_user] = vault.adjustTicketInfo(
            _user,
            highestBid[_id],
            _id
        );
    }

    function payout(address _user, uint256 payoutAmount) external {
        require(msg.sender == address(vault));
        factory.updatePendingReturns{
            value:payoutAmount
        }(_user);
    }

    /// @notice returns premium earned in auction sale 
    function getAuctionPremium(uint256 _id) view external returns(uint256 premium) {
        premium = auctionPremium[_id];
    }

    /// @notice returns auction end time
    function getAuctionEndTime(uint256 _id) view external returns(uint256 endTime) {
        endTime = auctionEndTime[_id];
    }

    function getLiveAuctionCount() view external returns(uint256 _liveAuctions) {
        _liveAuctions = liveAuctions;
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}