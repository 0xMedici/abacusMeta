//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Vault } from "./Vault.sol";
import "hardhat/console.sol";

contract TrancheCalculator {

    AbacusController controller;

    mapping(uint256 => bytes4) public operations;
    mapping(address => uint256) public computation;
    mapping(address => bytes4) public customSelector;
    mapping(uint256 => mapping(uint256 => uint256)) public outputStorage;

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
        uint256[] calldata ops
    ) external {
        require(ops.length < 28, "Too many ops");
        // require(controller.accreditedAddresses(msg.sender));
        computation[msg.sender] = this.getComputationBitString(ops);
    }

    function calculateBound(uint256 _ticket) external returns(uint256 bound) {
        if(outputStorage[computation[msg.sender]][_ticket] != 0) {
            return outputStorage[computation[msg.sender]][_ticket] * Vault(msg.sender).modTokenDecimal();
        }
        uint256 tranche = _ticket;
        uint256 computationPath = computation[msg.sender];
        while(computationPath > 0) {
            uint256 val1 = computationPath & (2**9 - 1);
            computationPath >>= 9;
            if(val1 == 8) {
                (val1, computationPath) = this.executeCalculation(
                    tranche,
                    computationPath
                );
            } else if(val1 == 0) {
                val1 = bound;
            } else if(val1 == 10) {
                val1 = tranche;
            } else if(val1 > 10) {
                val1 -= 10;
            }
            uint256 operation = computationPath & (2**9 - 1);
            computationPath >>= 9;
            uint256 val2 = computationPath & (2**9 - 1);
            computationPath >>= 9;
            if(val2 == 8) {
                (val2, computationPath) = this.executeCalculation(
                    tranche,
                    computationPath
                );
            } else if(val2 == 0) {
                val2 = bound;
            } else if(val2 == 10) {
                val2 = tranche;
            } else if(val2 > 10) {
                val2 -= 10;
            }
            bytes memory data = abi.encodeWithSelector(operations[operation], val1, val2);
            (, bytes memory returnData) = (address(this)).call(data);
            assembly {
                bound := mload(add(returnData, add(0x20, 0)))
            }
        }
        outputStorage[computation[msg.sender]][_ticket] = bound;
        bound *= Vault(msg.sender).modTokenDecimal();
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

    function executeCalculation(
        uint256 _tranche,
        uint256 _computationPath
    ) external returns(uint256 mainValue, uint256 computationPath) {
        computationPath = _computationPath;
        uint256 val1;
        uint256 val2;
        uint256 operation;
        while(operation != 9) {
            val1 = computationPath & (2**9 - 1);
            computationPath >>= 9;
            if(val1 == 8) {
                (val1, computationPath) = this.executeCalculation(
                    _tranche,
                    computationPath
                );
            } else if(val1 == 0) {
                val1 = mainValue;
            } else if(val1 == 9) {
                break;
            } else if(val1 == 10) {
                val1 = _tranche;
            } else {
                val1 -= 10;
            }
            operation = computationPath & (2**9 - 1);
            computationPath >>= 9;
            val2 = computationPath & (2**9 - 1);
            computationPath >>= 9;
            if(val2 == 8) {
                (val2, computationPath) = this.executeCalculation(
                    _tranche,
                    computationPath
                );
            } else if(val2 == 0) {
                val2 = mainValue;
            } else if(val2 == 9) {
                break;
            } else if(val2 == 10) {
                val2 = _tranche;
            } else {
                val2 -= 10;
            }
            bytes memory data = abi.encodeWithSelector(operations[operation], val1, val2);
            (, bytes memory returnData) = (address(this)).call(data);
            assembly {
                mainValue := mload(add(returnData, add(0x20, 0)))
            }
        }
    }

    function getComputationBitString(
        uint256[] calldata ops
    ) external pure returns (uint256 bitString) {
        uint256 length = ops.length;
        uint256 parenthesisBalance;
        for(uint256 i = 0; i < length; i++) {
            bitString <<= 9;
            bitString |= ops[i];
            if(ops[i] == 8) {
                parenthesisBalance--;
            } else if(ops[i] == 9) {
                parenthesisBalance++;
            }
        }
        require(parenthesisBalance == 0);
    }

    function mockCalculation(address _caller, uint256 _ticket) external returns(uint256 bound) {
        if(outputStorage[computation[_caller]][_ticket] != 0) {
            return outputStorage[computation[_caller]][_ticket];
        }
        uint256 tranche = _ticket;
        uint256 computationPath = computation[_caller];

        while(computationPath > 0) {
            uint256 val1 = computationPath & (2**9 - 1);
            computationPath >>= 9;
            if(val1 == 8) {
                (val1, computationPath) = this.executeCalculation(
                    tranche,
                    computationPath
                );
            } else if(val1 == 0) {
                val1 = bound;
            } else if(val1 == 10) {
                val1 = tranche;
            } else if(val1 > 10) {
                val1 -= 10;
            }
            uint256 operation = computationPath & (2**9 - 1);
            computationPath >>= 9;
            uint256 val2 = computationPath & (2**9 - 1);
            computationPath >>= 9;
            if(val2 == 8) {
                (val2, computationPath) = this.executeCalculation(
                    tranche,
                    computationPath
                );
            } else if(val2 == 0) {
                val2 = bound;
            } else if(val2 == 10) {
                val2 = tranche;
            } else if(val2 > 10) {
                val2 -= 10;
            }
            bytes memory data = abi.encodeWithSelector(operations[operation], val1, val2);
            (, bytes memory returnData) = (address(this)).call(data);
            assembly {
                bound := mload(add(returnData, add(0x20, 0)))
            }
        }
        bound *= Vault(_caller).modTokenDecimal();
    }
}