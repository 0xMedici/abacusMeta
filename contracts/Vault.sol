//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { IClosure } from "./interfaces/IClosure.sol";
import { IFactory } from "./interfaces/IFactory.sol";
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

    /* ======== CONSTANTS ======== */
    uint256 constant ELENGTH = 1 days;

    /* ======== ADDRESS ======== */
    IFactory factory;
    AbacusController controller;
    address creator;
    address private _closePoolMultiImplementation;

    /// @notice Address of the deployed closure contract
    address public closePoolContract;

    /* ======== UINT ======== */
    uint256 amountNftsLinked;
    uint256 MAPoolNonce;

    uint256 public interestRate;

    /// @notice The amount of available NFT closures
    uint256 public reservationsAvailable;

    /// @notice Total amount of slots to be collateralized
    uint256 public amountNft;

    /// @notice Pool creation time
    uint256 public startTime;

    /// @notice Pool tranche size
    uint256 public ticketLimit;

    /// @notice Total amount of adjustments required (every time an NFT is 
    /// closed this value increments)
    uint256 public adjustmentsRequired;

    /* ======== MAPPINGS ======== */
    mapping(uint256 => bool) tokenMapping;
    mapping(uint256 => uint256[]) ticketsPurchased;
    mapping(address => mapping(uint256 => uint256)) closureNonce;
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) adjustmentNonce;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) loss;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) epochOfClosure;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) payoutAmount;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) auctionSaleValue;

    mapping(uint256 => uint256) public compressedEpochVals;

    /// @notice A users position nonce
    /// [address] -> User address
    /// [uint256] -> Next nonce value 
    mapping(address => uint256) public positionNonce;

    /// @notice Amount of reservations made during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> amount of reservations
    mapping(uint256 => uint256) public reservations;

    /// @notice Payout size for each reservation during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> payout size
    mapping(uint256 => uint256) public epochEarnings;

    /// @notice Track an addresses allowance status to trade another addresses position
    /// [address] allowance recipient
    mapping(address => address) public allowanceTracker;

    mapping(address => mapping(uint256 => uint256)) public liqAccessed;

    /// @notice Tracking the adjustments made by each user for each open nonce
    /// [address] -> user
    /// [uint256] -> nonce
    /// [uint256] -> amount of adjustments made
    mapping(address => mapping(uint256 => uint256)) public adjustmentsMade;

    /// @notice Track a traders profile for each nonce
    /// [address] -> user
    /// [uint256] -> nonce
    mapping(address => mapping(uint256 => Buyer)) public traderProfile;

    /// @notice Track status of reservations made by an NFT during an epoch 
    /// [uint256] -> epoch
    /// [address] -> NFT Collection address
    /// [uint256] -> NFT ID
    /// [bool] -> status of whether a reservation was made
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public reservationMade;

    /// @notice Track adjustment status of closed NFTs
    /// [address] -> User 
    /// [uint256] -> nonce
    /// [address] -> NFT collection
    /// [uint256] -> NFT ID
    /// [bool] -> Status of adjustment
    mapping(address => mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => bool))))) public adjustCompleted;
    
    /* ======== STRUCTS ======== */
    /// @notice Holds core metrics for each trader
    /// [closed] -> track if a position is closed
    /// [multiplier] -> the multiplier applied to a users credit intake when closing a position
    /// [startEpoch] -> epoch that the position was opened
    /// [unlockEpoch] -> epoch that the position can be closed
    /// [comListOfTickets] -> compressed (using bit shifts) value containing the list of tranches
    /// [comAmountPerTicket] -> compressed (using bit shifts) value containing the list of amounts
    /// of tokens purchased in each tranche
    /// [ethLocked] -> total amount of eth locked in the position
    struct Buyer {
        bool closed;
        uint32 startEpoch;
        uint32 unlockEpoch;
        uint32 riskPoints;
        uint32 riskLost;
        uint128 ethStatic;
        uint128 ethLocked;
        uint128 ethLost;
        uint256 comListOfTickets;
        uint256 comAmountPerTicket;
    }

    /* ======== CONSTRUCTOR ======== */
    
    function initialize(
        uint256 nonce,
        address _controller,
        address closePoolImplementation_,
        address _creator
    ) external initializer {
        controller = AbacusController(_controller);
        factory = IFactory(controller.factory());

        creator = _creator;
        MAPoolNonce = nonce;
        _closePoolMultiImplementation = closePoolImplementation_;
        adjustmentsRequired = 1;
    }

    /* ======== CONFIGURATION ======== */
    /// @notice [setup phase] Give an NFT access to the pool 
    /// @param _compTokenInfo Compressed list of NFT collection address and token ID information
    function includeNft(uint256[] calldata _compTokenInfo) external {
        require(startTime == 0, "AS");
        require(msg.sender == creator, "NC");
        uint256 length = _compTokenInfo.length;
        for(uint256 i = 0; i < length; i++) {
            uint256 id = _compTokenInfo[i] & (2**95-1);
            uint256 temp = _compTokenInfo[i] >> 95;
            address collection = address(uint160(temp & (2**160-1)));
            require(IERC721(collection).ownerOf(id) != address(0), "NO");
            require(!tokenMapping[_compTokenInfo[i]], "AM");
            tokenMapping[_compTokenInfo[i]] = true;
        }
        amountNftsLinked += length;
        factory.emitNftInclusion(_compTokenInfo);
    }

    /// @notice [setup phase] Start the pools operation
    /// @param _slots The amount of collateral slots the pool will offer
    /// @param _ticketSize The size of a tranche
    /// @param _rate The chosen interest rate
    function begin(uint256 _slots, uint256 _ticketSize, uint256 _rate) external payable {
        require(startTime == 0, "AS");
        require(msg.sender == creator, "NC");
        // if(controller.beta() > 1 && (slots * _ticketSize / 1000 * 5e15) > tx.gasprice) {
        //     require(msg.value == slots * _ticketSize / 1000 * 5e15);
        //     alloc.receiveFees{value:msg.value}();
        // }
        amountNft = _slots;
        ticketLimit = _ticketSize;
        reservationsAvailable = _slots;
        interestRate = _rate;
        factory.updateSlotCount(MAPoolNonce, _slots, amountNftsLinked);
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
    /// @param _buyer The position buyer
    /// @param tickets Array of tickets that the buyer would like to add in their position
    /// @param amountPerTicket Array of amount of tokens that the buyer would like to purchase
    /// from each ticket
    /// @param startEpoch Starting LP epoch
    /// @param finalEpoch The first epoch during which the LP position unlocks
    function purchase(
        address _buyer,
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch
    ) external payable nonReentrant {
        require(_buyer == msg.sender);
        require(startTime != 0, "NS");
        require(tickets.length == amountPerTicket.length, "II");
        require(tickets.length <= 100, "II");
        require(startEpoch <= (block.timestamp - startTime) / ELENGTH + 1, "IT");
        require(startEpoch >= (block.timestamp - startTime) / ELENGTH, "IT");
        if(epochEarnings[startEpoch] != 0) startEpoch++;
        require(finalEpoch - startEpoch <= 52, "TL");
        uint256 totalTokensRequested;
        uint256 largestTicket;
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
                finalEpoch
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

        require(msg.value == totalTokensRequested * 0.001 ether, "IF");
    }

    /// @notice Close an LP position and receive credits earned
    /// @dev Users ticket balances are counted on a risk adjusted basis in comparison to the
    /// maximum purchased ticket tranche. The lowest discounted EDC payout is 75% and the 
    /// highest premium is 125% for the highest ticket holders. This rate effects the portion of
    /// EDC that a user receives per EDC emitted from a pool each epoch.
    /// Revenues from an EDC sale are distributed among allocators.
    /// @param _user Address of the LP
    /// @param _nonce Held nonce to close 
    function sell(
        address _user,
        uint256 _nonce
    ) external nonReentrant returns(uint256 interestEarned) {
        require(msg.sender == _user, "IC");
        Buyer storage trader = traderProfile[_user][_nonce];
        require(!trader.closed, "PC");
        require(adjustmentsMade[_user][_nonce] == adjustmentsRequired, "ANM");
        require(trader.unlockEpoch != 0, "ICR");
        uint256 poolEpoch = (block.timestamp - startTime) / ELENGTH;
        uint256 finalEpoch;
        uint256 interestLost;
        if(poolEpoch >= trader.unlockEpoch) {
            finalEpoch = trader.unlockEpoch;
        } else {
            require(reservations[poolEpoch] == 0);
            finalEpoch = poolEpoch;
        }
        for(uint256 j = trader.startEpoch; j < finalEpoch; j++) {
            uint256 riskPoints = this.getRiskPoints(j);
            interestLost += trader.riskLost * epochEarnings[j] / riskPoints;
            interestEarned += (trader.riskPoints - trader.riskLost) * epochEarnings[j] / riskPoints;
        }

        if(poolEpoch < trader.unlockEpoch) {
            for(poolEpoch; poolEpoch < trader.unlockEpoch; poolEpoch++) {
                uint256 tempComp = compressedEpochVals[poolEpoch];
                uint256 prevPosition;
                tempComp = tempComp & ~((2**(prevPosition + 35) - 1) - (2**prevPosition - 1)) | ((compressedEpochVals[poolEpoch] & (2**35 -1)) - (trader.ethLocked / 0.001 ether)); 
                prevPosition += 35;
                tempComp = tempComp & ~((2**(prevPosition + 51) - 1) - (2**prevPosition - 1)) | ((((compressedEpochVals[poolEpoch] >> 35) & (2**51 -1)) - trader.riskPoints) << prevPosition);
                prevPosition += 51;
                tempComp = tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) | ((((compressedEpochVals[poolEpoch] >> 86) & (2**84 -1)) - trader.ethLocked / amountNft) << prevPosition);
                prevPosition += 84;
                tempComp = tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) | ((((compressedEpochVals[poolEpoch] >> 170) & (2**84 -1)) - trader.ethLocked) << prevPosition);
                compressedEpochVals[poolEpoch] = tempComp;
            }
        }
        factory.emitSaleComplete(
            _user,
            _nonce,
            trader.comListOfTickets,
            interestEarned
        );
        payable(controller.multisig()).transfer(trader.ethLost + interestLost);
        payable(_user).transfer(trader.ethLocked + interestEarned);
        trader.closed = true;
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
            require(
                msg.sender == IERC721(nft).ownerOf(id)
                || msg.sender == controller.registry(IERC721(nft).ownerOf(id))
            );
            require(controller.nftVaultSignedAddress(nft, id) == address(this));
            factory.updateNftInUse(nft, id, MAPoolNonce);
            uint256 poolEpoch = (block.timestamp - startTime) / ELENGTH;
            while(reservationMade[poolEpoch][nft][id]) {
                delete reservationMade[poolEpoch][nft][id];
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
        uint256 poolEpoch = epochOfClosure[closureNonce[_nft][_id]][_nft][_id];
        auctionSaleValue[closureNonce[_nft][_id]][_nft][_id] = _saleValue;
        closureNonce[_nft][_id]++;
        uint256 ppr = this.getPayoutPerReservation(poolEpoch);
        uint256 propTrack = this.getTotalAvailableFunds(poolEpoch);
        uint256 mod;
        if(this.getTotalAvailableFunds(poolEpoch) > propTrack) {
            mod = this.getTotalAvailableFunds(poolEpoch) - propTrack;
        }
        while(this.getTotalAvailableFunds(poolEpoch) > 0) {
            uint256 tempComp = compressedEpochVals[poolEpoch];
            uint256 tv = this.getTotalAvailableFunds(poolEpoch);
            uint256 prevPosition = 86;
            tempComp = tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) | ((tv / amountNft) << 86);
            prevPosition += 84;
            tempComp = tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) | ((((compressedEpochVals[poolEpoch] >> 170) & (2**84 -1)) - ppr * (tv - mod) / propTrack) << prevPosition);
            compressedEpochVals[poolEpoch] = tempComp;
            poolEpoch++;
        }
        reservationsAvailable++;
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
    /// @param _id Token ID of the NFT that is being reserved
    /// @param _endEpoch The epoch during which the reservation wears off
    function reserve(address _nft, uint256 _id, uint256 _endEpoch) external payable nonReentrant {
        uint256 poolEpoch = (block.timestamp - startTime) / ELENGTH;
        require(
            msg.sender == IERC721(_nft).ownerOf(_id)
            || msg.sender == controller.registry(IERC721(_nft).ownerOf(_id)),
            "Not owner"
        );
        require(controller.nftVaultSignedAddress(_nft, _id) == address(this), "Not signed");
        require(reservations[poolEpoch] + 1 <= reservationsAvailable, "No res avail");
        require(_endEpoch - poolEpoch <= 20, "Res too long");
        uint256 amount;
        for(uint256 j = poolEpoch; j < _endEpoch; j++) {
            amount += this.getPayoutPerReservation(j);
        }
        require(
            msg.value == (100_000 + reservations[poolEpoch]**2 * 100_000 / amountNft**2) 
                * (_endEpoch - poolEpoch) * (amount / (_endEpoch - poolEpoch)) / 250_000_000,
                "Incorrect payment"
        );
        for(uint256 i = poolEpoch; i < _endEpoch; i++) {
            require(!reservationMade[i][_nft][_id], "Res already made");
            epochEarnings[i] += (100_000 + reservations[i]**2 * 100_000 / amountNft**2) 
                * (amount / (_endEpoch - poolEpoch)) / 250_000_000;
            reservationMade[i][_nft][_id] = true;
            reservations[i]++;
        }
        factory.emitSpotReserved(
            _id,
            poolEpoch,
            _endEpoch
        );
    }

    /* ======== POSITION MOVEMENT ======== */
    /// @notice Allow another user permission to execute a single 'transferFrom' call
    /// @param recipient Allowee address
    function changeTransferPermission(
        address recipient
    ) external nonReentrant returns(bool) {
        allowanceTracker[msg.sender] = recipient;
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
    function transferFrom(
        address from,
        address to,
        uint256 nonce
    ) external nonReentrant returns(bool) {
        require(
            msg.sender == allowanceTracker[from] 
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
    function closeNft(address _nft, uint256 _id) external nonReentrant2 returns(uint256) {
        uint256 poolEpoch = (block.timestamp - startTime) / ELENGTH;
        require(reservationMade[poolEpoch][_nft][_id]);
        adjustmentsRequired++;
        adjustmentNonce[_nft][_id][closureNonce[_nft][_id]] = adjustmentsRequired;
        controller.updateNftUsage(address(this), _nft, _id, false);
        reservationsAvailable--;
        uint256 i = poolEpoch;
        while(reservationMade[i][_nft][_id]) {
            reservationMade[i][_nft][_id] = false;
            reservations[i]--;
            i++;
        }
        i = poolEpoch;
        uint256 ppr = this.getPayoutPerReservation(i);
        if(closePoolContract == address(0)) {
            IClosure closePoolMultiDeployment = 
                IClosure(Clones.clone(_closePoolMultiImplementation));
            closePoolMultiDeployment.initialize(
                address(this),
                address(controller)
            );
            controller.addAccreditedAddressesMulti(address(closePoolMultiDeployment));
            closePoolContract = address(closePoolMultiDeployment);
        }
        IClosure(closePoolContract).startAuction(ppr, _nft, _id);
        IERC721(_nft).transferFrom(msg.sender, address(closePoolContract), _id);
        epochOfClosure[closureNonce[_nft][_id]][_nft][_id] = poolEpoch;
        payoutAmount[closureNonce[_nft][_id]][_nft][_id] = ppr;
        uint256 payout = 1 * ppr / 100;
        epochEarnings[poolEpoch] += payout;
        payable(msg.sender).transfer(ppr - payout - liqAccessed[_nft][_id]);
        factory.emitNftClosed(
            msg.sender,
            _nft,
            _id,
            ppr,
            address(closePoolContract)
        );
        return(ppr - payout);
    }

    /* ======== ACCOUNT CLOSURE ======== */
    /// @notice Adjust a users LP information after an NFT is closed
    /// @dev This function is called by the calculate principal function in the closure contract
    /// @param _user Address of the LP owner
    /// @param _nonce Nonce of the LP
    /// @param _nft Address of the auctioned NFT
    /// @param _id Token ID of the auctioned NFT
    /// @param _closureNonce Closure nonce of the NFT being adjusted for
    function adjustTicketInfo(
        address _user,
        uint256 _nonce,
        address _nft,
        uint256 _id,
        uint256 _closureNonce
    ) external nonReentrant returns(bool) {
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
            this.getTokensPurchased(epochOfClosure[_closureNonce][_nft][_id]),
            payoutAmount[_closureNonce][_nft][_id],
            auctionSaleValue[_closureNonce][_nft][_id],
            trader.comListOfTickets,
            trader.comAmountPerTicket
        );
        lossCalculator(
            trader,
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

    function processFees() external payable {
        require(controller.lender() == msg.sender, "Not accredited");
        uint256 poolEpoch = (block.timestamp - startTime) / ELENGTH;
        uint256 payout = msg.value / 25;
        payable(controller.multisig()).transfer(payout);
        epochEarnings[poolEpoch] += msg.value - payout;
    }

    function accessLiq(address _user, address _nft, uint256 _id, uint256 _amount) external {
        require(controller.lender() == msg.sender, "Not accredited");
        liqAccessed[_nft][_id] += _amount;
        payable(_user).transfer(_amount);
    }

    function depositLiq(address _nft, uint256 _id) external payable {
        require(controller.lender() == msg.sender, "Not accredited");
        liqAccessed[_nft][_id] -= msg.value;
    }

    /* ======== INTERNAL ======== */
    function choppedPosition(
        address _buyer,
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch
    ) internal returns(uint256 largestTicket) {
        uint256 _nonce = positionNonce[_buyer];
        positionNonce[_buyer]++;
        Buyer storage trader = traderProfile[_buyer][_nonce];
        adjustmentsMade[_buyer][_nonce] = adjustmentsRequired;
        trader.startEpoch = uint32(startEpoch);
        trader.unlockEpoch = uint32(finalEpoch);
        uint256 riskPoints;
        uint256 length = tickets.length;
        for(uint256 i; i < length; i++) {
            riskPoints += getSqrt((100 + tickets[i]) / 10) ** 3 * amountPerTicket[i];
        }
        (trader.comListOfTickets, trader.comAmountPerTicket, largestTicket, trader.ethLocked) = BitShift.bitShift(
            tickets,
            amountPerTicket
        );
        trader.ethStatic = trader.ethLocked;
        trader.riskPoints = uint32(riskPoints);

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
        for(uint256 j = startEpoch; j < endEpoch; j++) {
            uint256 riskPoints;
            while(ticketsPurchased[j].length == 0 || ticketsPurchased[j].length - 1 < largestTicket / 15) ticketsPurchased[j].push(0);
            uint256[] memory epochTickets = ticketsPurchased[j];
            uint256 amount;
            uint256 temp;
            for(uint256 i = 0; i < length; i++) {
                uint256 ticket = tickets[i];
                riskPoints += getSqrt((100 + ticket) / 10) ** 3 * ticketAmounts[i];
                temp = this.getTicketInfo(j, ticket);
                temp += ticketAmounts[i];
                require(ticketAmounts[i] != 0);
                require(temp <= amountNft * ticketLimit);
                epochTickets[ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1) - (2**(((ticket % 10))*25) - 1));
                epochTickets[ticket / 10] |= (temp << ((ticket % 10)*25));
                amount += ticketAmounts[i];
            }
            uint256 tempComp = compressedEpochVals[j];
            uint256 prevPosition;
            require(((compressedEpochVals[j] & (2**35 -1)) + amount) < (2**35 -1));
            tempComp = tempComp & ~((2**(prevPosition + 35) - 1) - (2**prevPosition - 1)) | ((compressedEpochVals[j] & (2**35 -1)) + amount); 
            prevPosition += 35;
            require((((compressedEpochVals[j] >> 35) & (2**51 -1)) + riskPoints) < (2**51 -1));
            tempComp = tempComp & ~((2**(prevPosition + 51) - 1) - (2**prevPosition - 1)) | ((((compressedEpochVals[j] >> 35) & (2**51 -1)) + riskPoints) << prevPosition);
            prevPosition += 51;
            require((((compressedEpochVals[j] >> 86) & (2**84 -1)) + amount * 0.001 ether / amountNft) < (2**84 -1));
            tempComp = tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) | ((((compressedEpochVals[j] >> 86) & (2**84 -1)) + amount * 0.001 ether / amountNft) << prevPosition);
            prevPosition += 84;
            require((((compressedEpochVals[j] >> 170) & (2**84 -1)) + amount * 0.001 ether) < (2**84 -1));
            tempComp = tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) | ((((compressedEpochVals[j] >> 170) & (2**84 -1)) + amount * 0.001 ether) << prevPosition);
            compressedEpochVals[j] = tempComp;
            ticketsPurchased[j] = epochTickets;
            totalTokens = amount;
        }
    }

    function internalAdjustment(
        address _user,
        uint256 _nonce,
        uint256 _totalTokens,
        uint256 _payout,
        uint256 _finalNftVal,
        uint256 _comTickets,
        uint256 _comAmounts
    ) internal returns(uint256 appLoss) {
        Buyer storage trader = traderProfile[_user][_nonce];
        uint256 payout;
        uint256 premium = _finalNftVal > _payout ? _finalNftVal - _payout : 0;
        uint256 userTokens;
        while(_comAmounts > 0) {
            uint256 ticket = _comTickets & (2**25 - 1);
            uint256 amountTokens = _comAmounts & (2**25 - 1);
            uint256 monetaryTicketSize = 1e18 * ticketLimit / 1000;
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
                        * 0.001 ether / monetaryTicketSize 
                            / amountNft / 100;
            }

            userTokens += amountTokens / 100;
        }

        trader.ethLocked -= uint128(appLoss);
        trader.riskLost = uint32(trader.riskPoints - trader.ethLocked * trader.riskPoints / trader.ethStatic);
        payable(_user).transfer(payout * (userTokens * premium / _totalTokens) / (payout + appLoss));
        appLoss += appLoss * premium / (payout + appLoss);
    }

    function lossCalculator(
        Buyer storage trader,
        address _nft,
        uint256 _id,
        uint256 _closureNonce,
        uint256 appLoss
    ) internal {
        uint256 _payoutAmount = payoutAmount[_closureNonce][_nft][_id];
        uint256 _saleValue = auctionSaleValue[_closureNonce][_nft][_id];
        uint256 _loss = loss[_closureNonce][_nft][_id];
        if(_payoutAmount > _saleValue) {
            if(_loss > _payoutAmount - _saleValue) {
                trader.ethLost += uint128(appLoss);
            } else if(_loss + appLoss > _payoutAmount - _saleValue) {
                trader.ethLost += uint128(_loss + appLoss - (_payoutAmount - _saleValue));
            }
        }
        loss[_closureNonce][_nft][_id] += appLoss;
    }

    /* ======== GETTER ======== */
    function getSqrt(uint x) public pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /// @notice Get multi asset pool reference nonce
    function getNonce() external view returns(uint256) {
        return MAPoolNonce;
    }

    function getTotalAvailableFunds(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return (compVal >> 170) & (2**84 -1);
    }

    function getPayoutPerReservation(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return (compVal >> 86) & (2**84 -1);
    }

    function getRiskPoints(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return (compVal >> 35) & (2**51 -1);
    }

    function getTokensPurchased(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return compVal & (2**35 -1);
    }

    // function getEpochInfo(uint256 _epoch) external view returns(
    //     uint256 totalAvailableFunds,
    //     uint256 payoutPerReservation,
    //     uint256 riskPoints,
    //     uint256 tokensPurchased
    // ) {
    //     uint256 compVal = compressedEpochVals[_epoch];
    //     tokensPurchased = compVal & (2**35 -1);
    //     compVal >>= 35;
    //     riskPoints = compVal & (2**51 -1);
    //     compVal >>= 51;
    //     payoutPerReservation = compVal & (2**85 -1);
    //     compVal >>= 85;
    //     totalAvailableFunds = compVal & (2**85 -1);
    // }

    function getPosition(
        address _user, 
        uint256 _nonce
    ) external view returns(
        uint32 startEpoch,
        uint32 endEpoch,
        uint256 tickets, 
        uint256 amounts,
        uint256 ethLocked
    ) {
        Buyer memory trader = traderProfile[_user][_nonce];
        startEpoch = trader.startEpoch;
        endEpoch = trader.unlockEpoch;
        tickets = trader.comListOfTickets;
        amounts = trader.comAmountPerTicket;
        ethLocked = trader.ethLocked;
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
        if(epochTickets.length <= ticket / 10) {
            return 0;
        }
        uint256 temp = epochTickets[ticket / 10];
        temp &= (2**((ticket % 10 + 1)*25) - 1) - (2**(((ticket % 10))*25) - 1);
        return temp >> ((ticket % 10) * 25);
    }

    /// @notice Get the cost to reserve an NFT for an amount of epochs
    /// @dev This takes into account the reservation amount premiums
    /// @param _endEpoch The epoch after the final reservation epoch
    function getCostToReserve(uint256 _endEpoch) external view returns(uint256) {
        uint256 poolEpoch = (block.timestamp - startTime) / ELENGTH;
        uint256 amount;
        for(uint256 j = poolEpoch; j < _endEpoch; j++) {
            amount += this.getPayoutPerReservation(j);
        }
        return (100_000 + reservations[poolEpoch]**2 * 100_000 / amountNft**2) 
            * (_endEpoch - poolEpoch) * (amount / (_endEpoch - poolEpoch)) / 250_000_000;
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}