//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

library BitShift {
    function bitShift(
        uint256 decimals,
        uint256[] memory tickets, 
        uint256[] memory amountPerTicket
    ) internal pure returns(
        uint256 comTickets, 
        uint256 comAmounts, 
        uint256 largestTicket, 
        uint128 base
    ) {
        uint256 length = tickets.length;
        for(uint256 i = 0; i < length; i++) {
            require(tickets[i] < 2**25);
            if(tickets[i] > largestTicket) largestTicket = tickets[i];
            comTickets <<= 25;
            comAmounts <<= 25;
            comTickets |= tickets[i];
            require(amountPerTicket[i] * 100 < (2**25 -1));
            comAmounts |= amountPerTicket[i] * 100;
            base += uint128(amountPerTicket[i] * decimals);
        }
    }
}