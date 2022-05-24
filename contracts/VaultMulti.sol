//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ABCToken } from "./AbcToken.sol";
import { AbacusController } from "./AbacusController.sol";
import { IClosePoolMulti } from "./interfaces/IClosePoolMulti.sol";
import { IVaultFactoryMulti } from "./interfaces/IVaultFactoryMulti.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { IVeAbc } from "./interfaces/IVeAbc.sol";
import { ICreditBonds } from "./interfaces/ICreditBond.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ClonesUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "./helpers/ReentrancyGuard.sol";
import "./helpers/ReentrancyGuard2.sol";
import "hardhat/console.sol";

/// @title Spot pool
/// @author Gio Medici
/// @notice Spot pool contract
contract VaultMulti is ReentrancyGuard, ReentrancyGuard2, Initializable {

    ///TODO: add events

    /* ======== ADDRESS ======== */

    IVaultFactoryMulti factory;

    /// @notice configure directory contract
    AbacusController controller;

    /// @notice abc token address
    ABCToken abcToken;

    /// @notice epoch vault address
    IEpochVault epochVault;

    IVeAbc veAbc;

    address public creator;

    /// @notice closure contract
    address public closePoolContract;

    /// @notice implementation of closure contract of intialize
    address private _closePoolMultiImplementation;

    /* ======== LOCKED ERC721 ======== */

    /// @notice NFT address
    IERC721 public heldCollection;

    /// @notice NFT id
    uint256[] public heldTokenIds;

    /* ======== UINT ======== */

    uint256 MAPoolNonce;

    uint256 public reservationsAvailable;

    uint256 public amountNft;

    /// @notice pool start time
    uint256 public startTime;

    /// @notice pool vault version
    uint8 public vaultVersion;

    /// @notice time emissions will stop
    uint64 public timeStopEmissions;

    /// @notice total tokens locked in pool
    uint256 public tokensLocked;

    /// @notice checkpoint for which position that was last counted
    uint256 positionCheckpoint;

    /// @notice point value of position checkpoint that was last counted
    uint256 positionPointCheckpoint;

    /// @notice tracker for how many tokens have been accounted for during the post auction custodial functions 
    uint256 tokensAccountedFor;

    uint256 public adjustmentsRequired;

    /* ======== BOOLEANS ======== */

    /// @notice signify whether the owner signed off on the pools emissions 
    bool public emissionsStarted;

    /// @notice mark pool locked after closed
    bool public poolClosed;

    /// @notice mark that position premiums for all positions have been calculated
    bool positionPremiumsCalculated;

    /* ======== MAPPINGS ======== */

    mapping(uint256 => uint256) public epochOfClosure;

    mapping(address => uint256) public adjustmentsMade;

    /// @notice track whether the user adjusted their payout ratio to move off the default value when selling
    mapping(address => bool) public payoutRatioAdjusted;

    /// @notice reward cap (based on how much ETH is in the pool with 100 EDC cap) for how much EDC is emitted per week
    mapping(uint256 => uint256) public rewardCapPerEpoch;

    /// @notice highest tranche per epoch
    mapping(uint256 => uint256) public maxTicketPerEpoch;

    /// @notice total amount of nominal tokens (token count post lock duration multiplier) per epoch 
    mapping(uint256 => uint256) public totalNominalTokensPerEpoch;

    /// @notice how many tokens have been purchased in a ticket range
    mapping(uint256 => uint256) public ticketsPurchased;

    mapping(uint256 => uint256) public reservations;

    mapping(uint256 => mapping(uint256 => uint256)) public totalNominalPerTicketPerEpoch;

    //TODO: consider removing
    mapping(uint256 => uint256) public unlockSizePerEpoch;

    mapping(uint256 => address[]) public addressesToClosePerEpoch;

    mapping(uint256 => uint256) public payoutPerRes;

    mapping(uint256 => uint256) public totAvailFunds;

    /// @notice used as a checkpoint for a users point of closure
    mapping(address => uint256) closureCheckpoint;

    /// @notice map each pool buyer
    mapping(address => Buyer) public traderProfile;

    /// @notice map lingering pending order to holder 
    mapping(address => mapping(uint256 => PendingOrder)) public pendingOrder;

    mapping(uint256 => mapping(uint256 => bool)) public reservationMade;

    mapping(uint256 => uint256) public generalBribe;

    mapping(uint256 => mapping(uint256 => uint256)) public concentratedBribe;
    
    /* ======== STRUCTS ======== */

    /// @notice user Buyer profile
    /** 
    @dev (1) creditPurchasePercentage -> what percentage of available credits would you like to purchase during sale
         (2) ticketsOpen -> how many tickets do you have open
         (3) startTime -> when did you originally lock you tokens
         (4) timeUnlock -> when tokens unlock
         (5) tokensLocked -> how many pool tokens are locked
         (6) finalCreditCount -> final amount of credits that'll be owned at unlock time
         (7) startEpoch -> the first epoch that a users funds are locked in
         (8) finalEpoch -> the final epoch that a users funds are locked in
         (9) listOfTickets -> list of a users tickets
         (10) ticketsOwned -> amount of tokens per ticket
         (11) nominalPerTicket -> nominal amount of tokens owned per ticket
         (12) nominalTokensPerEpoch -> nominal amount of tokens per epoch
    */
    struct Buyer {
        uint16 creditPurchasePercentage;
        uint16 ticketsOpen;
        uint32 startEpoch;
        uint32 finalEpoch;
        uint64 startTime;
        uint64 timeUnlock;
        uint128 tokensLocked;
        uint256 ethLocked;
        uint256 finalCreditCount;
        uint256[] listOfTickets;
        mapping(uint256 => uint256) ticketsOwned;
        mapping(uint256 => uint256) nominalPerTicket;
        mapping(uint256 => uint256) nominalTokensPerEpoch;
    }

    /// @notice represents a pending order that a user submits to buy the locked positions upon opening
    /** 
    @dev (1) ticketQueued -> if a pending order is queued
         (2) lockTime -> length of lockup if order executed 
         (3) executorReward -> reward offered to caller that fills the position
         (4) ticket -> list of tickets for targeted execution
         (5) amount -> list of amounts for targeted execution
         (6) buyer -> buyer who owns the pending order being executed
    */
    struct PendingOrder {
        bool ticketQueued;
        uint64 finalEpoch;
        uint256 executorReward;
        uint256[] ticket;
        uint256[] amount;
        address buyer;
    }

    /* ======== CONSTRUCTOR ======== */
    
    function initialize(
        IERC721 _heldTokenCollection,
        uint256[] memory _heldTokenIds,
        uint256 _vaultVersion,
        uint256 slots,
        uint256 nonce,
        address _creator,
        address _controller,
        address closePoolImplementation_
    ) external initializer {
        controller = AbacusController(_controller);
        abcToken = ABCToken(controller.abcToken());
        epochVault = IEpochVault(controller.epochVault());
        factory = IVaultFactoryMulti(controller.factoryVersions(_vaultVersion));
        veAbc = IVeAbc(controller.veAbcToken());

        vaultVersion = uint8(_vaultVersion);
        creator = _creator;
        heldCollection = _heldTokenCollection;
        heldTokenIds = _heldTokenIds;
        amountNft = slots;
        reservationsAvailable = slots;
        startTime = block.timestamp;
        MAPoolNonce = nonce;

        _closePoolMultiImplementation = closePoolImplementation_;
    }

    /* ======== USER ADJUSTMENTS ======== */

    /// @notice user can adjust what percentage of credits they'd like to purchase when unlocking tokens
    /// @param _creditPurchasePercentage percentage of credits to be purchased (scale 0 - 1000)
    function adjustPayoutRatio(uint256 _creditPurchasePercentage) external {
        if(!payoutRatioAdjusted[msg.sender]) payoutRatioAdjusted[msg.sender] = true;
        Buyer storage trader = traderProfile[msg.sender];
        trader.creditPurchasePercentage = uint16(_creditPurchasePercentage);
    }

    function startEmission() external {
        require(msg.sender == address(factory));
        emissionsStarted = true;
        timeStopEmissions = uint64(block.timestamp + 8 days);
    }

    /* ======== TRADING ======== */

    /// @notice Purchase and lock tokens
    /// @param _caller address that is responsible for calling the function
    /// @param _buyer address that the purchase is being executed on behalf of
    /// @param tickets tickets from which the buyer would like to purchase tokens
    /// @param amountPerTicket how many tokens to purchase per ticket
    /// @param finalEpoch how long to lock the tokens for
    function purchase(
        address _caller,
        address _buyer, 
        uint256[] memory tickets, 
        uint256[] memory amountPerTicket, 
        uint256 finalEpoch
    ) payable external {
        if(msg.sender != address(this) && msg.sender != controller.creditBonds()) {
            takePayment(msg.sender);
        }
        require(!poolClosed);

        uint256 totalTokensRequested;
        uint256 localMaxTicket;
        uint256 _lockTime;
        uint256 length = tickets.length;
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        Buyer storage trader = traderProfile[_buyer];

        if(trader.timeUnlock == 0) {
            _lockTime = finalEpoch * 1 days + startTime - block.timestamp;
            addressesToClosePerEpoch[finalEpoch].push(_buyer);
        }
        else {
            require(adjustmentsMade[_buyer] == adjustmentsRequired);
            require(trader.timeUnlock - block.timestamp > 1 days);
            _lockTime = trader.timeUnlock - block.timestamp;
        }

        //TODO: lock time has to be greater than 2 days
        require(_lockTime >= 1 days);
        require(_lockTime <= 8 days);
        //TODO: trader time unlock difference must be greater than 3 days
        for(uint256 i=0; i<length; i++) {
            /// check purchase request is properly submitted
            require(tickets[i] % 1e18 == 0);
            require(ticketsPurchased[tickets[i]] + amountPerTicket[i] <= amountNft * 1000e18);

            /// update local max value
            if(tickets[i] > localMaxTicket) localMaxTicket = tickets[i];
            /// check that all previous tickets are filled (recursively checks and allows for executed pending orders to bypass)
            if(tickets[i] != 0 && msg.sender != address(this)) require(ticketsPurchased[tickets[i] - 1e18] == amountNft * 1000e18);
            /// if new ticket being purchased add it to the traders list
            if(trader.ticketsOwned[tickets[i]] == 0) {
                trader.listOfTickets.push(tickets[i]);
                trader.ticketsOpen++;
            }
            uint256 addedAmount = _lockTime * 2 * amountPerTicket[i] * 0.001 ether / 1e18;

            totalTokensRequested += amountPerTicket[i];
            ticketsPurchased[tickets[i]] += amountPerTicket[i];
            trader.ticketsOwned[tickets[i]] += amountPerTicket[i];
            trader.nominalPerTicket[tickets[i]] += addedAmount;

            ///update upcoming epochs with added amount of tokens
            for(uint256 j = poolEpoch; j < finalEpoch; j++) {
                totalNominalPerTicketPerEpoch[j][i] += addedAmount;
                totalNominalTokensPerEpoch[j] += addedAmount;
                trader.nominalTokensPerEpoch[j] += addedAmount;
                rewardCapPerEpoch[j] += amountPerTicket[i] * 0.001 ether / 1e18;
                payoutPerRes[j] += amountPerTicket[i] * 0.001 ether / 1e18 / amountNft;
                totAvailFunds[j] += amountPerTicket[i] * 0.001 ether / 1e18;
            }
        
            if(msg.sender == address(this)) break;
        }

        trader.finalEpoch = uint32(finalEpoch);
        /// update max ticket per epoch using the local max
        for(uint256 i = poolEpoch; i < trader.finalEpoch; i++) {
            maxTicketPerEpoch[i] = 1e18;
            if(localMaxTicket > maxTicketPerEpoch[i]) maxTicketPerEpoch[i] = localMaxTicket;
        }
        
        /// check credit bonds and verify purchase cost
        uint256 creditedAmount; 
        uint256 cost = 10_125 * totalTokensRequested * 0.001 ether / 1e18 / 10_000;
        creditedAmount = ICreditBonds(controller.creditBonds()).sendToVault(msg.sender, address(this), _buyer, cost);
        if(msg.sender != address(this)) require(msg.value + creditedAmount == cost);

        factory.updatePendingReturns{ 
            value:25 * (totalTokensRequested / 1e18 * 0.001 ether) / 10_000
        } ( creator );
        factory.updatePendingReturns{ 
            value:100 * (totalTokensRequested / 1e18 * 0.001 ether) / 10_000
        } ( _caller );

        /// lock user tokens
        if(trader.startTime == 0) lockTokens(_buyer, totalTokensRequested, _lockTime);
        else addTokens(_buyer, totalTokensRequested);
    }

    /// @notice Sell and unlock tokens
    /// @dev Upon the sale of each ticket, any pending order is executed and the caller is rewarded the executor reward
    /// @param _user address of person that is being sold for
    function sell(
        address _user 
    ) nonReentrant2 external {
        takePayment(msg.sender);

        Buyer storage trader = traderProfile[_user];
        uint256 _totalTokensRequested;
        uint256 bribePayout;
        uint256 length = trader.listOfTickets.length;

        require(adjustmentsMade[_user] == adjustmentsRequired);
        require(trader.timeUnlock <= block.timestamp);
        require(trader.ticketsOpen != 0);

        for(uint256 j = trader.startEpoch; j < trader.finalEpoch; j++) {
            uint256 amount;
            for(uint256 i=length - 1; i>=(length > 25 ? length - 25:0); i--) {
                uint256 ticketId = trader.listOfTickets[i];
                uint256 tokensOwned = trader.ticketsOwned[ticketId];
                /// add nominal tokens per ticket to local tracker `amount`
                amount += 
                    (75e18 + (ticketId ** 2) * 100e18 / (maxTicketPerEpoch[j] ** 2) / 2) * trader.nominalPerTicket[ticketId] / 100e18;
                _totalTokensRequested += tokensOwned;

                bribePayout += trader.nominalPerTicket[ticketId] * concentratedBribe[j][i] / totalNominalPerTicketPerEpoch[j][i];
                /// if on final epoch start clearing token list and decreasing tranche sizes
                if(j == trader.finalEpoch - 1) {
                    ticketsPurchased[ticketId] -= tokensOwned;
                    delete trader.nominalPerTicket[ticketId];
                    delete trader.ticketsOwned[ticketId];
                    trader.ticketsOpen--;
                    
                    /// if pending order is waiting for execution - execute it
                    if(pendingOrder[_user][ticketId].ticketQueued) {
                        pendingOrder[_user][ticketId].amount.push(tokensOwned);
                        executePending(msg.sender, _user, ticketId, tokensOwned);
                    }
                    
                    trader.listOfTickets.pop();
                    if(trader.ticketsOpen == 0) {
                        break;
                    }
                }

                if(trader.listOfTickets.length == 0 || i == 0) break;
            }

            ///check reward cap to calculate weekly reward cap count
            uint256 rewardCap;
            if(rewardCapPerEpoch[j] < 100e18) rewardCap = rewardCapPerEpoch[j];
            else rewardCap = 100e18;
            ///increase final credit count
            trader.finalCreditCount += amount * rewardCap / totalNominalTokensPerEpoch[j];
            bribePayout += amount * generalBribe[j] / totalNominalTokensPerEpoch[j];

            /// unlock users tokens
            if(trader.ticketsOpen == 0) {
                unlockTokens(msg.sender, _user);
                break;
            }

            factory.updatePendingReturns{ 
                value:bribePayout
            } ( _user );
        }
    }

    /// @notice Allow users to submit pending orders to the meta-layer of Spot pools 
    /// @dev allows users to bid for the rights to a position when it opens. 
    /// the executor reward goes to the person that executes the sale.
    /// @param _targetPositionHolder the position that the user is interested in buying ticket from
    /// @param _buyer the buyer address that is submiting the purchase order
    /// @param ticket targeted ticket of interest
    /// @param finalEpoch amount of time the user would like to lock their tokens for
    /// @param executorReward reward being offered to the caller that executes the sale
    function createPendingOrder(
        address _targetPositionHolder,
        address _buyer,
        uint256 ticket,
        uint256 finalEpoch,
        uint256 executorReward
    ) nonReentrant payable external {
        require(!poolClosed);
        takePayment(msg.sender);
        PendingOrder storage newOrder = pendingOrder[_targetPositionHolder][ticket];
        if(traderProfile[_buyer].timeUnlock != 0) {
            require(traderProfile[_buyer].timeUnlock - block.timestamp > 1 days);
            require(traderProfile[_buyer].timeUnlock - traderProfile[_targetPositionHolder].timeUnlock > 1 days);
        }
        
        require(traderProfile[_targetPositionHolder].timeUnlock - block.timestamp < 1 days);
        require(
            msg.value == 
                10_125 * traderProfile[_targetPositionHolder].ticketsOwned[ticket] * 0.001 ether / 1e18 / 10_000 + executorReward
        );
        /// check that executor reward outbids last bidder
        require(executorReward > newOrder.executorReward);

        /// update and send return funds to factory
        if(newOrder.ticketQueued) {
            factory.updatePendingReturns{ 
                value:newOrder.executorReward + traderProfile[_targetPositionHolder].ticketsOwned[ticket] * 0.001 ether / 1e18 
            } ( newOrder.buyer );
        }
        else{
            newOrder.ticket.push(ticket);
        }

        /// update new pending order configuration
        newOrder.finalEpoch = uint64(finalEpoch);
        newOrder.executorReward = executorReward;
        newOrder.buyer = _buyer;
        newOrder.ticketQueued = true;
    }

    function offerGeneralBribe(uint256 bribePerEpoch, uint256 startEpoch, uint256 endEpoch) payable external {
        uint256 cost;
        for(uint256 i = startEpoch; i < endEpoch; i++) {
            generalBribe[i] += bribePerEpoch;
            cost += bribePerEpoch;
        }

        require(msg.value == cost);
    }

    function offerConcentratedBribe(
        uint256 startEpoch, 
        uint256 endEpoch, 
        uint256[] memory tickets,
        uint256[] memory bribePerTicket
    ) payable external {
        uint256 cost;
        uint256 length = tickets.length;
        require(length == bribePerTicket.length);
        for(uint256 i = startEpoch; i < endEpoch; i++) {
            for(uint256 j = 0; j < length; j++) {
                concentratedBribe[i][tickets[j]] += bribePerTicket[j];
                cost += bribePerTicket[j];
            }
        }

        require(msg.value == cost);
    }

    function remove(uint256 id) external {
        require(msg.sender == heldCollection.ownerOf(id));
        uint256 timeLeftMultiplier = (timeStopEmissions / 1 days);
        uint256 gas = timeLeftMultiplier ** 2 * controller.abcGasFee();
        abcToken.bypassTransfer(
            msg.sender, 
            controller.epochVault(),
            gas
        );
        epochVault.receiveAbc(
            gas
        );
        heldTokenIds = factory.updateNftInUse(address(heldCollection), id, MAPoolNonce);
    }

    function updateAvailFunds(uint256 _id, uint256 _saleValue) external {
        require(msg.sender == closePoolContract);
        uint256 e = (block.timestamp - startTime) / 1 days;
        uint256 ppr = payoutPerRes[epochOfClosure[_id]];
        if(_saleValue > payoutPerRes[e]) return;
        //TODO: revisit, the value is 12 because of max lockup time of 12 weeks 
        while(totAvailFunds[e] > 0 && e <= epochOfClosure[_id] + 12) {
            totAvailFunds[e] -= totAvailFunds[e] * ((ppr - _saleValue) * 1e18 / ppr / amountNft) / 1e18;
            e++;
        }
    }

    function restore() external returns(bool) {
        uint256 startingEpoch = (block.timestamp - startTime) / 1 days;
        require(!poolClosed);
        require(reservations[startingEpoch] == 0);
        require(reservationsAvailable < amountNft);
        require(IClosePoolMulti(closePoolContract).getLiveAuctionCount() == 0);

        while(totAvailFunds[startingEpoch] > 0) {
            payoutPerRes[startingEpoch] = totAvailFunds[startingEpoch] / amountNft;
            startingEpoch++;
        }

        return true;
    }

    function reserve(uint256 id, uint256 endEpoch) external {
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        require(!poolClosed);
        require(msg.sender == heldCollection.ownerOf(id));
        require(factory.getIdPresence(address(heldCollection), id));
        require(reservations[poolEpoch] + 1 <= reservationsAvailable);
        require(endEpoch - poolEpoch <= 12);
        uint256 gas = controller.abcGasFee();
        abcToken.bypassTransfer(
            msg.sender, 
            controller.epochVault(),
            reservations[poolEpoch] ** 2 * (endEpoch - poolEpoch) * gas
        );
        epochVault.receiveAbc(
            reservations[poolEpoch] ** 2 * (endEpoch - poolEpoch) * gas
        );
        for(uint256 i = poolEpoch; i < endEpoch; i++) {
            reservationMade[i][id] = true;
            reservations[i]++;
        }
    }

    /* ======== POOL CLOSURE ======== */

    /// @notice close pool and deploy pool closure contract
    /** 
    @dev In the case of an auction the value in the pool is sent to the owner at the end of the tx and fees are stored
    for distribution on the current contract while the NFT is sent to the closure contract for auction. 
    In the case of an exit fee being paid, the owner immediately receives the NFT and the exit fee money is 
    sent to the closure contract for users to claim when closing their accounts.
    */
    function closeNft(uint256 _id) nonReentrant external {
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        require(reservationMade[poolEpoch][_id]);
        require(!poolClosed);
        adjustmentsRequired++;

        //closure fee to close a vault
        uint256 closureFee = controller.vaultClosureFee();
        abcToken.bypassTransfer(msg.sender, address(epochVault), closureFee);
        epochVault.receiveAbc(closureFee);
        heldTokenIds = factory.updateNftInUse(address(heldCollection), _id, MAPoolNonce);
        reservationsAvailable--;

        uint256 i = poolEpoch;
        while(reservationMade[i][_id]) {
            reservationMade[i][_id] = false;
            reservations[i]--;
            i++;
        }

        if(closePoolContract == address(0)) {
            IClosePoolMulti closePoolMultiDeployment = IClosePoolMulti(ClonesUpgradeable.clone(_closePoolMultiImplementation));
            closePoolMultiDeployment.initialize(
                address(this),
                address(controller),
                address(heldCollection),
                vaultVersion
            );

            controller.addAccreditedAddresses(address(closePoolMultiDeployment), address(0), 0, 0);
            closePoolContract = address(closePoolMultiDeployment);
        }

        IClosePoolMulti(closePoolContract).startAuction(payoutPerRes[poolEpoch], _id);
        //transfer held NFT to the owner (exit fee) or closure contract (auction)
        heldCollection.transferFrom(msg.sender, address(closePoolContract), _id);

        epochOfClosure[_id] = poolEpoch;
        payable(msg.sender).transfer(payoutPerRes[poolEpoch]);
    }

    function closePool() external {
        require(msg.sender == address(factory));
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        require(reservations[poolEpoch] == 0);
        poolClosed = true;
    } 

    /* ======== ACCOUNT CLOSURE ======== */

    /// @notice adjust ticket info when closing account on closure contract
    /// @dev calculates the final principal of a user by clearing each ticket in comparison to final nft value using FIFO
    /// @param _user the user whos principal that is being calculated
    /// @param _finalNftVal the final auction sale price of the NFT 
    /// @param _id id of token that the user is adjusting for
    function adjustTicketInfo(
        address _user,
        uint256 _finalNftVal,
        uint256 _id
    ) external returns(bool complete){
        require(adjustmentsMade[_user] < adjustmentsRequired);

        ///TODO: adjust to fill in tickets with purchase price and payout premium
        //only closure contract can call this
        Buyer storage trader = traderProfile[_user];
        uint256 _epochOfClosure = epochOfClosure[_id];
        /** 
        compare each ticket to final NFT val and follow:
            - ticket value < nft value -> add val of tokens in ticket to principal 
            - ticket start < nft value && ticket end > nft val -> take the proportional overflow
              and return each token in ticket at that value
            - ticket start > nft value -> tokens in ticket are worth 0
        */
        uint256 toRemoveNom;
        uint256 length = trader.listOfTickets.length;
        uint256 checkpoint = closureCheckpoint[_user];

        for(uint256 i=checkpoint; i<checkpoint+1; i++) {
            if(maxTicketPerEpoch[_epochOfClosure] + 1e18 < _finalNftVal) {
                complete = true;
                break; 
            }
            uint256 ticketId = trader.listOfTickets[i];
            if(ticketId + 1e18 < _finalNftVal) {
                if(i == length - 1) {
                    complete = true;
                    break;
                }
                continue;
            }
            if(ticketId > _finalNftVal) {
                trader.ticketsOwned[ticketId] = trader.ticketsOwned[ticketId] * (amountNft - 1)/amountNft;
                trader.nominalPerTicket[ticketId] = trader.nominalPerTicket[ticketId] * (amountNft - 1)/amountNft;
                toRemoveNom += trader.nominalPerTicket[ticketId] * 1/amountNft;
            }
            else if(ticketId + 1e18 > _finalNftVal) {
                trader.ticketsOwned[ticketId] -= 
                    trader.ticketsOwned[ticketId] / amountNft * (ticketId + 1e18 - _finalNftVal) / 1e18;
                trader.nominalPerTicket[ticketId] -= 
                    trader.nominalPerTicket[ticketId] / amountNft * (ticketId + 1e18 - _finalNftVal) / 1e18;
                toRemoveNom += 
                    trader.nominalPerTicket[ticketId] / amountNft * (ticketId + 1e18 - _finalNftVal) / 1e18;
            }
            
            if(i == length - 1) {
                complete = true;
                break;
            }
        }

        for(uint256 j = _epochOfClosure; j < trader.finalEpoch; j++) {
            trader.nominalTokensPerEpoch[j] -= toRemoveNom;
        }

        uint256 auctionPremium = IClosePoolMulti(closePoolContract).getAuctionPremium(_id);
        if(!complete) closureCheckpoint[_user] += 1;
        else {
            closureCheckpoint[_user] = 0;
            adjustmentsMade[_user]++;
            IClosePoolMulti(closePoolContract).payout(
                _user, 
                auctionPremium * trader.nominalTokensPerEpoch[_epochOfClosure] / totalNominalTokensPerEpoch[_epochOfClosure]
            );
        }
    }

    /* ======== INTERNAL ======== */

    /// @notice lock purchase pool tokens 
    /** 
    @dev when user purchases tokens, they're automatically locked. 
    Upon locking the user final eth:credit purchase rate is 1:(lock time / 1 weeks).
    This means that at the position maturity, the user will be able to purchase 
    (tokensLocked * 0.001 ether) * (lock time / 1 weeks) for the cost of (tokensLocked * 0.001 ether).
    This function is only called when a user has 0 tokens locked.
    */
    /// @param _user the user that is locking tokens
    /// @param _amount the amount of tokens being locked
    /// @param _lockTime the amount of times the tokens are being locked 
    function lockTokens(address _user, uint256 _amount, uint256 _lockTime) internal {
        adjustmentsMade[_user] = adjustmentsRequired;
        //max lock time is 12 weeks
        uint256 poolEpoch = (block.timestamp - startTime) / 1 days;
        Buyer storage trader = traderProfile[_user];
        //log start time and unlock time
        trader.startEpoch = uint32(poolEpoch);
        trader.startTime = uint64(block.timestamp);
        trader.timeUnlock = uint64(block.timestamp + (_lockTime / 1 days) * 1 days);
        trader.tokensLocked += uint128(_amount);
        tokensLocked += _amount;
    }

    /// @notice lock *more* tokens
    /** 
    @dev if a user purchases tokens and they've already locked some amount of tokens, addTokens is called.
    This updates the final credit balance that a user will converge on based on how much is being added 
    to the locked balance and the length of time left on the lockup.
    */
    /// @param _user the user that is locking tokens
    /// @param _amount the amount of tokens being locked 
    function addTokens(address _user, uint256 _amount) internal {

        //make sure there are already tokens locked and position hasn't matured
        Buyer storage trader = traderProfile[_user];
        require(trader.tokensLocked != 0 && trader.timeUnlock > block.timestamp);
        
        //mint and lock tokens
        trader.tokensLocked += uint128(_amount);
        tokensLocked += _amount;
    }

    /// @notice unlock tokens
    /** 
    @dev users can only unlock tokens once their unlock time is up. Upon unlocking tokens the ENTIRE position
    is closed. All locked tokens are burned, user makes decisions regarding credits via the sellTokens.
    */
    /// @param _user the user that whos tokens are unlocking
    function unlockTokens(address _caller, address _user) internal {

        //make sure position has matured
        Buyer storage trader = traderProfile[_user];
        require(block.timestamp >= trader.timeUnlock);

        uint256 amountTokensLocked = trader.tokensLocked;
        uint256 _salePrice = (amountTokensLocked * 0.001 ether / 1e18);
        uint256 amountCreditsDesired = 
            (payoutRatioAdjusted[_user] ? trader.creditPurchasePercentage : 1_000) * trader.finalCreditCount / 1_000;
        uint256 cost = 
            (payoutRatioAdjusted[_user] ? trader.creditPurchasePercentage : 1_000) * amountTokensLocked * 0.001 ether / 1_000e18;
        uint256 mod;
        if(emissionsStarted) mod = 1;

        if(!emissionsStarted) {
            amountCreditsDesired = 0;
            cost = 0;
        }

        // update claim amount for msg.sender and nft owner
        factory.updatePendingReturns{ 
            value:25 * (_salePrice - cost) / 10_000
        } ( _caller );
        factory.updatePendingReturns{ 
            value:mod * cost / 100
        } ( creator );

        /// send revenue to veABC holders and treasury
        veAbc.receiveFees{value: (100 - mod - controller.treasuryRate()) * cost / 100}();
        payable(controller.abcTreasury()).transfer(controller.treasuryRate() * cost / 100);

        _salePrice -= 25 * (_salePrice - cost) / 10_000;

        //return remaining funds to seller
        factory.updatePendingReturns{ 
            value:_salePrice - cost
        } ( _user );

        //update user credit count in vault
        epochVault.updateEpoch(address(heldCollection), _user, amountCreditsDesired);

        //unlock and burn tokens
        tokensLocked -= amountTokensLocked;

        //reset buyer position
        delete trader.timeUnlock;
        delete trader.startTime;
        delete trader.finalCreditCount;
        delete trader.tokensLocked;
    }

    /// @notice internal function to execute a pending order atomically upon sale
    function executePending(address _caller, address _user, uint256 ticketId, uint256 amountTokensOwned) internal {
        if(poolClosed) {
            factory.updatePendingReturns{ 
                value:amountTokensOwned * 0.001 ether / 1e18
                    + pendingOrder[_user][ticketId].executorReward
            } ( pendingOrder[_user][ticketId].buyer );
        }
        else {
            // execute token purchase on behalf of highest bidder
            this.purchase(
                _caller, 
                pendingOrder[_user][ticketId].buyer, 
                pendingOrder[_user][ticketId].ticket,
                pendingOrder[_user][ticketId].amount, 
                pendingOrder[_user][ticketId].finalEpoch
            );

            pendingOrder[_user][ticketId].ticket.pop();
            pendingOrder[_user][ticketId].amount.pop();

            // send executor reward to the caller
            payable(_caller).transfer(pendingOrder[_user][ticketId].executorReward);
        }

        // delete pending order
        delete pendingOrder[_user][ticketId];
    }

    /// @notice charge abc network fee
    function takePayment(address _user) internal {
        uint256 gas = controller.abcGasFee();
        abcToken.bypassTransfer(_user, controller.epochVault(), gas);
        epochVault.receiveAbc(gas);
    }

    /* ======== GETTER ======== */

    function getEpoch(uint256 _time) view external returns(uint256) {
        return (_time - startTime) / 1 days; 
    }

    function getNonce() view external returns(uint256) {
        return MAPoolNonce;
    }

    function getPayoutPerRes(uint256 epoch) view external returns(uint256) {
        return payoutPerRes[epoch];
    }

    /// @notice return a users nominal token count per epoch
    function getNominalTokensPerEpoch(address _user, uint256 _epoch) view external returns(uint256) {
        return traderProfile[_user].nominalTokensPerEpoch[_epoch];
    }

    /// @notice return a users full list of tickets held
    function getListOfTickets(address _user) view external returns(uint256[] memory) {
        return traderProfile[_user].listOfTickets;
    }
    
    ///TODO: add in unlock epoch to be returned
    /// @notice returns user tokens owned in a ticket and shows pending offer information
    /// @param _user user of interest
    /// @param _ticket ticket of interest 
    /// @return tokensOwnedPerTicket tokens currently owned in at ticket by _user
    /// @return currentBribe size of the bribe for that position
    /// @return ticketQueued whether there is currently a queued ticket
    /// @return buyer highest bidder to take over that position
    function getPendingInfo(
        address _user, 
        uint256 _ticket
    ) view external returns(uint256 tokensOwnedPerTicket, uint256 currentBribe, bool ticketQueued, address buyer) {
        Buyer storage trader = traderProfile[_user];
        tokensOwnedPerTicket = trader.ticketsOwned[_ticket];
        currentBribe = pendingOrder[_user][_ticket].executorReward;
        ticketQueued = pendingOrder[_user][_ticket].ticketQueued;
        buyer = pendingOrder[_user][_ticket].buyer;
    }

    /// @notice returns how many tokens are locked and when they unlock
    /// @param _user user of interest
    function getUserPositionInfo(address _user) view external returns(uint256 lockedTokens, uint256 timeUnlock) {
        Buyer storage trader = traderProfile[_user];
        lockedTokens = trader.tokensLocked;
        timeUnlock = trader.timeUnlock;
    }

    function getUnlockInfo(uint256 _epoch) view external returns(uint256 amountUnlocked, uint256 unlockTime) {
        amountUnlocked = unlockSizePerEpoch[_epoch];
        unlockTime = _epoch * 1 days + startTime;
    }

    /// @notice return a users chosen payout ratio
    function getPayoutRatio(address _user) view external returns(uint256 payoutRatio) {
        Buyer storage trader = traderProfile[_user];
        payoutRatio = payoutRatioAdjusted[_user] ? trader.creditPurchasePercentage : 1_000;
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}