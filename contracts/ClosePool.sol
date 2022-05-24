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

contract ClosePool is ReentrancyGuard, Initializable {

    ///TODO: add events
    
    /* ======== ADDRESS ======== */

    /// @notice factory contract for Spot pools
    IVaultFactoryMulti public factory;

    /// @notice parent Spot pool
    IVaultMulti public vault;

    /// @notice protocol directory
    AbacusController public controller;

    address public heldToken;
    
    address public highestBidder;

    /* ======== UINT ======== */

    uint256 public heldTokenId;

    uint256 public auctionEndTime;

    uint256 public nftVal;

    uint256 public highestBid;

    uint256 public auctionPremium;

    /* ======== BOOL ======== */

    bool public auctionComplete;

    /* ======== MAPPING ======== */

    /// @notice user principal
    mapping(address => uint256) public principal;
    
    /// @notice was a users principal calculated
    mapping(address => bool) public principalCalculated;


    /* ======== CONSTRUCTOR ======== */

    function initialize(
        address _vault,
        address _controller,
        address _heldToken,
        uint256 _heldId,
        uint256 _nftVal,
        uint256 _version
    ) external initializer {
        vault = IVaultMulti(payable(_vault));
        controller = AbacusController(_controller);
        factory = IVaultFactoryMulti(controller.factoryVersions(_version));

        heldTokenId = _heldId;
        auctionEndTime = block.timestamp + 12 hours;
        nftVal = _nftVal;
        heldToken = _heldToken;
    }

    /// @notice submit new bid in NFT auction
    function newBid() nonReentrant payable external {
        // take gas fee
        ABCToken(controller.abcToken()).bypassTransfer(msg.sender, controller.epochVault(), controller.abcGasFee());
        IEpochVault(controller.epochVault()).receiveAbc(controller.abcGasFee());

        // check that user bid is higher than previous and that auction is ongoing 
        require(msg.value > highestBid);
        require(block.timestamp < auctionEndTime);

        factory.updatePendingReturns{ 
            value:highestBid
        } ( highestBidder );

        // update most recent bid, highest bid, highest bidder
        highestBid = msg.value;
        highestBidder = msg.sender;
    }

    /// @notice end auction once time concludes
    function endAuction() nonReentrant external {
        require(
            block.timestamp > auctionEndTime
            && !auctionComplete
        );

        // check if the NFT sold at a premium
        if(highestBid > nftVal) {
            auctionPremium = highestBid - nftVal;
        }

        // auction concludes, send NFT to winner
        auctionComplete = true;
        IERC721(heldToken).transferFrom(
            address(this), 
            highestBidder, 
            heldTokenId
        );
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
    function calculatePrincipal(address _user) nonReentrant external {
        require(!principalCalculated[_user]);
        require(auctionComplete);
        principalCalculated[_user] = vault.adjustTicketInfo(
            _user,
            highestBid,
            heldTokenId
        );
    }

    function payout(address _user, uint256 payoutAmount) external {
        require(msg.sender == address(vault));
        factory.updatePendingReturns{
            value:payoutAmount
        }(_user);
    }

    /// @notice returns premium earned in auction sale 
    function getAuctionPremium() view external returns(uint256) {
        return auctionPremium;
    }

    /// @notice returns auction end time
    function getAuctionEndTime() view external returns(uint256) {
        return auctionEndTime;
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}