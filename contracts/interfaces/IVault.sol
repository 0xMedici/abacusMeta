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

    function includeNft(uint256[] calldata _compTokenInfo) external;

    function begin(uint256 slots) external;

    function purchase(
        address _caller,
        address _buyer, 
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch
    ) external payable;

    function sell(
        address _user,
        uint256 _nonce,
        uint256 _payoutRatio
    ) external;

    function offerGeneralBribe(
        uint256 bribePerEpoch, 
        uint256 startEpoch, 
        uint256 endEpoch
    ) external payable;

    function offerConcentratedBribe(
        uint256 startEpoch,
        uint256 endEpoch,
        uint256[] calldata tickets,
        uint256[] calldata bribePerTicket
    ) external payable;

    function reclaimGeneralBribe(uint256 epoch) external;

    function reclaimConcentratedBribe(uint256 epoch, uint256 ticket) external;

    function remove(address[] calldata _nft, uint256[] calldata _id) external;

    function updateSaleValue(
        address _nft,
        uint256 _id,
        uint256 _saleValue
    ) external payable;

    function restore() external returns(bool);

    function reserve(address _nft, uint256 id, uint256 endEpoch) external payable;

    function changeTransferPermission(
        address recipient,
        uint256 nonce,
        bool permission
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 nonce
    ) external;

    function closeNft(address _nft, uint256 _id) external;

    function closePool() external;

    function adjustTicketInfo(
        address _user,
        uint256 _nonce,
        address _nft,
        uint256 _id,
        uint256 _closureNonce
    ) external returns(bool);

    function getNonce() external view returns(uint256);

    function getHeldTokenExistence(address _nft, uint256 _id) external view returns(bool);

    function getTicketInfo(uint256 epoch, uint256 ticket) external view returns(uint256);

    function getCostToReserve(uint256 _endEpoch) external view returns(uint256);
}