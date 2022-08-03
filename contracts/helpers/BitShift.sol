//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

library BitShift {
    function bitShift(
        uint256[] memory tickets, 
        uint256[] memory amountPerTicket
    ) internal pure returns(uint256 comTickets, uint256 comAmounts, uint256 largestTicket, uint256 base) {
        uint256 length = tickets.length;
        for(uint256 i = 0; i < length; i++) {
            if(tickets[i] > largestTicket) largestTicket = tickets[i];
            comTickets <<= 25;
            comAmounts <<= 25;
            comTickets |= tickets[i];
            comAmounts |= amountPerTicket[i] * 100;
            base += amountPerTicket[i] * 0.001 ether;
        }
    }
}