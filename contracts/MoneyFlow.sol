//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Vault } from "./Vault.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MoneyFlow {

    AbacusController public controller;

    mapping(address => mapping(address => uint256)) public tokenBalances;

    event PendingReturnsUpdated(address _user, address _token, uint256 _amount);

    constructor(
        address _controller
    ) {
        controller = AbacusController(_controller);
    }

    function receiveLiquidity(
        address _sender,
        uint256 _amount
    ) external {
        require(
            controller.accreditedAddresses(msg.sender)
            , "Not a pool"
        );
        Vault(msg.sender).token().transferFrom(_sender, address(this), _amount);
    }

    function returnLiquidity(
        address _recipient,
        uint256 _amount
    ) external {
        require(
            controller.accreditedAddresses(msg.sender)
            , "Not a pool"
        );
        Vault(msg.sender).token().transfer(_recipient, _amount);
    }

    function routBorrow(
        address _borrower,
        address _currency,
        uint256 _amount
    ) external {
        require(
            msg.sender == controller.lender()
            , "Caller not lender"
        );
        ERC20(_currency).transfer(_borrower, _amount);
    }

    function serviceBorrow(
        address _borrower,
        address _currency,
        uint256 _amount
    ) external {
        require(
            msg.sender == address(controller.lender())
            , "Caller not lender"
        );
        ERC20(_currency).transferFrom(_borrower, address(this), _amount);
    }

    function payoutSaleClosure(
        address _recipient,
        address _currency,
        uint256 _amount
    ) external {
        require(
            msg.sender == address(controller.handler())
            , "Caller not handler"
        );
        ERC20(_currency).transfer(_recipient, _amount);
    }

    function processFees(
        address _sender,
        address _currency,
        address[] calldata _pools,
        uint256[] calldata _fees
    ) external {
        require(
            controller.accreditedAddresses(msg.sender)
            || msg.sender == controller.lender()
            , "Not a pool or the protocol lender"
        );
        uint256 totalFees;
        for(uint256 i = 0; i < _pools.length; i++) {
            Vault vault = Vault(_pools[i]);
            uint256 fee = _fees[i];
            tokenBalances[vault.creator()][_currency] += vault.creatorFee() * fee / 1000;
            vault.processFees((950 - vault.creatorFee()) * fee / 1000);
            totalFees += fee;
        }
        ERC20(_currency).transferFrom(_sender, address(this), totalFees);
        ERC20(_currency).transfer(controller.multisig(), 5 * totalFees / 100);
    }

    function updatePendingReturns(
        address _token, 
        address _user, 
        uint256 _amount
    ) external nonReentrant {
        require(
            controller.accreditedAddresses(msg.sender)
            || msg.sender == address(controller.auction())
            , "Not a pool"
        );
        tokenBalances[_user][_token] += _amount;
        emit PendingReturnsUpdated(_user, _token, _amount);
    }

    function withdrawFunds(
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external nonReentrant {
        require(
            _tokens.length == _amounts.length
            , "Improper input"
        );
        for(uint256 i = 0; i < _tokens.length; i++) {
            require(
                tokenBalances[msg.sender][_tokens[i]] >= _amounts[i]
                , "Amount too high"
            );
            tokenBalances[msg.sender][_tokens[i]] -= _amounts[i];
            ERC20(_tokens[i]).transfer(msg.sender, _amounts[i]);
        }
    }
}