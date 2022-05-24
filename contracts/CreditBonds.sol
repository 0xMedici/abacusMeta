//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { ABCToken } from "./AbcToken.sol";
import { IVault } from "./interfaces/IVault.sol";
import { IEpochVault } from "./interfaces/IEpochVault.sol";
import { IVeAbc } from "./interfaces/IVeAbc.sol";

import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract CreditBonds is ReentrancyGuard {

    /// @notice protocol directory
    AbacusController public controller;

    /// @notice modVal set to 1 after the 0th epoch begins
    uint256 public modVal;

    /// @notice total ETH credits bonded per epoch
    mapping(uint256 => uint256) public totalCreditPerEpoch;

    /// @notice a users final ETH credit bonded in an epoch (fixed after epoch)
    mapping(uint256 => mapping(address => uint256)) public finalUserCredit;

    /// @notice a users ETH credit bonded in an epoch (also tracks residual credit when spending)
    mapping(uint256 => mapping(address => uint256)) public userCredit;

    /// @notice allow another user to spend ETH credit 
    mapping(uint256 => mapping(address => mapping(address => uint256))) public transferAllowance;

    event AddCredit(address _user, uint256 _amount);
    event BondEth(address _user, uint256 _epoch, uint256 _amount, uint256 _totalAmountBonded);
    event PurchaseTokensSingle(address _vault, address _user, uint256 _epoch, uint256 _ticket, uint256 _amount);
    event PurchaseTokensMulti(address _vault, address _user, uint256 _epoch, uint256[] tickets, uint256[] amounts);

    constructor(address _controller) {
        controller = AbacusController(_controller);
    }

    /// @notice used to trigger modVal when Abacus begins
    function begin() nonReentrant external {
        require(msg.sender == controller.epochVault());
        modVal = 1;
    }

    /// @notice give an address an allowance to spend your credits on your behalf in pools
    function allowTransferAddress(address allowee, uint256 allowance) external {
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch() + modVal;

        /// gib allowance to second address to spend credits on behalf of msg.sender
        transferAllowance[currentEpoch][msg.sender][allowee] += allowance;
    }

    /// @notice clears any unused bond money to veABC holders after an epoch concludes
    function clearUnusedBond(uint256 _epoch) nonReentrant external {
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch() + modVal;

        /// req that the epoch which is being called to clear is not later than the current bonding epoch
        require(_epoch < currentEpoch - modVal);

        /// send 0.5% of total cleared funds to the caller 
        payable(msg.sender).transfer(5 * totalCreditPerEpoch[_epoch] / 1000);

        /// send 99.5% of total cleared funds to veABC holders
        IVeAbc(controller.veAbcToken()).donateToEpoch{ value: 995 * totalCreditPerEpoch[_epoch] / 1000 }(currentEpoch - modVal);
    }

    /// @notice bond ETH in exchange for credit bonded ETH 
    function bond() nonReentrant payable external {
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch() + modVal;

        /// log bonded credits
        userCredit[currentEpoch][msg.sender] += msg.value;
        finalUserCredit[currentEpoch][msg.sender] += msg.value;
        totalCreditPerEpoch[currentEpoch] += msg.value;

        /// update the users bond boost
        IVeAbc(controller.veAbcToken()).updateVeSize(msg.sender, currentEpoch);
        emit BondEth(msg.sender, currentEpoch, msg.value, finalUserCredit[currentEpoch][msg.sender]);
    }
    
    /// @notice allows pools to route bonded ETH to fill trade cost automatically
    function sendToVault(address _caller, address _vault, address _user, uint256 _amount) external returns(uint256){

        /// only callable by accredited addresses
        require(controller.accreditedAddresses(msg.sender));
        uint256 currentEpoch = IEpochVault(controller.epochVault()).getCurrentEpoch() + modVal;
        uint256 payload;

        /// if the caller is not the user their allowance is checked and spent  
        if(_caller != _user) {
            if(transferAllowance[currentEpoch][_user][_caller] < _amount) {
                payload = transferAllowance[currentEpoch][_user][_caller];
                transferAllowance[currentEpoch][_user][_caller] = 0;
            }
            else {
                payload = _amount;
                transferAllowance[currentEpoch][_user][_caller] -= _amount;
            }
            payable(_vault).transfer(payload);
            return payload;
        }

        if(_amount >= userCredit[currentEpoch - 1][_user]) {
            payload = userCredit[currentEpoch - 1][_user];
            userCredit[currentEpoch - 1][_user] = 0;
        }
        else {
            payload = _amount;
            userCredit[currentEpoch - 1][_user] -= _amount;
        }

        /// payload is delivered to the vault 
        payable(_vault).transfer(payload);
        return payload;
    }

    /// @notice get a users personal boost in an epoch 
    function getPersonalBoost(address _user, uint256 epoch) view external returns(uint256) {
        if(finalUserCredit[epoch][_user] >= controller.bondMaxPremiumThreshold()) return 10_000;
        return 10_000 * finalUserCredit[epoch][_user] / controller.bondMaxPremiumThreshold();
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}
}