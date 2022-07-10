//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVault {

    function initialize(
        uint256 _vaultVersion,
        uint256 nonce,
        address _controller,
        address closePoolImplementation_,
        address _creator
    ) external;
    
    function toggleEmissions(address _nft, uint256 _id, bool emissionStatus) external;

    function purchase(
        address _caller,
        address _buyer, 
        uint256[] memory tickets, 
        uint256[] memory amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch,
        uint256 nonce
    ) external payable;

    function sell(
        address _user,
        uint256 _nonce,
        uint256 _payoutRatio
    ) external;

    function purchase(
        address _caller,
        address _buyer, 
        uint256[] memory tickets, 
        uint256[] memory amountPerTicket, 
        uint256 startEpoch,
        uint256 finalEpoch
    ) payable external;

    function offerGeneralBribe(
        uint256 bribePerEpoch, 
        uint256 startEpoch, 
        uint256 endEpoch
    ) external payable;

    function offerConcentratedBribe(
        uint256 startEpoch, 
        uint256 endEpoch, 
        uint256[] memory tickets,
        uint256[] memory bribePerTicket
    ) external payable;

    function remove(address _nft, uint256 id) external;

    function updateSaleValue(
        address _nft,
        uint256 _id,
        uint256 _saleValue
    ) external payable;

    function restore() external returns(bool);

    function reserve(address _nft, uint256 id, uint256 endEpoch) external payable;

    function grantTransferPermission(
        address recipient,
        uint256 nonce
    ) external returns(bool);

    function transferFrom(
        address from, 
        address to, 
        uint256 nonce, 
        uint256[] memory _listOfTickets,
        uint256[] memory _amountPerTicket
    ) external returns(bool);

    function closeNft(address _nft, uint256 _id) external;

    function closePool() external;

    function adjustTicketInfo(
        address _user,
        uint256 _nonce,
        uint256 _finalNftVal,
        address _nft,
        uint256 _id
    ) external returns(bool complete);
    
    function getPoolClosedStatus() external view returns(bool);

    function getEpoch(uint256 _time) external view returns(uint256);

    function getNonce() external view returns(uint256);

    function getHeldTokenExistence(address _nft, uint256 _id) external view returns(bool);

    function getAmountOfReservations(
        uint256 _epoch
    ) external view returns(uint256 amountOfReservations);

    function getReservationStatus(
        address nft, 
        uint256 id, 
        uint256 epoch
    ) external view returns(bool);

    function getCostToReserve(uint256 _endEpoch) external view returns(uint256);

    function getTotalFunds(uint256 epoch) external view returns(uint256);

    function getPayoutPerRes(uint256 epoch) external view returns(uint256);

    function getDecodedLPInfo(
        address _user, 
        uint256 _nonce
    ) external view returns(
        uint256 multiplier,
        uint256 unlockEpoch,
        uint256 startEpoch,
        uint256[10] memory tickets, 
        uint256[10] memory amounts
    );

    
}