//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNft is ERC721{ 

    uint256 public id;

    constructor() ERC721("Test NFT", "TSTN") {
        _mint(msg.sender, id + 1);
    }

    function mintNew() external {
        id++;
        _mint(msg.sender, id + 1);
    }
}