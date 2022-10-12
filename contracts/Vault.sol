//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Closure } from "./Closure.sol";
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

    /* ======== ADDRESS ======== */
    IFactory factory;
    AbacusController controller;
    address creator;
    address private _closePoolMultiImplementation;

    /// @notice Address of the deployed closure contract
    address public closePoolContract;

    /* ======== STRING ======== */
    string name;

    /* ======== UINT ======== */
    uint256 amountNftsLinked;

    uint256 public epochLength;

    /// @notice Interest rate that the pool charges for usage of liquidity
    uint256 public interestRate;

    uint256 public reservations;

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
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) payoutInfo;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) auctionSaleValue;

    /// @notice Compressed version of: totalTokensPurchased, totalRiskPoints, payoutPerRes, totAvailFunds
    mapping(uint256 => uint256) public compressedEpochVals;

    /// @notice A users position nonce
    /// [address] -> User address
    /// [uint256] -> Next nonce value 
    mapping(address => uint256) public positionNonce;

    /// @notice Payout size for each reservation during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> payout size
    mapping(uint256 => uint256) public epochEarnings;

    /// @notice Track an addresses allowance status to trade another addresses position
    /// [address] allowance recipient
    mapping(address => address) public allowanceTracker;

    /// @notice Tracks the amount of liquidity that has been accessed on behalf of an NFT
    /// [address] -> NFT collection address
    /// [uint256] -> NFT ID
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

    /// @notice Track adjustment status of closed NFTs
    /// [address] -> User 
    /// [uint256] -> nonce
    /// [address] -> NFT collection
    /// [uint256] -> NFT ID
    /// [bool] -> Status of adjustment
    mapping(address => mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => bool))))) public adjustCompleted;
    
    /* ======== STRUCTS ======== */
    /// @notice Holds core metrics for each trader
    /// [active] -> track if a position is closed
    /// [multiplier] -> the multiplier applied to a users credit intake when closing a position
    /// [startEpoch] -> epoch that the position was opened
    /// [unlockEpoch] -> epoch that the position can be closed
    /// [comListOfTickets] -> compressed (using bit shifts) value containing the list of tranches
    /// [comAmountPerTicket] -> compressed (using bit shifts) value containing the list of amounts
    /// of tokens purchased in each tranche
    /// [ethLocked] -> total amount of eth locked in the position
    struct Buyer {
        bool active;
        uint32 startEpoch;
        uint32 unlockEpoch;
        uint32 riskStart;
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
        string memory _name,
        address _controller,
        address closePoolImplementation_,
        address _creator
    ) external initializer {
        controller = AbacusController(_controller);
        factory = IFactory(controller.factory());

        creator = _creator;
        name = _name;
        _closePoolMultiImplementation = closePoolImplementation_;
        adjustmentsRequired = 1;
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== CONFIGURATION ======== */
    /** 
    Error codes:
        AS - Already started
        NC - Not creator
        NO - Not owner
        AM - Already mapped 
    */
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

    /** 
    Error codes:
        AS - Already started
        NC - Not creator
    */
    function begin(
        uint256 _slots, 
        uint256 _ticketSize, 
        uint256 _rate,
        uint256 _epochLength
    ) external payable {
        require(
            _epochLength >= 1 days
            && _epochLength <= 2 weeks
        );
        require(startTime == 0, "AS");
        require(msg.sender == creator, "NC");
        epochLength = _epochLength;
        amountNft = _slots;
        ticketLimit = _ticketSize;
        reservationsAvailable = _slots;
        interestRate = _rate;
        factory.updateSlotCount(name, _slots, amountNftsLinked);
        startTime = block.timestamp;
        factory.emitPoolBegun(_slots, _ticketSize, _rate, _epochLength);
    }

    /* ======== TRADING ======== */
    /** 
    Error codes:
        NS - not started
        II - Improper input
        IT - Improper time
        TS - Too short
        TL - Too long
    */
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
        require(startEpoch == (block.timestamp - startTime) / epochLength, "IT");
        require(finalEpoch - startEpoch > 1, "TS");
        require(finalEpoch - startEpoch <= 10, "TL");
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

    /** 
    Error codes:
        IC - Improper caller
        PC - Position closed
        ANM - Adjustments not made
        PNE - Position non-existent
    */
    function sell(
        address _user,
        uint256 _nonce
    ) external nonReentrant returns(uint256 interestEarned) {
        require(msg.sender == _user, "IC");
        Buyer storage trader = traderProfile[_user][_nonce];
        require(trader.active, "PC");
        require(adjustmentsMade[_user][_nonce] == adjustmentsRequired, "ANM");
        require(trader.unlockEpoch != 0, "PNE");
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        uint256 finalEpoch;
        uint256 interestLost;
        if(poolEpoch >= trader.unlockEpoch) {
            finalEpoch = trader.unlockEpoch;
        } else {
            require(reservations == 0);
            finalEpoch = poolEpoch;
        }
        for(uint256 j = trader.startEpoch; j < finalEpoch; j++) {
            uint256 riskPoints;
            if(j == trader.startEpoch) {
                riskPoints = trader.riskStart;
            } else {
                riskPoints = this.getRiskPoints(j);
            }
            interestLost += trader.riskLost * epochEarnings[j] / riskPoints;
            interestEarned += (trader.riskPoints - trader.riskLost) 
                * epochEarnings[j] / riskPoints;
        }

        if(poolEpoch < trader.unlockEpoch) {
            for(poolEpoch; poolEpoch < trader.unlockEpoch; poolEpoch++) {
                uint256 tempComp = compressedEpochVals[poolEpoch];
                uint256 prevPosition;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 35) - 1) - (2**prevPosition - 1)) 
                        | (
                            (compressedEpochVals[poolEpoch] & (2**35 -1)) 
                            - (trader.ethLocked / 0.001 ether)
                        ); 
                prevPosition += 35;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 51) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 35) & (2**51 -1)) 
                                - trader.riskPoints
                            ) << prevPosition
                        );
                prevPosition += 51;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 86) & (2**84 -1)) 
                                - trader.ethLocked / amountNft
                            ) << prevPosition
                        );
                prevPosition += 84;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 170) & (2**84 -1)) 
                                - trader.ethLocked
                            ) << prevPosition
                        );
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
        delete traderProfile[_user][_nonce].active;
    }

    function updateSaleValue(
        address _nft,
        uint256 _id,
        uint256 _saleValue
    ) external payable nonReentrant {
        require(msg.sender == closePoolContract);
        uint256 poolEpoch = epochOfClosure[closureNonce[_nft][_id]][_nft][_id];
        auctionSaleValue[closureNonce[_nft][_id]][_nft][_id] = _saleValue;
        closureNonce[_nft][_id]++;
        reservationsAvailable++;
        uint256 ppr = payoutInfo[closureNonce[_nft][_id]][_nft][_id] >> 128;
        uint256 propTrack = payoutInfo[closureNonce[_nft][_id]][_nft][_id] & (2**128 - 1);
        while(this.getTotalAvailableFunds(poolEpoch) > 0) {
            uint256 tempComp = compressedEpochVals[poolEpoch];
            uint256 tv = this.getTotalAvailableFunds(poolEpoch);
            uint256 prevPosition = 86;
            tempComp = 
                tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                    | (((tv + _saleValue) / reservationsAvailable) << 86);
            prevPosition += 84;
            if(_saleValue < ppr) {
                tempComp = 
                    tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 170) & (2**84 -1)) 
                                - (ppr - _saleValue) * tv / propTrack
                            ) << prevPosition
                        );
            }
            compressedEpochVals[poolEpoch] = tempComp;
            poolEpoch++;
        }
    }

    /* ======== POSITION MOVEMENT ======== */
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
    function closeNft(address _nft, uint256 _id) external nonReentrant2 returns(uint256) {
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        if(liqAccessed[_nft][_id] == 0) {
            require(reservations < reservationsAvailable);
        } else {
            reservations--;
        }
        adjustmentsRequired++;
        adjustmentNonce[_nft][_id][closureNonce[_nft][_id]] = adjustmentsRequired;
        reservationsAvailable--;
        uint256 ppr = this.getPayoutPerReservation(poolEpoch);
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
        uint256 temp;
        temp |= ppr;
        temp <<= 128;
        temp |= this.getTotalAvailableFunds(poolEpoch);
        payoutInfo[closureNonce[_nft][_id]][_nft][_id] = temp;

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
            block.timestamp > Closure(payable(closePoolContract)).auctionEndTime(
                _closureNonce, 
                _nft, 
                _id
            )
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
            payoutInfo[_closureNonce][_nft][_id] >> 128,
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
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        uint256 payout = msg.value / 20;
        payable(controller.multisig()).transfer(payout);
        epochEarnings[poolEpoch] += msg.value - payout;
    }

    function accessLiq(address _user, address _nft, uint256 _id, uint256 _amount) external {
        require(controller.lender() == msg.sender, "Not accredited");
        if(liqAccessed[_nft][_id] == 0) {
            require(reservations < reservationsAvailable);
            reservations++;
        }
        liqAccessed[_nft][_id] += _amount;
        payable(_user).transfer(_amount);
    }

    function depositLiq(address _nft, uint256 _id) external payable {
        require(controller.lender() == msg.sender, "Not accredited");
        liqAccessed[_nft][_id] -= msg.value;
        if(liqAccessed[_nft][_id] == 0) {
            reservations--;
        }
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
        trader.active = true;
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
        trader.riskStart = 
            uint32(
                riskPoints * (block.timestamp - (block.timestamp - startTime) / epochLength * epochLength)
                    /  epochLength
            );
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
            while(
                ticketsPurchased[j].length == 0 
                || ticketsPurchased[j].length - 1 < largestTicket / 10
            ) ticketsPurchased[j].push(0);
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
                epochTickets[ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1) 
                    - (2**(((ticket % 10))*25) - 1));
                epochTickets[ticket / 10] |= (temp << ((ticket % 10)*25));
                amount += ticketAmounts[i];
            }
            uint256 tempComp = compressedEpochVals[j];
            uint256 prevPosition;
            require(
                (
                    (compressedEpochVals[j] & (2**35 -1)) 
                    + amount
                ) < (2**35 -1)
            );
            tempComp = 
                tempComp & ~((2**(prevPosition + 35) - 1) - (2**prevPosition - 1)) 
                    | ((compressedEpochVals[j] & (2**35 -1)) + amount); 
            prevPosition += 35;
            require(
                (
                    ((compressedEpochVals[j] >> 35) & (2**51 -1)) 
                    + riskPoints
                ) < (2**51 -1)
            );
            tempComp = 
                tempComp & ~((2**(prevPosition + 51) - 1) - (2**prevPosition - 1)) 
                    | (
                        (
                            ((compressedEpochVals[j] >> 35) & (2**51 -1)) 
                            + riskPoints
                        ) << prevPosition
                    );
            prevPosition += 51;
            require(
                (
                    ((compressedEpochVals[j] >> 86) & (2**84 -1)) 
                    + amount * 0.001 ether / amountNft
                ) < (2**84 -1)
            );
            tempComp = 
                tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                    | (
                        (
                            ((compressedEpochVals[j] >> 86) & (2**84 -1)) 
                            + amount * 0.001 ether / amountNft
                        ) << prevPosition
                    );
            prevPosition += 84;
            require(
                (
                    ((compressedEpochVals[j] >> 170) & (2**84 -1)) 
                    + amount * 0.001 ether
                ) < (2**84 -1)
            );
            tempComp = 
                tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                    | (
                        (
                            ((compressedEpochVals[j] >> 170) & (2**84 -1)) 
                            + amount * 0.001 ether
                        ) << prevPosition
                    );
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
        uint256 _payoutAmount = payoutInfo[_closureNonce][_nft][_id] >> 128;
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

    function getName() external view returns(string memory) {
        return name;
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

    function getHeldTokenExistence(address _nft, uint256 _id) external view returns(bool) {
        uint256 temp; 
        temp |= uint160(_nft);
        temp <<= 95;
        temp |= _id;
        return tokenMapping[temp];
    }

    function getTicketInfo(uint256 epoch, uint256 ticket) external view returns(uint256) {
        uint256[] memory epochTickets = ticketsPurchased[epoch];
        if(epochTickets.length <= ticket / 10) {
            return 0;
        }
        uint256 temp = epochTickets[ticket / 10];
        temp &= (2**((ticket % 10 + 1)*25) - 1) - (2**(((ticket % 10))*25) - 1);
        return temp >> ((ticket % 10) * 25);
    }
}