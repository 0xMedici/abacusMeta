//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockToken is ERC20{ 

    constructor() ERC20("Test Token", "TSTT") {}

    function mint() external {
        _mint(msg.sender, 1_000_000_000_000_000e18);
    }
}