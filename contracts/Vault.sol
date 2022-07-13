//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ABCToken } from "./AbcToken.sol";
import { AbacusController } from "./AbacusController.sol";
import { IClosure } from "./interfaces/IClosure.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { IAllocator } from "./interfaces/IAllocator.sol";
import { ICreditBonds } from "./interfaces/ICreditBond.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import "./helpers/ReentrancyGuard.sol";
import "./helpers/ReentrancyGuard2.sol";
import "hardhat/console.sol";


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

/// @title Spot pool
/// @author Gio Medici
/// @notice Spot pools allow users to collateralize any combination of NFT collections and IDs
contract Vault is ReentrancyGuard, ReentrancyGuard2, Initializable {

    /* ======== ADDRESS ======== */

    IFactory factory;

    AbacusController controller;

    ABCToken abcToken;

    IEpochVault epochVault;

    IAllocator alloc;

    /// @notice Address of deployer
    address public creator;

    /// @notice Address of the deployed closure contract
    address public closePoolContract;

    /// @notice Address of the chosen boost collection
    address public boostCollection;

    address private _closePoolMultiImplementation;

    /* ======== UINT ======== */

    uint256 public amountNftsLinked;

    /// @notice Epoch during which the pool was closed
    uint256 public poolClosureEpoch;

    uint256 MAPoolNonce;

    /// @notice The amount of available NFT closures
    uint256 public reservationsAvailable;

    /// @notice Total amount of slots to be collateralized
    uint256 public amountNft;

    /// @notice Pool creation time
    uint256 public startTime;

    /// @notice Vault version (corresponds to the factory version that created this)
    uint8 public vaultVersion;

    /// @notice Total amount of adjustments required (every time an NFT is 
    /// closed this value increments)
    uint256 public adjustmentsRequired;

    /* ======== BOOLEANS ======== */

    /// @notice Status of pool closure
    bool public poolClosed;

    /* ======== MAPPINGS ======== */

    mapping(address => mapping(uint256 => mapping(uint256 => bool))) public emissionsStarted;

    mapping(uint256 => uint256) public emissionStartedCount;

    /// @notice Used to track the existence of tokens within the pool
    /// [uint256] -> Compressed token information (address and ID)
    /// [bool] -> Status of presence in the pool
    mapping(uint256 => bool) public tokenMapping;

    /// @notice Track the total loss logged based on the auction sale value and payout size
    /// [address] -> NFT collection
    /// [uint256] -> NFT token ID
    /// [uint256] -> Loss experienced from the auction
    mapping(address => mapping(uint256 => uint256)) public loss;

    /// @notice Track adjustment status of closed NFTs
    /// [address] -> User 
    /// [address] -> NFT collection
    /// [uint256] -> NFT ID
    /// [bool] -> Status of adjustment
    mapping(address => mapping(address => mapping(uint256 => bool))) public adjustCompleted;

    /// @notice Unique tag for each position purchased by a user
    /// [address] -> user
    /// [uint256] -> nonce
    mapping(address => uint256) public positionNonce;

    /// @notice The epoch during which a specific NFT was closed
    /// [address] -> NFT Collection address
    /// [uint256] -> NFT ID
    /// [uint256] -> epoch that the NFT was closed on
    mapping(address => mapping(uint256 => uint256)) public epochOfClosure;

    /// @notice Tracking the adjustments made by each user for each open nonce
    /// [address] -> user
    /// [uint256] -> nonce
    /// [uint256] -> amount of adjustments made
    mapping(address => mapping(uint256 => uint256)) public adjustmentsMade;

    /// @notice Largest ticket in an epoch
    /// [uint256] -> epoch
    /// [uint256] -> max ticket 
    mapping(uint256 => uint256) public maxTicketPerEpoch;

    /// @notice Amount of reservations made during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> amount of reservations
    mapping(uint256 => uint256) public reservations;

    mapping(uint256 => uint256) totalReservationValue;

    /// @notice NFT auction sale value
    /// [address] -> NFT collection 
    /// [uint256] -> NFT token ID 
    /// [uint256] -> Auction sale value
    mapping(address => mapping(uint256 => uint256)) public auctionSaleValue;

    /// @notice Amount of tokens purchased within a ticket
    /// [uint256] -> epoch
    /// [uint256] -> ticket
    /// [uint256] -> tokens purchased
    mapping(uint256 => mapping(uint256 => uint256)) public ticketsPurchased;

    /// @notice Nonces to close for each user during an epoch
    /// [address] -> user
    /// [uint256] -> epoch
    /// [uint256[]] -> list of nonces to close
    mapping(address => mapping(uint256 => uint256[])) public noncesToClosePerEpoch;

    /// @notice Payout size for each reservation during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> payout size
    mapping(uint256 => uint256) public payoutPerRes;

    /// @notice Total available funds in the pool during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> available funds
    mapping(uint256 => uint256) public totAvailFunds;

    /// @notice Track a traders profile for each epoch
    /// [address] -> user
    /// [uint256] -> epoch
    mapping(address => mapping(uint256 => Buyer)) public traderProfile;

    /// @notice Track status of reservations made by an NFT during an epoch 
    /// [uint256] -> epoch
    /// [address] -> NFT Collection address
    /// [uint256] -> NFT ID
    /// [bool] -> status of whether a reservation was made
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public reservationMade;

    /// @notice Track general bribe size during an epoch (paid out to all tickets on 
    /// risk adjusted basis)
    /// [uint256] -> epoch 
    /// [uint256] -> amount of bribes offered
    mapping(uint256 => uint256) public generalBribe;

    /// @notice General bribe offered by a user 
    /// [address] -> User
    /// [uint256] -> Epoch
    /// [uint256] -> Bribe offered
    mapping(address => mapping(uint256 => uint256)) public generalBribeOffered;

    /// @notice Track whether an address has been added to 'addressesToClosePerEpoch'
    mapping(address => mapping(uint256 => bool)) public addedToEpoch;

    /// @notice Track concentrated bribes offered to specific tickets during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> ticket
    /// [uint256] -> bribe amount
    mapping(uint256 => mapping(uint256 => uint256)) public concentratedBribe;

    /// @notice Concentrated bribe offered by a user
    /// [address] -> User
    /// [uint256] -> Epoch
    /// [uint256] -> Target tranche
    /// [uint256] -> Amount
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public concentratedBribeOffered;

    /// @notice Track an addresses allowance status to trade another addresses position
    /// [address] allower
    /// [address] allowee
    /// [uint256] nonce
    /// [bool] allowance status
    mapping(address => mapping(address => mapping(uint256 => bool))) public allowanceTracker;
    
    /* ======== STRUCTS ======== */
    /// @notice Holds core metrics for each trader
    /// [multiplier] -> the multiplier applied to a users credit intake when closing a position
    /// [startEpoch] -> epoch that the position was opened
    /// [unlockEpoch] -> epoch that the position can be closed
    /// [comListOfTickets] -> compressed (using bit shifts) value containing the list of tranches
    /// [comAmountPerTicket] -> compressed (using bit shifts) value containing the list of amounts
    /// of tokens purchased in each tranche
    /// [ethLocked] -> total amount of eth locked in the position
    struct Buyer {
        uint32 multiplier;
        uint32 startEpoch;
        uint32 unlockEpoch;
        uint256 comListOfTickets;
        uint256 comAmountPerTicket;
        uint256 ethLocked;
    }

    /* ======== CONSTRUCTOR ======== */
    
    function initialize(
        uint256 _vaultVersion,
        uint256 nonce,
        address _controller,
        address closePoolImplementation_,
        address _creator
    ) external initializer {
        controller = AbacusController(_controller);
        abcToken = ABCToken(controller.abcToken());
        epochVault = IEpochVault(controller.epochVault());
        factory = IFactory(controller.factoryVersions(_vaultVersion));
        alloc = IAllocator(controller.allocator());

        creator = _creator;
        vaultVersion = uint8(_vaultVersion);
        MAPoolNonce = nonce;
        _closePoolMultiImplementation = closePoolImplementation_;
    }

    /* ======== USER ADJUSTMENTS ======== */
    /// @notice Turn the emissions on and off
    /// @dev Only callable by the factory contract
    /// @param _nft Address of NFT collection
    /// @param _id ID of NFT
    /// @param emissionStatus The state new state of 'emissionsStarted' 
    function toggleEmissions(address _nft, uint256 _id, bool emissionStatus) external {
        require(!poolClosed);
        uint256 poolEpoch;
        if(startTime == 0) {
            poolEpoch = 0;
        } else {
            poolEpoch = (block.timestamp - startTime) / 1 days;
        }
        if(!emissionStatus) {
            require(msg.sender == address(factory));
        } else {
            require(
                msg.sender == address(factory)
                || IERC721(_nft).ownerOf(_id) == msg.sender
            );
            require(controller.nftVaultSignedAddress(_nft, _id) == address(this));
        }
        if(emissionStatus) {
            (uint256 currentBoostNum, uint256 currentBoostDen) = alloc.calculateBoost(boostCollection);
            (uint256 newBoostNum, uint256 newBoostDen) = alloc.calculateBoost(_nft);
            uint256 currentBoost = (currentBoostDen == 0 ? 100 : (100 + 100 * currentBoostNum / currentBoostDen));
            uint256 newBoost = (newBoostDen == 0 ? 100 : (100 + 100 * newBoostNum / newBoostDen));
            if(
                emissionStartedCount[poolEpoch] == 0
                || newBoost > currentBoost
            ) {
                boostCollection = _nft;
            }
            emissionsStarted[_nft][_id][poolEpoch] = true;
            emissionStartedCount[poolEpoch]++;
        } else if(emissionsStarted[_nft][_id][poolEpoch]) {
            emissionsStarted[_nft][_id][poolEpoch] = false;
            emissionStartedCount[poolEpoch]--;
        }

        factory.emitToggle(_nft, _id, emissionStatus, emissionStartedCount[poolEpoch]);
    }

    /* ======== CONFIGURATION ======== */
    /// @notice [setup phase] Give an NFT access to the pool 
    /// @param _compTokenInfo Compressed list of NFT collection address and token ID information
    function includeNft(uint256[] memory _compTokenInfo) external {
        require(startTime == 0);
        require(msg.sender == creator);
        uint256 length = _compTokenInfo.length;
        for(uint256 i = 0; i < length; i++) {
            address collection = address(uint160(_compTokenInfo[i] & (2**160-1)));
            uint256 id = _compTokenInfo[i] >> 160;
            if(controller.beta() == 2) {
                require(
                    controller.collectionWhitelist(collection)
                    || msg.sender == controller.admin()
                );
            }
            require(IERC721(collection).ownerOf(id) != address(0));
            tokenMapping[_compTokenInfo[i]] = true;
        }

        amountNftsLinked += length;
        factory.emitNftInclusion(_compTokenInfo);
    }

    /// @notice [setup phase] Start the pools operation
    /// @param slots The amount of collateral slots the pool will offer
    function begin(uint256 slots) external {
        require(startTime == 0);
        require(msg.sender == creator);
        amountNft = slots;
        reservationsAvailable = slots;
        factory.updateSlotCount(MAPoolNonce, slots, amountNftsLinked);
        startTime = block.timestamp;
        factory.emitPoolBegun();
    }

    /* ======== TRADING ======== */
    /// @notice Purchase an LP position in a spot pool
    /// @dev Each position that is held by a user is tagged by a nonce which allows each 
    /// position to hold the property of a pseudo non-fungible token (psuedo because it 
    /// doesn't directly follow the common ERC721 token standard). This position is tradeable
    /// post-purchase via the 'transferFrom' function. 
    /// - The '_caller' address of a purchase receives a 1% referral fee. If this is the buyer,
    /// they incur no fee as the extra 1% is accredited to them. 
    /// @param _caller Function caller
    /// @param _buyer The position buyer
    /// @param tickets Array of tickets that the buyer would like to add in their position
    /// @param amountPerTicket Array of amount of tokens that the buyer would like to purchase
    /// from each ticket
    /// @param startEpoch Starting LP epoch
    /// @param finalEpoch The first epoch during which the LP position unlocks
    function purchase(
        address _caller,
        address _buyer, 
        uint256[] memory tickets, 
        uint256[] memory amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch
    ) external payable nonReentrant {
        require(startTime != 0);
        require(!poolClosed);
        require(tickets.length == amountPerTicket.length);
        require(tickets.length <= 10);
        require(startEpoch <= (block.timestamp - startTime) / 1 days + 1);
        require(startEpoch >= (block.timestamp - startTime) / 1 days);
        require(finalEpoch - startEpoch <= 10);

        uint256 totalTokensRequested;
        uint256 _lockTime = 
            finalEpoch * 1 days + startTime - 
                ((block.timestamp > startEpoch * 1 days + startTime) ? 
                            block.timestamp : (startEpoch * 1 days + startTime));
        uint256 _nonce = positionNonce[_buyer];
        positionNonce[_buyer]++;
        Buyer storage trader = traderProfile[_buyer][_nonce];
        adjustmentsMade[_buyer][_nonce] = adjustmentsRequired;
        trader.startEpoch = uint32(startEpoch);
        trader.unlockEpoch = uint32(finalEpoch);
        trader.multiplier = uint32(_lockTime / 1 days);

        (trader.comListOfTickets, trader.comAmountPerTicket) = bitShift(
            tickets,
            amountPerTicket
        );

        require(_lockTime >= 12 hours);
        noncesToClosePerEpoch[_buyer][finalEpoch].push(_nonce);
        for(uint256 i=0; i<tickets.length; i++) {
            uint256 ticketAmount = amountPerTicket[i];
            require(ticketAmount <= 300000);
            uint256 baseCost = ticketAmount * 0.001 ether;
            totalTokensRequested += ticketAmount;
            uint256 ticketId = tickets[i];
            require(ticketId <= 2**24-1);
            for(uint256 j = startEpoch; j < finalEpoch; j++) {
                require(ticketAmount >= amountNft);
                require(ticketsPurchased[j][ticketId] + ticketAmount <= amountNft * 1000);
                ticketsPurchased[j][ticketId] += ticketAmount;
                payoutPerRes[j] += baseCost / amountNft;
                totAvailFunds[j] += baseCost;
                if(ticketId > maxTicketPerEpoch[j]) maxTicketPerEpoch[j] = ticketId;
            }
        }

        executePayments(_caller, _buyer, _nonce, msg.value, totalTokensRequested);
        factory.emitPurchase(
            _buyer,
            tickets,
            amountPerTicket,
            _nonce,
            startEpoch,
            finalEpoch
        );
    }

    /// @notice Close an LP position and receive credits earned
    /// @dev Users ticket balances are counted on a risk adjusted basis in comparison to the
    /// maximum purchased ticket tranche. The lowest discounted EDC payout is 75% and the 
    /// highest premium is 125% for the highest ticket holders. This rate effects the portion of
    /// EDC that a user receives per EDC emitted from a pool each epoch. Furthermore, upon unlock
    /// any concentrated or general bribes during the users LP time is distributed on a risk
    /// adjusted basis. Revenues from an EDC sale are distributed among allocators.
    /// @param _user Address of the LP
    /// @param _nonce Held nonce to close 
    /// @param _payoutRatio Ratio of mined EDC that the user would like to purchase 
    function sell(
        address _user,
        uint256 _nonce,
        uint256 _payoutRatio
    ) external nonReentrant {
        require(startTime != 0);
        Buyer storage trader = traderProfile[_user][_nonce];
        require(adjustmentsMade[_user][_nonce] == adjustmentsRequired);
        require(trader.unlockEpoch != 0);
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        uint256 bribePayout;
        uint256 finalCreditCount;
        uint256 finalEpoch;
        require(
            poolEpoch >= trader.unlockEpoch 
            || poolClosed
        );
        finalEpoch = 
            poolClosed ? 
                (poolClosureEpoch > trader.unlockEpoch ? 
                    trader.unlockEpoch : poolClosureEpoch) 
                        : trader.unlockEpoch;
        for(uint256 j = trader.startEpoch; j < finalEpoch; j++) {
            uint256 amount;
            uint256 _comListOfTickets = trader.comListOfTickets;
            uint256 _comAmounts = trader.comAmountPerTicket;
            uint256 rewardCap;
            if(totAvailFunds[j] < 100e18) {
                rewardCap = totAvailFunds[j];
            } else {
                rewardCap = 100e18;
            }
            while(_comAmounts > 0) {
                uint256 ticket = _comListOfTickets & (2**25 - 1);
                uint256 amountTokens = (_comAmounts & (2**25 - 1)) / 100;
                _comListOfTickets >>= 25;
                _comAmounts >>= 25;
                
                if(maxTicketPerEpoch[j] == 0) maxTicketPerEpoch[j] = 1;
                uint256 adjustment = totAvailFunds[j] / 10e18;
                if(adjustment > 50) {
                    adjustment = 50;
                }
                amount += 
                    ((75e18 - adjustment * 1e18) + ((1e18 * ticket) ** 2) 
                        * (100e18 + adjustment * 1e18 * 4) 
                            / ((maxTicketPerEpoch[j] * 1e18) ** 2) / 2) 
                                * (amountTokens * 0.001 ether) / 100e18;
                bribePayout += 
                    amountTokens * concentratedBribe[j][ticket] 
                    / ticketsPurchased[j][ticket];
            }
            finalCreditCount += amount * rewardCap
                * (emissionStartedCount[j] > amountNft ? amountNft : emissionStartedCount[j])
                    * (
                        (reservations[j] > 0 && totalReservationValue[j] > 2e17) ? 
                            (5 * totalReservationValue[j] / 1e18) : 1
                    ) / totAvailFunds[j];
            bribePayout += trader.ethLocked * generalBribe[j] / totAvailFunds[j];
        }

        factory.emitSaleComplete(
            _user,
            _nonce,
            trader.comListOfTickets,
            _payoutRatio * finalCreditCount / 1_000
        );

        unlock(_user, _nonce, bribePayout, finalCreditCount, _payoutRatio);
    }

    /// @notice Offer a bribe to all LPs during a set of epochs
    /// @param bribePerEpoch Bribe size during each desired epoch
    /// @param startEpoch First epoch where bribes will be distributed
    /// @param endEpoch Epoch in which bribe distribution from this general
    /// bribe concludes
    function offerGeneralBribe(
        uint256 bribePerEpoch, 
        uint256 startEpoch, 
        uint256 endEpoch
    ) external payable nonReentrant {
        require(startTime != 0);
        uint256 cost;
        for(uint256 i = startEpoch; i < endEpoch; i++) {
            generalBribe[i] += bribePerEpoch;
            generalBribeOffered[msg.sender][i] += bribePerEpoch;
            cost += bribePerEpoch;
        }

        factory.emitGeneralBribe(
            msg.sender,
            bribePerEpoch,
            startEpoch,
            endEpoch
        );
        require(msg.value == cost);
    }

    /// @notice Offer a concentrated bribe
    /// @dev Concentrated bribes are offered to specific tranches during specific epochs 
    /// @param startEpoch First epoch where bribes will be distributed
    /// @param endEpoch Epoch in which bribe distribution from this general
    /// @param tickets Tranches for bribe to be applied
    /// @param bribePerTicket Size of the bribe offered to each tranche LP
    function offerConcentratedBribe(
        uint256 startEpoch,
        uint256 endEpoch,
        uint256[] memory tickets,
        uint256[] memory bribePerTicket
    ) external payable nonReentrant {
        require(startTime != 0);
        uint256 cost;
        uint256 length = tickets.length;
        require(length == bribePerTicket.length);
        for(uint256 i = startEpoch; i < endEpoch; i++) {
            for(uint256 j = 0; j < length; j++) {
                concentratedBribe[i][tickets[j]] += bribePerTicket[j];
                concentratedBribeOffered[msg.sender][i][tickets[j]] += bribePerTicket[j];
                cost += bribePerTicket[j];
            }
        }

        factory.emitConcentratedBribe(
            msg.sender,
            tickets,
            bribePerTicket,
            startEpoch,
            endEpoch
        );
        require(msg.value == cost);
    }

    /// @notice Reclaim unused general bribes offered
    /// @param epoch Epoch in which bribe went unused
    function reclaimGeneralBribe(uint256 epoch) external nonReentrant {
        require(startTime != 0);
        require(totAvailFunds[epoch] == 0);
        uint256 payout = generalBribeOffered[msg.sender][epoch];
        delete generalBribeOffered[msg.sender][epoch];
        payable(msg.sender).transfer(payout);
    }

    /// @notice Reclaim unused concentrated bribes offered
    /// @param epoch Epoch in which bribe went unused
    /// @param ticket Ticket in which bribe went unused
    function reclaimConcentratedBribe(uint256 epoch, uint256 ticket) external nonReentrant {
        require(startTime != 0);
        require(ticketsPurchased[epoch][ticket] == 0);
        uint256 payout = concentratedBribeOffered[msg.sender][epoch][ticket];
        delete concentratedBribeOffered[msg.sender][epoch][ticket];
        payable(msg.sender).transfer(payout);
    }

    /// @notice Revoke an NFTs connection to a pool
    /// @param _nft List of NFTs to be removed
    /// @param _id List of token ID of the NFT to be removed
    function remove(address[] memory _nft, uint256[] memory _id) external nonReentrant {
        require(startTime != 0);
        uint256 length = _nft.length;
        for(uint256 i = 0; i < length; i++) {
            address nft = _nft[i];
            uint256 id = _id[i];
            require(msg.sender == IERC721(nft).ownerOf(id));
            require(controller.nftVaultSignedAddress(nft, id) == address(this));
            require(!reservationMade[(block.timestamp - startTime) / 1 days][nft][id]);
            uint256 tempStorage;
            tempStorage |= uint160(nft);
            tempStorage <<= 160;
            tempStorage |= id;
            tokenMapping[tempStorage] = false;
            factory.updateNftInUse(nft, id, MAPoolNonce);
        }
    }

    /// @notice Update the 'totAvailFunds' count upon the conclusion of an auction
    /// @dev Called automagically by the closure contract 
    /// @param _nft NFT that was auctioned off
    /// @param _id Token ID of the NFT that was auctioned off
    /// @param _saleValue Auction sale value
    function updateSaleValue(
        address _nft,
        uint256 _id,
        uint256 _saleValue
    ) external payable nonReentrant {
        require(msg.sender == closePoolContract);
        auctionSaleValue[_nft][_id] = _saleValue;
    }

    /// @notice Reset the value of 'payoutPerRes' size and the total allowed reservations
    /// @dev This rebalances the payout per reservation value dependent on the total 
    /// available funds count. 
    function restore() external nonReentrant returns(bool) {
        require(startTime != 0);
        uint256 startingEpoch = (block.timestamp - startTime) / 1 days;
        require(!poolClosed);
        require(reservations[startingEpoch] == 0);
        require(reservationsAvailable < amountNft);
        require(IClosure(closePoolContract).getLiveAuctionCount() == 0);

        reservationsAvailable = amountNft;
        while(totAvailFunds[startingEpoch] > 0) {
            payoutPerRes[startingEpoch] = totAvailFunds[startingEpoch] / amountNft;
            startingEpoch++;
        }

        factory.emitPoolRestored(
            payoutPerRes[(block.timestamp - startTime) / 1 days]
        );
        return true;
    }

    /// @notice Reserve the ability to close an NFT during an epoch 
    /// @dev Example: Alice and Bob create a 1 slot pool together with 2 Punks. Alice wants to
    /// borrow against the NFT in the upcoming epoch so she reserves the right to close the pool via 
    /// 'reserve'. If Bob wants to close the NFT he has to wait until he can reserve the closure space.
    /// The cost to reserve also increases by 25% based on the amount of reservations that have been
    /// made during the epoch of interest. So if the pool was created with 2 slots and Alice already
    /// reserved a space, Bob would have to pay 125% of what Alice paid to take the second reservation
    /// slot. 
    /// @param _nft NFT that is being reserved
    /// @param id Token ID of the NFT that is being reserved
    /// @param endEpoch The epoch during which the reservation wears off
    function reserve(address _nft, uint256 id, uint256 endEpoch) external payable nonReentrant {
        require(startTime != 0);
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        require(!poolClosed);
        require(msg.sender == IERC721(_nft).ownerOf(id));
        require(controller.nftVaultSignedAddress(_nft, id) == address(this));
        require(reservations[poolEpoch] + 1 <= reservationsAvailable);
        require(endEpoch - poolEpoch <= 20);
        require(
            msg.value == (100_000 + reservations[poolEpoch] * 50_000 / amountNft) 
                * (endEpoch - poolEpoch) * payoutPerRes[poolEpoch] / 100_000_000
        );
        alloc.receiveFees{ 
            value:(100 + reservations[poolEpoch] * 25) 
                * (endEpoch - poolEpoch) / 5 * payoutPerRes[poolEpoch] / 100_000
        }();
        for(uint256 i = poolEpoch; i < endEpoch; i++) {
            require(!reservationMade[i][_nft][id]); 
            totalReservationValue[i] += payoutPerRes[i];
            reservationMade[i][_nft][id] = true;
            reservations[i]++;
        }

        factory.emitSpotReserved(
            id,
            poolEpoch,
            endEpoch
        );
    }

    /* ======== POSITION TRANSFER ======== */
    /// @notice Allow another user permission to execute a single 'transferFrom' call
    /// @param recipient Allowee address
    /// @param nonce Nonce of allowance 
    function grantTransferPermission(
        address recipient,
        uint256 nonce
    ) external nonReentrant returns(bool) {
        require(startTime != 0);
        allowanceTracker[msg.sender][recipient][nonce] = true;

        factory.emitPositionAllowance(
            msg.sender, 
            recipient
        );
        return true;
    }

    /// @notice Transfer a position or portion of a position from one user to another
    /// @dev A user can transfer an amount of tokens in each tranche from their held position at
    /// 'nonce' to another users new position (upon transfer a new position (with a new nonce)
    /// is created for the 'to' address). 
    /// @param from Sender 
    /// @param to Recipient
    /// @param nonce Nonce of position that transfer is being applied
    /// @param _listOfTickets List of tickets to be transferred
    /// @param _amountPerTicket Amount of tokens for each designated ticket
    function transferFrom(
        address from,
        address to,
        uint256 nonce,
        uint256[] memory _listOfTickets,
        uint256[] memory _amountPerTicket
    ) external nonReentrant returns(bool) {
        require(startTime != 0);
        require(
            allowanceTracker[from][msg.sender][nonce] 
            || msg.sender == from
        );
        require(adjustmentsMade[from][nonce] == adjustmentsRequired);
        Buyer storage traderFrom = traderProfile[from][nonce];
        uint256 totalTransferRequested;
        uint256 _tempComTickets;
        uint256 _tempComAmounts;
        uint256 _comTickets = traderFrom.comListOfTickets;
        uint256 _comAmounts = traderFrom.comAmountPerTicket;
        uint256 i;
        uint256 tracker = 1;
        while(tracker > 0) {
            tracker = _comAmounts;
            uint256 ticket = _comTickets & (2**25 - 1);
            uint256 amountTokens = _comAmounts & (2**25 - 1);
            _comTickets >>= 25;
            _comAmounts >>= 25;

            if(tracker != 0) {
                require(_listOfTickets[i] == ticket);

                amountTokens -= _amountPerTicket[i] * 100;
                _tempComTickets <<= 25;
                _tempComAmounts <<= 25;
                _tempComTickets |= (ticket & (2**25 - 1));
                _tempComAmounts |= (amountTokens & (2**25 - 1));
            }
            i++;
        }

        traderFrom.comListOfTickets = _tempComTickets;
        traderFrom.comAmountPerTicket = _tempComAmounts;
        traderFrom.ethLocked -= totalTransferRequested * 0.001 ether / 100;

        createNewPosition(
            from,
            to,
            totalTransferRequested * 0.001 ether / 1e18,
            _listOfTickets,
            _amountPerTicket
        );

        return true;
    }

    /* ======== POOL CLOSURE ======== */
    /// @notice Close an NFT in exchange for the 'payoutPerRes' of the current epoch
    /// @dev This closure triggers a 48 hour auction to begin in which the closed NFT will be sold
    /// and can only be called by the holder of the NFT. Upon calling this function the caller will
    /// be sent the 'payoutPerRes' and the NFT will be taken. (If this is the first function call)
    /// it will create a close pool contract that the rest of the closure will use as well.
    /// @param _nft NFT that is being closed
    /// @param _id Token ID of the NFT that is being closed
    function closeNft(address _nft, uint256 _id) external nonReentrant2 {
        require(startTime != 0);
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        require(reservationMade[poolEpoch][_nft][_id]);
        require(!poolClosed);
        require(epochOfClosure[_nft][_id] == 0);
        adjustmentsRequired++;

        uint256 tempStorage;
        tempStorage |= uint160(_nft);
        tempStorage <<= 160;
        tempStorage |= _id;
        tokenMapping[tempStorage] = false;
        reservationsAvailable--;

        uint256 i = poolEpoch;
        while(reservationMade[i][_nft][_id]) {
            reservationMade[i][_nft][_id] = false;
            reservations[i]--;
            i++;
        }

        i = poolEpoch;
        uint256 ppr = payoutPerRes[i];
        uint256 propTrack = totAvailFunds[i];
        while(totAvailFunds[i] > 0) {
            totAvailFunds[i] -= ppr * propTrack / totAvailFunds[i];
            i++;
        }

        if(closePoolContract == address(0)) {
            IClosure closePoolMultiDeployment = 
                IClosure(Clones.clone(_closePoolMultiImplementation));
            closePoolMultiDeployment.initialize(
                address(this),
                address(controller),
                vaultVersion
            );

            controller.addAccreditedAddressesMulti(address(closePoolMultiDeployment));
            closePoolContract = address(closePoolMultiDeployment);
        }

        IClosure(closePoolContract).startAuction(payoutPerRes[poolEpoch], _nft, _id);
        IERC721(_nft).transferFrom(msg.sender, address(closePoolContract), _id);

        epochOfClosure[_nft][_id] = poolEpoch;
        alloc.receiveFees{value:3 * payoutPerRes[poolEpoch] / 100 }();
        payable(msg.sender).transfer(97 * payoutPerRes[poolEpoch] / 100);
        factory.emitNftClosed(
            msg.sender,
            _nft,
            _id,
            payoutPerRes[poolEpoch],
            address(closePoolContract)
        );
    }

    /// @notice Close the pool
    /// @dev This can only be called from the factory once majority of holders
    /// sign off on the overall closure of this pool.
    function closePool() external nonReentrant {
        require(msg.sender == address(factory));
        poolClosureEpoch = (block.timestamp - startTime) / 1 days;
        poolClosed = true;
    }

    /* ======== ACCOUNT CLOSURE ======== */
    /// @notice Adjust a users LP information after an NFT is closed
    /// @dev This function is called by the calculate principal function in the closure contract
    /// @param _user Address of the LP owner
    /// @param _nonce Nonce of the LP
    /// @param _nft Address of the auctioned NFT
    /// @param _id Token ID of the auctioned NFT
    function adjustTicketInfo(
        address _user,
        uint256 _nonce,
        address _nft,
        uint256 _id
    ) external nonReentrant returns(bool) {
        require(startTime != 0);
        require(!adjustCompleted[_user][_nft][_id]);
        require(adjustmentsMade[_user][_nonce] < adjustmentsRequired);
        require(
            block.timestamp > IClosure(closePoolContract).getAuctionEndTime(_nft, _id)
        );

        Buyer storage trader = traderProfile[_user][_nonce];
        uint256 _epochOfClosure = epochOfClosure[_nft][_id];
        uint256 _comTickets = trader.comListOfTickets;
        uint256 _comAmounts = trader.comAmountPerTicket;
        adjustmentsMade[_user][_nonce]++;

        if(
            trader.unlockEpoch < _epochOfClosure
            || trader.startEpoch > _epochOfClosure
        ) {
            return true;
        }

        uint256 appLoss = internalAdjustment(
            _user,
            _nonce,
            payoutPerRes[_epochOfClosure],
            auctionSaleValue[_nft][_id],
            _comTickets,
            _comAmounts
        );

        if(payoutPerRes[_epochOfClosure] > auctionSaleValue[_nft][_id]) {
            if(loss[_nft][_id] > payoutPerRes[_epochOfClosure] - auctionSaleValue[_nft][_id]) {
                alloc.receiveFees{value:appLoss}();
            } else if(loss[_nft][_id] + appLoss > payoutPerRes[_epochOfClosure] - auctionSaleValue[_nft][_id]) {
                alloc.receiveFees{
                    value:loss[_nft][_id] + appLoss - (payoutPerRes[_epochOfClosure] - auctionSaleValue[_nft][_id])
                }();
            }
        }
        loss[_nft][_id] += appLoss;
        factory.emitPrincipalCalculated(
            address(this),
            _nft,
            _id,
            _user,
            _nonce
        );

        adjustCompleted[_user][_nft][_id] = true;
        return true;
    }

    /* ======== INTERNAL ======== */
    function bitShift(
        uint256[] memory tickets, 
        uint256[] memory amountPerTicket
    ) internal pure returns(uint256 comTickets, uint256 comAmounts) {
        uint256 length = tickets.length;
        for(uint256 i = 0; i < length; i++) {
            comTickets <<= 25;
            comAmounts <<= 25;
            comTickets |= tickets[i];
            comAmounts |= amountPerTicket[i] * 100;
        }
    }

    function executePayments(
        address _caller, 
        address _buyer, 
        uint256 _nonce, 
        uint256 paymentSize, 
        uint256 totalTokensRequested
    ) internal {
        Buyer storage trader = traderProfile[_buyer][_nonce];
        uint256 base = totalTokensRequested * 0.001 ether;
        uint256 cost = (_caller == _buyer ? 10_000 : 10_100) * base / 10_000;
        require(paymentSize + ICreditBonds(controller.creditBonds()).sendToVault(
            _caller,
            address(this),
            _buyer,
            cost
            ) == cost
        );
        
        if(_caller != _buyer) {
            factory.updatePendingReturns{ 
                value:100 * (base) / 10_000
            } ( _caller );
        }
        trader.ethLocked += base;
    }

    function unlock(
        address _user,
        uint256 _nonce,
        uint256 _bribeReward,
        uint256 _finalCreditCount,
        uint256 _payoutRatio
    ) internal {
        if(
            !epochVault.getBaseAdjustmentStatus()
            && epochVault.getCurrentEpoch() != 0
        ) epochVault.adjustBase();
        Buyer storage trader = traderProfile[_user][_nonce];
        uint256 basePercentage = epochVault.getBasePercentage();
        uint256 amountCreditsDesired = 
            _payoutRatio * _finalCreditCount / 1_000;
        uint256 cost = 
            _payoutRatio * trader.ethLocked / 1_000
                * basePercentage / 10_000;
        alloc.receiveFees{value: (cost)}();
        payable(_user).transfer(trader.ethLocked + _bribeReward - cost);
        epochVault.updateEpoch(boostCollection, _user, amountCreditsDesired * trader.multiplier);
        delete traderProfile[_user][_nonce];
    }

    function internalAdjustment(
        address _user,
        uint256 _nonce,
        uint256 _payout,
        uint256 _finalNftVal,
        uint256 _comTickets,
        uint256 _comAmounts
    ) internal returns(uint256 appLoss) {
        Buyer storage trader = traderProfile[_user][_nonce];
        uint256 _tempComTickets;
        uint256 _tempComAmounts;
        uint256 ethRemoval;
        uint256 payout;
        uint256 tPrem;
        uint256 premium = _finalNftVal > _payout ? _finalNftVal - _payout : 0;
        while(_comAmounts > 0) {
            uint256 ticket = _comTickets & (2**25 - 1);
            uint256 amountTokens = _comAmounts & (2**25 - 1);
            tPrem += amountTokens * 0.001 ether / amountNft * premium / _payout;
            _comTickets >>= 25;
            _comAmounts >>= 25;
            _tempComTickets <<= 25;
            _tempComAmounts <<= 25;
            _tempComTickets |= ticket;
            if(ticket * 1e18 + 1e18 <= _finalNftVal) {
                payout += amountTokens * 0.001 ether / amountNft / 100;
                _tempComAmounts |= amountTokens;
            } else if(ticket * 1e18 > _finalNftVal) {
                appLoss += amountTokens * 0.001 ether / amountNft / 100;
                _tempComAmounts |= amountTokens - amountTokens / amountNft;
            } else if(ticket * 1e18 + 1e18 > _finalNftVal) {
                payout += 
                    (
                        amountTokens - amountTokens * (ticket * 1e18 + 1e18 - _finalNftVal) / 1e18
                    ) * 0.001 ether / amountNft / 100;
                appLoss += amountTokens * (ticket * 1e18 + 1e18 - _finalNftVal)
                        / amountNft / 1e18 * 0.001 ether / 100;
                _tempComAmounts |= amountTokens - amountTokens * (ticket * 1e18 + 1e18 - _finalNftVal) / amountNft / 1e18;
            }

            ethRemoval += amountTokens * 0.001 ether / amountNft;
        }

        trader.ethLocked -= ethRemoval / 100;
        payable(_user).transfer(payout + payout * tPrem / (payout + appLoss));
        appLoss += appLoss * tPrem / (payout + appLoss);
        trader.comListOfTickets = _tempComTickets;
        trader.comAmountPerTicket = _tempComAmounts;
    }

    function createNewPosition(
        address from,
        address to, 
        uint256 ethValTransfer, 
        uint256[] memory listOfTickets,
        uint256[] memory amountPerTicket
    ) internal {
        Buyer storage traderTo = traderProfile[to][positionNonce[to]];
        adjustmentsMade[to][positionNonce[to]] = adjustmentsRequired;
        traderTo.ethLocked = ethValTransfer;
        uint256 comTickets;
        uint256 comAmounts;
        for(uint256 i = 0; i < listOfTickets.length; i++) {
            comTickets <<= 25;
            comAmounts <<= 25;
            comTickets |= (listOfTickets[i] & (2**25 - 1));
            comAmounts |= (amountPerTicket[i] & (2**25 - 1));
        }
        traderTo.comListOfTickets = comTickets;
        traderTo.comAmountPerTicket = comAmounts;
        positionNonce[to]++;

        factory.emitLPTransfer(
            from, 
            to, 
            listOfTickets, 
            amountPerTicket
        );
    }

    /* ======== GETTER ======== */
    /// @notice Check if the pool is closed
    function getPoolClosedStatus() external view returns(bool) {
        return poolClosed;
    }

    /// @notice Get the pool epoch at a specific time
    /// @param _time Time of interest
    function getEpoch(uint256 _time) external view returns(uint256) {
        return (_time - startTime) / 1 days; 
    }

    /// @notice Get multi asset pool reference nonce
    function getNonce() external view returns(uint256) {
        return MAPoolNonce;
    }

    /// @notice Get the list of NFT address and corresponding token IDs in by this pool
    function getHeldTokenExistence(address _nft, uint256 _id) external view returns(bool) {
        uint256 temp; 
        temp |= _id;
        temp <<= 160;
        temp |= uint160(_nft);
        return tokenMapping[temp];
    }

    /// @notice Get the total amount of reservations made during an epoch
    /// @param _epoch Epoch of interest
    function getAmountOfReservations(
        uint256 _epoch
    ) external view returns(uint256 amountOfReservations) {
        amountOfReservations = reservations[_epoch];
    }

    /// @notice Get the reservation status of an NFT during an epoch
    /// @param nft Address of NFT of interest
    /// @param id Token ID of NFT of interest
    /// @param epoch Epoch of interest
    function getReservationStatus(
        address nft, 
        uint256 id, 
        uint256 epoch
    ) external view returns(bool) {
        return reservationMade[epoch][nft][id];
    }

    /// @notice Get the cost to reserve an NFT for an amount of epochs
    /// @dev This takes into account the reservation amount premiums
    /// @param _endEpoch The epoch after the final reservation epoch
    function getCostToReserve(uint256 _endEpoch) external view returns(uint256) {
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        return (100_000 + reservations[poolEpoch] * 50_000 / amountNft) 
                * (_endEpoch - poolEpoch) * payoutPerRes[poolEpoch] / 100_000_000;
    }

    /// @notice Get total funds available in an epoch
    function getTotalFunds(uint256 epoch) external view returns(uint256) {
        return totAvailFunds[epoch];
    }

    /// @notice Get size of the payout during an epoch
    /// @param epoch Epoch of interest
    function getPayoutPerRes(uint256 epoch) external view returns(uint256) {
        return payoutPerRes[epoch];
    }

    /// @notice Get a decoded version of an LP position
    /// @dev This getter decodes the bit shifts used to compress a list of tickets. The two
    /// lists are returned in reverse order of the original list.
    /// @param _user LP of interest
    /// @param _nonce Nonce tag of LP position of interest
    function getDecodedLPInfo(
        address _user, 
        uint256 _nonce
    ) external view returns(
        uint256 multiplier,
        uint256 unlockEpoch,
        uint256 startEpoch,
        uint256[10] memory tickets, 
        uint256[10] memory amounts
    ) {
        Buyer storage trader = traderProfile[_user][_nonce];
        uint256 i;
        uint256 _comListOfTickets = trader.comListOfTickets;
        uint256 _comAmounts = trader.comAmountPerTicket;
        uint256 tracker = 1;
        while(tracker > 0) {
            tracker = _comAmounts;
            uint256 ticket = _comListOfTickets & (2**25 - 1);
            uint256 amountTokens = _comAmounts & (2**25 - 1);
            _comListOfTickets >>= 25;
            _comAmounts >>= 25;

            if(tracker != 0) {
                tickets[i] = ticket;
                amounts[i] = amountTokens;
            }
            i++;
        }
        multiplier = trader.multiplier;
        startEpoch = trader.startEpoch;
        unlockEpoch = trader.unlockEpoch;
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}