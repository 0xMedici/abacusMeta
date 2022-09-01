//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ABCToken } from "./AbcToken.sol";
import { AbacusController } from "./AbacusController.sol";
import { IClosure } from "./interfaces/IClosure.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { IAllocator } from "./interfaces/IAllocator.sol";
import { ICreditBonds } from "./interfaces/ICreditBond.sol";
import { BitShift } from "./helpers/BitShift.sol";
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
    address creator;

    /// @notice Address of the deployed closure contract
    address public closePoolContract;

    /// @notice Address of the chosen boost collection
    address public boostCollection;

    address private _closePoolMultiImplementation;

    /* ======== UINT ======== */
    uint256 public ticketLimit;

    uint256 amountNftsLinked;

    uint256 poolClosureEpoch;

    uint256 MAPoolNonce;

    /// @notice The amount of available NFT closures
    uint256 public reservationsAvailable;

    /// @notice Total amount of slots to be collateralized
    uint256 public amountNft;

    /// @notice Pool creation time
    uint256 public startTime;

    uint8 vaultVersion;

    /// @notice Total amount of adjustments required (every time an NFT is 
    /// closed this value increments)
    uint256 public adjustmentsRequired;

    /* ======== BOOLEANS ======== */
    /// @notice Status of pool closure
    bool public poolClosed;

    bool public nonWhitelistPool;

    /* ======== MAPPINGS ======== */
    /// @notice The amount of NFTs from a collection that has signed the pool
    /// [uint256] -> Epoch
    /// [address] -> NFT collection
    /// [uint256] -> Amount NFTs signed
    mapping(uint256 => mapping(address => uint256)) collectionsSigned;

    /// @notice The current nonce tag connected to the amount of times a specific NFT has been closed
    /// [address] -> NFT collection
    /// [uint256] -> NFT token ID
    /// [uint256] -> Nonce tag for closure number
    mapping(address => mapping(uint256 => uint256)) closureNonce;

    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) adjustmentNonce;

    /// @notice Tracks whether an NFT has started emissions during an epoch
    /// [address] -> NFT collection
    /// [uint256] -> NFT token ID
    /// [uint256] -> Epoch
    /// [bool] -> Status of if the NFT started emissions during that epoch 
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) public emissionsStarted;

    /// @notice The total amount of times emissions has been toggled during an epoch
    /// [uint256] -> Epoch
    /// [uint256] -> Amount of times toggled
    mapping(uint256 => uint256) public emissionStartedCount;

    mapping(uint256 => bool) tokenMapping;

    mapping(uint256 => uint256) totalTokensPurchased;

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) loss;

    /// @notice Track adjustment status of closed NFTs
    /// [address] -> User 
    /// [uint256] -> nonce
    /// [address] -> NFT collection
    /// [uint256] -> NFT ID
    /// [bool] -> Status of adjustment
    mapping(address => mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => bool))))) public adjustCompleted;

    mapping(address => uint256) public positionNonce;

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) epochOfClosure;

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

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) auctionSaleValue;

    /// @notice Amount of tokens purchased within a ticket
    /// [uint256] -> epoch
    /// [uint256] -> ticket
    /// [uint256] -> tokens purchased
    mapping(uint256 => uint256[]) ticketsPurchased;

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

    mapping(address => mapping(uint256 => uint256)) generalBribeOffered;

    /// @notice Track concentrated bribes offered to specific tickets during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> ticket
    /// [uint256] -> bribe amount
    mapping(uint256 => mapping(uint256 => uint256)) public concentratedBribe;

    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) concentratedBribeOffered;

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
        adjustmentsRequired = 1;
    }

    /* ======== USER ADJUSTMENTS ======== */
    /// @notice Turn the emissions on and off
    /// @dev Only callable by the factory contract
    /// @param _nft Address of NFT collection
    /// @param _id ID of NFT
    /// @param emissionStatus The state new state of 'emissionsStarted' 
    function toggleEmissions(address _nft, uint256 _id, bool emissionStatus) external nonReentrant {
        require(!poolClosed);
        uint256 poolEpoch;
        if(startTime == 0) {
            poolEpoch = 0;
        } else {
            poolEpoch = (block.timestamp - startTime) / 1 days;
        }
        if(!emissionStatus) {
            require(
                msg.sender == address(factory)
                || msg.sender == address(this)    
            );
        } else {
            require(
                msg.sender == address(factory)
                || IERC721(_nft).ownerOf(_id) == msg.sender
                || controller.registry(IERC721(_nft).ownerOf(_id)) == msg.sender
                || msg.sender == address(this)
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
            collectionsSigned[poolEpoch][_nft]++;
            emissionsStarted[_nft][_id][poolEpoch] = true;
            emissionStartedCount[poolEpoch]++;
        } else if(emissionsStarted[_nft][_id][poolEpoch]) {
            collectionsSigned[poolEpoch][_nft]--;
            emissionsStarted[_nft][_id][poolEpoch] = false;
            emissionStartedCount[poolEpoch]--;
            if(collectionsSigned[poolEpoch][_nft] == 0 && _nft == boostCollection) {
                delete boostCollection;
            } 
        }

        factory.emitToggle(_nft, _id, emissionStatus, emissionStartedCount[poolEpoch]);
    }

    /* ======== CONFIGURATION ======== */
    /// @notice [setup phase] Give an NFT access to the pool 
    /// @param _compTokenInfo Compressed list of NFT collection address and token ID information
    function includeNft(uint256[] calldata _compTokenInfo) external {
        require(startTime == 0);
        require(msg.sender == creator);
        uint256 length = _compTokenInfo.length;
        for(uint256 i = 0; i < length; i++) {
            uint256 id = _compTokenInfo[i] & (2**95-1);
            uint256 temp = _compTokenInfo[i] >> 95;
            address collection = address(uint160(temp & (2**160-1)));
            if(!controller.collectionWhitelist(collection)) {
                nonWhitelistPool = true;
            }
            require(IERC721(collection).ownerOf(id) != address(0));
            tokenMapping[_compTokenInfo[i]] = true;
        }

        amountNftsLinked += length;
        factory.emitNftInclusion(_compTokenInfo);
    }

    /// @notice [setup phase] Start the pools operation
    /// @param slots The amount of collateral slots the pool will offer
    function begin(uint256 slots, uint256 _ticketSize) external {
        require(startTime == 0);
        require(msg.sender == creator);
        amountNft = slots;
        ticketLimit = _ticketSize;
        reservationsAvailable = slots;
        factory.updateSlotCount(MAPoolNonce, slots, amountNftsLinked);
        startTime = block.timestamp;
        factory.emitPoolBegun(_ticketSize);
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
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch
    ) external payable nonReentrant {
        require(startTime != 0);
        require(!poolClosed);
        require(tickets.length == amountPerTicket.length);
        require(tickets.length <= 100);
        require(startEpoch <= (block.timestamp - startTime) / 1 days + 1);
        require(startEpoch >= (block.timestamp - startTime) / 1 days);
        require(finalEpoch - startEpoch <= 10);
        uint256 totalTokensRequested;
        uint256 largestTicket;
        uint256 _lockTime = 
            finalEpoch * 1 days + startTime - 
                ((block.timestamp > startEpoch * 1 days + startTime) ? 
                            block.timestamp : (startEpoch * 1 days + startTime));

        for(uint256 i = 0; i < tickets.length / 10 + 1; i++) {
            if(tickets.length % 10 == 0 && i == tickets.length / 10) break;
            uint256 tempVal;
            uint256 upperBound;
            if(10 + i * 10 > tickets.length) {
                upperBound = tickets.length;
            } else {
                upperBound = 10 + i * 10;
            }
            tempVal = choppedPosition(
                _buyer,
                tickets[0 + i * 10:upperBound],
                amountPerTicket[0 + i * 10:upperBound],
                startEpoch,
                finalEpoch,
                _lockTime
            );
            if(tempVal > largestTicket) largestTicket = tempVal;
        }

        totalTokensRequested = updateProtocol(
            largestTicket,
            startEpoch,
            finalEpoch,
            tickets,
            amountPerTicket
        );

        controller.updateTotalVolumeTraversed(totalTokensRequested * 0.001 ether);
        executePayments(_caller, _buyer, msg.value, totalTokensRequested);
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
        require(msg.sender == _user);
        Buyer storage trader = traderProfile[_user][_nonce];
        require(adjustmentsMade[_user][_nonce] == adjustmentsRequired);
        require(trader.unlockEpoch != 0);
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        uint256 bribePayout;
        uint256 finalCreditCount;
        uint256 finalEpoch;
        uint256 totalAmountTokens;
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
            while(_comAmounts > 0) {
                uint256 ticket = _comListOfTickets & (2**25 - 1);
                uint256 amountTokens = (_comAmounts & (2**25 - 1)) / 100;
                totalAmountTokens += amountTokens;
                _comListOfTickets >>= 25;
                _comAmounts >>= 25;
                if(totAvailFunds[j] < 100e18) {
                    rewardCap = totAvailFunds[j];
                } else {
                    rewardCap = 100e18;
                }
                if(maxTicketPerEpoch[j] == 0) maxTicketPerEpoch[j] = 1;
                uint256 adjustment = payoutPerRes[j] / (5 * ticketLimit);
                if(adjustment > 25) {
                    adjustment = 25;
                }

                // COMMENT HERE FOR CLARITY: REPURPOSING poolEpoch
                poolEpoch = ((100e18 - adjustment * 1e18) + ((1e18 * ticket) ** 2) 
                        * ((adjustment == 0 ? 1e18 : 0) + adjustment * 1e18 * 4) 
                            / ((maxTicketPerEpoch[j] * 1e18) ** 2) / 2) < 100e18 ?
                                (
                                    1 + (1000 * amountNft * 1e18 - amountTokens) * 1 
                                        / (1000 * amountNft * 1e18)
                                ) : 1;
                amount += 
                    ((100e18 - adjustment * 1e18) + ((1e18 * ticket) ** 2) 
                        * ((adjustment == 0 ? 1e18 : 0) + adjustment * 1e18 * 4) 
                            / ((maxTicketPerEpoch[j] * 1e18) ** 2) / 2) 
                                * (amountTokens * 0.001 ether) / 100e18
                                    * poolEpoch;
                bribePayout += 
                    amountTokens * concentratedBribe[j][ticket] 
                    / this.getTicketInfo(j, ticket);
            }
            // COMMENT HERE FOR CLARITY: REPURPOSING _comAmounts
            _comAmounts = 5 * (
                factory.getSqrt(totalReservationValue[j] / 1e18) > 0 
                ? factory.getSqrt(totalReservationValue[j] / 1e18) : 1
            );

            // COMMENT HERE FOR CLARITY: REPURPOSING _comListOfTickets
            _comListOfTickets = emissionStartedCount[j] >= reservations[j] ? emissionStartedCount[j] : reservations[j];

            // COMMENT HERE FOR CLARITY: REPURPOSING _comListOfTickets
            _comListOfTickets = _comListOfTickets > 0 ? 
                (
                    _comListOfTickets > amountNft
                    ? factory.getSqrt(amountNft) : factory.getSqrt(_comListOfTickets)
                ) : 0;
            finalCreditCount += amount * rewardCap * (_comListOfTickets)
                    * (reservations[j] > 0 ? (_comAmounts == 0 ? 1 : _comAmounts) : 1) / 1e18;
            bribePayout += trader.ethLocked * generalBribe[j] / totAvailFunds[j];
        }

        factory.emitSaleComplete(
            _user,
            _nonce,
            trader.comListOfTickets,
            _payoutRatio * finalCreditCount / 1_000
        );
        unlock(
            _user, 
            _nonce, 
            bribePayout, 
            finalCreditCount * totalAmountTokens * 0.001 ether / trader.ethLocked, 
            _payoutRatio
        );
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
        uint256[] calldata tickets,
        uint256[] calldata bribePerTicket
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
    function reclaimGeneralBribe(uint256 epoch, uint256 ticket) external nonReentrant {
        require(startTime != 0);
        require(payoutPerRes[epoch] == 0);
        require(epoch > (block.timestamp - startTime) / 1 days);
        uint256 payout = generalBribeOffered[msg.sender][epoch] + concentratedBribeOffered[msg.sender][epoch][ticket];
        delete generalBribeOffered[msg.sender][epoch];
        delete concentratedBribeOffered[msg.sender][epoch][ticket];
        payable(msg.sender).transfer(payout);
    }

    /// @notice Revoke an NFTs connection to a pool
    /// @param _nft List of NFTs to be removed
    /// @param _id List of token ID of the NFT to be removed
    function remove(address[] calldata _nft, uint256[] calldata _id) external {
        require(startTime != 0);
        uint256 length = _nft.length;
        for(uint256 i = 0; i < length; i++) {
            address nft = _nft[i];
            uint256 id = _id[i];
            require(msg.sender == IERC721(nft).ownerOf(id));
            require(controller.nftVaultSignedAddress(nft, id) == address(this));
            factory.updateNftInUse(nft, id, MAPoolNonce);
            uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
            while(reservationMade[poolEpoch][nft][id]) {
                delete reservationMade[poolEpoch][nft][id];
                totalReservationValue[poolEpoch] -= payoutPerRes[poolEpoch];
                reservations[poolEpoch]--;
                poolEpoch++;
            }
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
        auctionSaleValue[closureNonce[_nft][_id]][_nft][_id] = _saleValue;
        closureNonce[_nft][_id]++;
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
            msg.value == (50_000 + reservations[poolEpoch]**2 * 100_000 / amountNft**2) 
                * (endEpoch - poolEpoch) * payoutPerRes[poolEpoch] / 250_000_000
        );
        alloc.receiveFees{value:msg.value}();
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
    function changeTransferPermission(
        address recipient,
        uint256 nonce,
        bool permission
    ) external nonReentrant returns(bool) {
        require(startTime != 0);
        allowanceTracker[msg.sender][recipient][nonce] = permission;

        factory.emitPositionAllowance(
            msg.sender, 
            recipient,
            permission
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
    function transferFrom(
        address from,
        address to,
        uint256 nonce
    ) external nonReentrant returns(bool) {
        require(startTime != 0);
        require(
            allowanceTracker[from][msg.sender][nonce] 
            || msg.sender == from
        );
        require(adjustmentsMade[from][nonce] == adjustmentsRequired);
        adjustmentsMade[to][positionNonce[to]] = adjustmentsMade[from][nonce];
        traderProfile[to][positionNonce[to]] = traderProfile[from][nonce];
        positionNonce[to]++;
        delete traderProfile[from][nonce];

        factory.emitLPTransfer(from, to, nonce);
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
        adjustmentsRequired++;
        adjustmentNonce[_nft][_id][closureNonce[_nft][_id]] = adjustmentsRequired;
        controller.updateNftUsage(address(this), _nft, _id, false);
        this.toggleEmissions(_nft, _id, false);
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
            totAvailFunds[i] -= ppr * totAvailFunds[i] / propTrack;
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

        IClosure(closePoolContract).startAuction(ppr, _nft, _id);
        IERC721(_nft).transferFrom(msg.sender, address(closePoolContract), _id);

        epochOfClosure[closureNonce[_nft][_id]][_nft][_id] = poolEpoch;
        uint256 payout = 1 * ppr / 100;
        alloc.receiveFees{value:payout }();
        payable(msg.sender).transfer(ppr - payout);
        factory.emitNftClosed(
            msg.sender,
            _nft,
            _id,
            ppr,
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
        uint256 _id,
        uint256 _closureNonce
    ) external nonReentrant returns(bool) {
        require(startTime != 0);
        require(!adjustCompleted[_user][_nonce][_closureNonce][_nft][_id]);
        require(adjustmentsMade[_user][_nonce] < adjustmentsRequired);
        require(
            block.timestamp > IClosure(closePoolContract).getAuctionEndTime(_closureNonce, _nft, _id)
        );
        Buyer storage trader = traderProfile[_user][_nonce];
        require(adjustmentsMade[_user][_nonce] == adjustmentNonce[_nft][_id][_closureNonce] - 1);
        adjustmentsMade[_user][_nonce]++;
        if(trader.unlockEpoch < epochOfClosure[_closureNonce][_nft][_id]) {
            return true;
        }

        uint256 appLoss = internalAdjustment(
            _user,
            _nonce,
            totalTokensPurchased[epochOfClosure[_closureNonce][_nft][_id]],
            payoutPerRes[epochOfClosure[_closureNonce][_nft][_id]],
            auctionSaleValue[_closureNonce][_nft][_id],
            trader.comListOfTickets,
            trader.comAmountPerTicket
        );
        lossCalculator(
            _nft,
            _id,
            _closureNonce,
            appLoss
        );
        factory.emitPrincipalCalculated(
            address(this),
            _nft,
            _id,
            _user,
            _nonce,
            _closureNonce
        );
        adjustCompleted[_user][_nonce][_closureNonce][_nft][_id] = true;
        return true;
    }

    /* ======== INTERNAL ======== */
    function choppedPosition(
        address _buyer,
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch,
        uint256 _lockTime
    ) internal returns(uint256 largestTicket) {
        uint256 _nonce = positionNonce[_buyer];
        uint256 base;
        positionNonce[_buyer]++;
        Buyer storage trader = traderProfile[_buyer][_nonce];
        adjustmentsMade[_buyer][_nonce] = adjustmentsRequired;
        trader.startEpoch = uint32(startEpoch);
        trader.unlockEpoch = uint32(finalEpoch);
        trader.multiplier = uint32(_lockTime / 1 days);
        (trader.comListOfTickets, trader.comAmountPerTicket, largestTicket, base) = BitShift.bitShift(
            tickets,
            amountPerTicket
        );
        trader.ethLocked += base;

        factory.emitPurchase(
            _buyer,
            tickets,
            amountPerTicket,
            _nonce,
            startEpoch,
            finalEpoch
        );
    }

    function updateProtocol(
        uint256 largestTicket,
        uint256 startEpoch,
        uint256 endEpoch,
        uint256[] calldata tickets, 
        uint256[] calldata ticketAmounts
    ) internal returns(uint256 totalTokens) {
        uint256 length = tickets.length;
        uint256 tracker;
        for(uint256 j = startEpoch; j < endEpoch; j++) {
            while(ticketsPurchased[j].length == 0 || ticketsPurchased[j].length - 1 < largestTicket / 15) ticketsPurchased[j].push(0);
            uint256[] memory epochTickets = ticketsPurchased[j];
            uint256 amount;
            for(uint256 i = 0; i < length; i++) {
                uint256 ticket = tickets[i];
                uint256 ticketAmount = ticketAmounts[i];
                require(ticket <= largestTicket);
                if(ticket == largestTicket) tracker = 1;
                uint256 bitAND = (2**((ticket % 15 + 1)*16) - 1) - (2**(((ticket % 15))*16) - 1);
                uint256 temp = epochTickets[ticket / 15] & bitAND;
                uint256 bitSHIFT = ticket % 15;
                temp >>= bitSHIFT * 16;
                temp += ticketAmount;
                require(temp <= amountNft * ticketLimit);
                epochTickets[ticket / 15] &= ~bitAND;
                epochTickets[ticket / 15] |= (temp << (bitSHIFT*16));
                amount += ticketAmount;
            }
            payoutPerRes[j] += amount * 0.001 ether / amountNft;
            totAvailFunds[j] += amount * 0.001 ether;
            ticketsPurchased[j] = epochTickets;
            totalTokens = amount;
            if(maxTicketPerEpoch[j] < largestTicket) maxTicketPerEpoch[j] = largestTicket;
            totalTokensPurchased[j] += amount;
        }

        require(tracker == 1);
    }

    function executePayments(
        address _caller, 
        address _buyer, 
        uint256 paymentSize, 
        uint256 totalTokensRequested
    ) internal {
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
        uint256 _totalTokenAmount,
        uint256 _payout,
        uint256 _finalNftVal,
        uint256 _comTickets,
        uint256 _comAmounts
    ) internal returns(uint256 appLoss) {
        Buyer storage trader = traderProfile[_user][_nonce];
        uint256 ethRemoval;
        uint256 payout;
        uint256 premium = _finalNftVal > _payout ? _finalNftVal - _payout : 0;
        while(_comAmounts > 0) {
            uint256 ticket = _comTickets & (2**25 - 1);
            uint256 amountTokens = _comAmounts & (2**25 - 1);
            uint256 monetaryTicketSize = 1e18 * ticketLimit / 1000;
            // tPrem += amountTokens * 0.001 ether * premium / amountNft / _payout / 100;
            _comTickets >>= 25;
            _comAmounts >>= 25;
            if(ticket * monetaryTicketSize + monetaryTicketSize <= _finalNftVal) {
                payout += amountTokens * 0.001 ether / amountNft / 100;
            } else if(ticket * monetaryTicketSize > _finalNftVal) {
                appLoss += amountTokens * 0.001 ether / amountNft / 100;
            } else if(ticket * monetaryTicketSize + monetaryTicketSize > _finalNftVal) {
                payout += 
                    (
                        amountTokens - amountTokens * 
                            (
                                ticket * monetaryTicketSize 
                                    + monetaryTicketSize - _finalNftVal
                            ) 
                                / (monetaryTicketSize)
                    ) / amountNft * 0.001 ether / 100;
                appLoss += amountTokens * 
                    (ticket * monetaryTicketSize + monetaryTicketSize - _finalNftVal) 
                        / monetaryTicketSize
                            / amountNft * 0.001 ether / 100;
            }

            ethRemoval += amountTokens * 0.001 ether / amountNft;
        }

        uint256 tPrem = (ethRemoval / 100) * premium / _payout;
        premium = (_payout * amountNft) * ethRemoval / 100 / (_totalTokenAmount * 0.001 ether);
        trader.ethLocked -= premium;
        payable(_user).transfer(premium + premium * tPrem / (payout + appLoss));
        appLoss += appLoss * tPrem / (premium + appLoss);
    }

    function lossCalculator(
        address _nft,
        uint256 _id,
        uint256 _closureNonce,
        uint256 appLoss
    ) internal {
        uint256 _epochOfClosure = epochOfClosure[_closureNonce][_nft][_id];
        uint256 _saleValue = auctionSaleValue[_closureNonce][_nft][_id];
        uint256 _loss = loss[_closureNonce][_nft][_id];
        if(payoutPerRes[_epochOfClosure] > _saleValue) {
            if(_loss > payoutPerRes[_epochOfClosure] - _saleValue) {
                alloc.receiveFees{value:appLoss}();
            } else if(_loss + appLoss > payoutPerRes[_epochOfClosure] - _saleValue) {
                alloc.receiveFees{
                    value:_loss + appLoss - (payoutPerRes[_epochOfClosure] - _saleValue)
                }();
            }
        }
        loss[_closureNonce][_nft][_id] += appLoss;
    }

    /* ======== GETTER ======== */

    /// @notice Get multi asset pool reference nonce
    function getNonce() external view returns(uint256) {
        return MAPoolNonce;
    }

    /// @notice Get the list of NFT address and corresponding token IDs in by this pool
    function getHeldTokenExistence(address _nft, uint256 _id) external view returns(bool) {
        uint256 temp; 
        temp |= uint160(_nft);
        temp <<= 95;
        temp |= _id;
        return tokenMapping[temp];
    }

    /// @notice Get the amount of spots in a ticket that have been purchased during an epoch
    function getTicketInfo(uint256 epoch, uint256 ticket) external view returns(uint256) {
        uint256[] memory epochTickets = ticketsPurchased[epoch];
        if(epochTickets.length <= ticket / 15) {
            return 0;
        }
        uint256 temp = epochTickets[ticket / 15];
        temp &= (2**((ticket % 15 + 1)*16) - 1) - (2**(((ticket % 15))*16) - 1);
        return temp >> ((ticket % 15) * 16);
    }

    /// @notice Get the cost to reserve an NFT for an amount of epochs
    /// @dev This takes into account the reservation amount premiums
    /// @param _endEpoch The epoch after the final reservation epoch
    function getCostToReserve(uint256 _endEpoch) external view returns(uint256) {
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        return (50_000 + reservations[poolEpoch]**2 * 100_000 / amountNft**2) 
                    * (_endEpoch - poolEpoch) * payoutPerRes[poolEpoch] / 250_000_000;
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}