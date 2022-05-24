//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVaultMulti {

    function initialize(
        IERC721 _heldTokenCollection,
        uint256[] memory _heldTokenIds,
        uint256 _vaultVersion,
        uint256 slots,
        uint256 nonce,
        address _creator,
        address _controller,
        address closePoolImplementation_
    ) external;
    
    function adjustPayoutRatio(uint256 _creditPurchasePercentage) external;

    function startEmission() external;

    function purchase(
        address _caller,
        address _buyer, 
        uint256[] memory tickets, 
        uint256[] memory amountPerTicket, 
        uint256 finalEpoch
    ) payable external;

    function sell(address _user) external;

    function createPendingOrder(
        address _targetPositionHolder,
        address _buyer,
        uint256 ticket,
        uint256 lockTime,
        uint256 executorReward
    ) payable external;

    function offerGeneralInterest(uint256 startEpoch, uint256 endEpoch) payable external;

    function offerConcentratedInterest(
        uint256 startEpoch, 
        uint256 endEpoch, 
        uint256[] memory concentratedTranches
    ) payable external;

    function restore(uint256[] memory id) external returns(bool);

    function reserve(uint256 id, uint256 reservationLength) external;

    function closeNft(uint256 id) external;

    function adjustTicketInfo(
        address _user,
        uint256 _finalNftVal,
        uint256 _id
    ) external returns(bool complete);

    function closePool() external;

    function updateRestorationNonce() external;

    function updateAvailFunds(uint256 _id, uint256 _saleValue) external;

    function getNonce() view external returns(uint256);

    function getAvailableCredits(address _user) view external returns(uint256);

    function getNominalTokensPerEpoch(address _user, uint256 _epoch) view external returns(uint256);

    function getListOfTickets(address _user) view external returns(uint256[] memory);

    function getClosePoolContract() view external returns(address contractAddress);

    function getPendingInfo(
        address _user, 
        uint256 _ticket
    ) view external returns(uint256 tokensOwnedPerTicket, uint256 currentBribe, bool ticketQueued, address buyer);

}