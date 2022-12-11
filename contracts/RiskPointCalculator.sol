//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import "hardhat/console.sol";

contract RiskPointCalculator {

    AbacusController controller;

    mapping(uint256 => bytes4) public operations;
    mapping(address => uint256) public computation;
    mapping(address => address) public customComputationContract;
    mapping(address => bytes4) public customSelector;

    constructor(
        address _controller
    ) {
        controller = AbacusController(_controller);
        operations[1] = RiskPointCalculator(address(this)).add.selector;
        operations[2] = RiskPointCalculator(address(this)).sub.selector;
        operations[3] = RiskPointCalculator(address(this)).mul.selector;
        operations[4] = RiskPointCalculator(address(this)).div.selector;
        operations[5] = RiskPointCalculator(address(this)).exp.selector;
        operations[6] = RiskPointCalculator(address(this)).mod.selector;
        operations[7] = RiskPointCalculator(address(this)).sqrt.selector;
    }

    function setMetrics(
        uint256[] calldata val,
        uint256[] calldata op,
        address _customComputationContract
    ) external {
        require(val.length < 20);
        require(controller.accreditedAddresses(msg.sender));
        computation[msg.sender] = this.getComputationBitString(val, op);
        customComputationContract[msg.sender] = _customComputationContract;
    }

    function findRiskMultiplier(uint256 ticket) external returns(uint256 riskPointsPerToken) {
        uint256 computationPath = computation[msg.sender];
        if(computationPath == 8) {
            riskPointsPerToken = this.custom(msg.sender, ticket);
            return riskPointsPerToken;
        }
        while(computationPath > 0) {
            uint256 val = computationPath & (2**9 - 1);
            computationPath >>= 9;
            uint256 operation = computationPath & (2**3 - 1);
            computationPath >>= 3;
            bytes memory dataRisk = abi.encodeWithSelector(operations[operation], ticket, val);
            (, bytes memory returnRisk) = (address(this)).call(dataRisk);
            assembly {
                riskPointsPerToken := mload(add(returnRisk, add(0x20, 0)))
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

    function custom(address _caller, uint256 _ticket) external returns (uint256 riskPointsPerToken) {
        bytes memory dataRisk = abi.encodeWithSelector(customSelector[_caller], _ticket);
        (, bytes memory returnRisk) = (customComputationContract[_caller]).call(dataRisk);
        assembly {
            riskPointsPerToken := mload(add(returnRisk, add(0x20, 0)))
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