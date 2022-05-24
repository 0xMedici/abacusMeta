//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Vault } from "./Vault.sol";
import { IVault } from "./interfaces/IVault.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract TestOwner {
    function getContractBalance() view external returns(uint256 balance){
        balance = address(this).balance;
    }

    function approveNft(address toApprove, address token, uint256 id) external {
        IERC721(token).approve(toApprove, id);
    }
    
    function closeVault(address _vault) external {
        IVault(payable(_vault)).closeNft();
    }

    receive() external payable {}
    fallback() external payable {}
}