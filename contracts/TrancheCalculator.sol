//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import "hardhat/console.sol";

contract TrancheCalculator {

    AbacusController controller;

    mapping(uint256 => bytes4) public operations;
    mapping(address => uint256) public computation;
    mapping(address => address) public customComputationContract;
    mapping(address => bytes4) public customSelector;

    constructor(
        address _controller
    ) {
        controller = AbacusController(_controller);
        operations[1] = TrancheCalculator(address(this)).add.selector;
        operations[2] = TrancheCalculator(address(this)).sub.selector;
        operations[3] = TrancheCalculator(address(this)).mul.selector;
        operations[4] = TrancheCalculator(address(this)).div.selector;
        operations[5] = TrancheCalculator(address(this)).exp.selector;
        operations[6] = TrancheCalculator(address(this)).mod.selector;
        operations[7] = TrancheCalculator(address(this)).sqrt.selector;
    }

    function setMetrics(
        uint256[] calldata val,
        uint256[] calldata op
    ) external {
        require(val.length < 20);
        require(controller.accreditedAddresses(msg.sender));
        computation[msg.sender] = this.getComputationBitString(val, op);
    }

    function findBounds(uint256 ticket, uint256 ticketSize) external returns(uint256 lowerBound, uint256 upperBound) {
        lowerBound = ticket * ticketSize;
        upperBound = (ticket + 1) * ticketSize;
        uint256 computationPath = computation[msg.sender];
        if(computationPath == 8) {
            this.custom(msg.sender, lowerBound, upperBound);
        }
        while(computationPath > 0) {
            uint256 val = computationPath & (2**9 - 1);
            computationPath >>= 9;
            uint256 operation = computationPath & (2**3 - 1);
            computationPath >>= 3;
            bytes memory dataLower = abi.encodeWithSelector(operations[operation], lowerBound, val);
            bytes memory dataUpper = abi.encodeWithSelector(operations[operation], upperBound, val);
            (, bytes memory returnLower) = (address(this)).call(dataLower);
            (, bytes memory returnUpper) = (address(this)).call(dataUpper);
            assembly {
                lowerBound := mload(add(returnLower, add(0x20, 0)))
                upperBound := mload(add(returnUpper, add(0x20, 0)))
            }
        }
    }

    function add(uint256 x, uint256 y) external pure returns(uint256) {
        return x + y;
    }

    function sub(uint256 x, uint256 y) external pure returns(uint256) {
        return x - y; 
    }

    function mul(uint256 x, uint256 y) external pure returns(uint256) {
        return x * y;
    }

    function div(uint256 x, uint256 y) external pure returns(uint256) {
        return x / y;
    }

    function exp(uint256 x, uint256 y) external pure returns(uint256) {
        return x ** y;
    }

    function mod(uint256 x, uint256 y) external pure returns(uint256) {
        return x % y;
    }

    function sqrt(uint256 x, uint256 y) external pure returns (uint256 a) {
        uint z = (x + 1) / 2;
        a = x;
        while (z < a) {
            a = z;
            z = (x / z + z) / 2;
        }
    }

    function custom(address _caller, uint256 _lowerBound, uint256 _upperBound) external returns (uint256 lowerBound, uint256 upperBound) {
        bytes memory dataLower = abi.encodeWithSelector(customSelector[_caller], _lowerBound);
        bytes memory dataUpper = abi.encodeWithSelector(customSelector[_caller], _upperBound);
        (, bytes memory returnLower) = (customComputationContract[_caller]).call(dataLower);
        (, bytes memory returnUpper) = (customComputationContract[_caller]).call(dataUpper);
        assembly {
            lowerBound := mload(add(returnLower, add(0x20, 0)))
            upperBound := mload(add(returnUpper, add(0x20, 0)))
        }
    }

    function getComputationBitString(
        uint256[] calldata val,
        uint256[] calldata op
    ) external pure returns (uint256 bitString) {
        uint256 length = val.length;
        for(uint256 i = 0; i < length; i++) {
            bitString <<= 3;
            bitString |= val[i];
            bitString <<= 9;
            bitString |= op[i];
        }

    }
}