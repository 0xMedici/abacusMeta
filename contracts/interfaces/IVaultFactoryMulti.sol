//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVaultFactoryMulti {

    function initiateMultiAssetVault(address _nft, uint256[] memory _id) payable external;

    function signMultiAssetVault(uint256 multiVaultNonce, address nft, uint256[] memory id) external;

    function executeMultiAssetVaultCreation(string memory _name, string memory _symbol, uint256 multiVaultNonce) external;

    function updateNftInUse(
        address nftToRemove,
        uint256 idToRemove,
        uint256 multiVaultNonce
    ) external returns(uint256[] memory newIds);

    function updatePendingReturns(address _user) payable external;

    function getIdPresence(address nft, uint256 id) view external returns(bool);
}