//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVault {
    function initialize(
        IERC721 _heldTokenCollection,
        uint256 _heldTokenIds,
        uint256 _vaultVersion,
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

    function sell(
        address _user 
    ) external;

    function createPendingOrder(
        address _targetPositionHolder,
        address _buyer,
        uint256 ticket,
        uint256 finalEpoch,
        uint256 executorReward
    ) payable external;

    function offerGeneralBribe(uint256 bribePerEpoch, uint256 startEpoch, uint256 endEpoch) payable external;

    function offerConcentratedBribe(
        uint256 startEpoch, 
        uint256 endEpoch, 
        uint256[] memory tickets,
        uint256[] memory bribePerTicket
    ) payable external;

    function closeNft() external;

    function adjustTicketInfo(
        address _user,
        uint256 _finalNftVal
    ) external returns(bool complete);

    function getClosePoolContract() view external returns(address);

    function getNominalTokensPerEpoch(address _user, uint256 _epoch) view external returns(uint256);

    function getListOfTickets(address _user) view external returns(uint256[] memory);

    function getPendingInfo(
        address _user, 
        uint256 _ticket
    ) view external returns(uint256 tokensOwnedPerTicket, uint256 currentBribe, bool ticketQueued, address buyer);

    function getUserPositionInfo(address _user) view external returns(uint256 lockedTokens, uint256 timeUnlock);

    function getPayoutRatio(address _user) view external returns(uint256 payoutRatio);

}
