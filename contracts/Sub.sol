//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Position } from "./Position.sol";
import { Vault } from "./Vault.sol";
import { BitShift } from "./helpers/BitShift.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Sub is ReentrancyGuard {

    AbacusController controller;

    /* ======== UINT ======== */
    uint256 public nonce;

    /* ======== MAPPINGS ======== */
    mapping(address => uint256) public gasStored;
    mapping(uint256 => Order) public orderList;
    mapping(address => mapping(address => uint256)) public tokensStored;
    mapping(address => mapping(address => uint256)) public profits;

    /* ======== STRUCTS ======== */
    struct Order {
        bool active;
        address pool;
        address buyer;
        uint256 tickets;
        uint256 amountPerTicket;
        uint256 costOfPurchase;
        uint256 lockTime;
        uint256 gasPerPurchase;
        uint256 gasPerSale;
        uint256 gasPerAdjustment;
        uint256 executionDelay;
        uint256 nextTx;
    }

    /* ======== EVENTS ======== */
    event GasDeposited(address _creator, uint256 _amount);
    event GasWithdrawn(address _creator, uint256 _amount);
    event TokensDeposited(address _creator, address[] _tokens, uint256[] _amounts);
    event TokensWithdrawn(address _creator, address[] _tokens, uint256[] _amounts);
    event SubCreated(
        address _creator, address _pool, uint256 _nonce, 
        uint256[] _tickets, uint256[] _amounts, uint256 _lockTime,
        uint256 _gasPerCall, uint256 _executionDelay
    );
    event PurchaseExecuted(
        address _creator, address _pool, uint256 _nonce, uint256 _positionNonce,
        uint256 _startEpoch, uint256 _endEpoch, uint256 _gasPerPurchase
    );
    event AdjustmentExecuted(
        address _creator, address _pool, uint256 _nonce, 
        uint256 _positionNonce, uint256 _auctionNonce, uint256 _gasPerAdjustment
    );
    event SaleExecuted(
        address _creator, address _pool, uint256 _nonce, 
        uint256 _positionNonce, uint256 _payout, uint256 _lost, uint256 _gasPerSale
    ); 
    event SubCancelled(address _creator, address _pool, uint256 _nonce);

    /* ======== CONSTRUCTOR ======== */
    constructor(address _controller) {
        controller = AbacusController(_controller);
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== SUB PAYMENTS ======== */
    function depositGas() external payable nonReentrant {
        gasStored[msg.sender] += msg.value;
        emit GasDeposited(msg.sender, msg.value);
    }

    function withdrawGas(uint256 _amount) external nonReentrant {
        require(gasStored[msg.sender] >= _amount);
        gasStored[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
        emit GasWithdrawn(msg.sender, _amount);
    }

    function depositTokens(
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external nonReentrant {
        require(_tokens.length == _amounts.length, "Improper input");
        uint256 length = _tokens.length;
        for(uint256 i; i < length; i++) {
            require(ERC20(_tokens[i]).transferFrom(msg.sender, address(this), _amounts[i]), "Transfer failed");
            tokensStored[msg.sender][_tokens[i]] += _amounts[i];
        }
        emit TokensDeposited(msg.sender, _tokens, _amounts);
    }

    function withdrawTokens(
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external nonReentrant {
        require(_tokens.length == _amounts.length);
        uint256 length = _tokens.length;
        for(uint256 i; i < length; i++) {
            require(tokensStored[msg.sender][_tokens[i]] >= _amounts[i]);
            require(ERC20(_tokens[i]).transfer(msg.sender, _amounts[i]));
            tokensStored[msg.sender][_tokens[i]] -= _amounts[i];
        }
        emit TokensWithdrawn(msg.sender, _tokens, _amounts);
    }

    function claimProfits(
        address[] calldata _tokens
    ) external nonReentrant {
        uint256 length = _tokens.length;
        for(uint256 i; i < length; i++) {
            uint256 payout = profits[msg.sender][_tokens[i]];
            delete profits[msg.sender][_tokens[i]];
            ERC20(_tokens[i]).transfer(msg.sender, payout);
        }
    }

    /* ======== SUB CREATION ======== */
    function createOrder(
        address _pool,
        uint256[] calldata _tickets,
        uint256[] calldata _amounts,
        uint256 _lockTime,
        uint256 _gasPerCall,
        uint256 _executionDelay
    ) external {
        require(_pool != address(0), "Zero address entered");
        require(controller.accreditedAddresses(_pool), "Improper pool input");
        require(_tickets.length == _amounts.length, "Improper order input");
        require(_tickets.length <= 10, "Ticket length too long");
        Vault vault = Vault(_pool);
        require(_lockTime / vault.epochLength() >= 1, "Lock time too short");
        require(_lockTime / vault.epochLength() <= 9, "Lock time too long");
        uint256 _nonce = nonce;
        nonce++;
        orderList[_nonce].active = true;
        orderList[_nonce].pool = _pool;
        orderList[_nonce].buyer = msg.sender;
        (orderList[_nonce].tickets, orderList[_nonce].amountPerTicket,,) = BitShift.bitShift(
            vault.modTokenDecimal(),
            _tickets,
            _amounts
        );
        orderList[_nonce].lockTime = _lockTime;
        orderList[_nonce].gasPerPurchase = _gasPerCall & (2**83 - 1);
        orderList[_nonce].gasPerSale = (_gasPerCall >> 83) & (2**83 - 1);
        orderList[_nonce].gasPerAdjustment = (_gasPerCall >> 166) & (2**83 - 1);
        orderList[_nonce].executionDelay = _executionDelay;
        uint256 length = _tickets.length;
        uint256 sum;
        for(uint256 i; i < length; i++) {
            require(_amounts[i] != 0, "Cannot purchase 0 of a tranche");
            sum += _amounts[i] * 10**vault.token().decimals() / 1000;
        }
        orderList[_nonce].costOfPurchase = sum;
        emit SubCreated(
            msg.sender, 
            _pool, 
            _nonce, 
            _tickets, 
            _amounts, 
            _lockTime,
            _gasPerCall,
            _executionDelay
        );
    }

    /* ======== SUB EXECUTION ======== */
    function executePurchaseOrder(
        address _subsidyRecipient,
        uint256 _orderNonce,
        uint256[] calldata _tickets,
        uint256[] calldata _amounts
    ) external nonReentrant {
        Order memory order = orderList[_orderNonce];
        Vault vault = Vault(order.pool);
        address owner = order.buyer;
        require(block.timestamp > order.nextTx, "Too early");
        require(gasStored[owner] >= order.gasPerPurchase, "Avail gas too low");
        require(tokensStored[owner][address(vault.token())] >= order.costOfPurchase, "Avail tokens too low");
        gasStored[owner] -= order.gasPerPurchase;
        tokensStored[owner][address(vault.token())] -= order.costOfPurchase;
        uint256 startEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        uint256 endEpoch = (block.timestamp + order.lockTime - vault.startTime()) / vault.epochLength();
        require(checkPurchaseValidity(
            address(vault),
            _orderNonce,
            _tickets,
            _amounts
        ), "Ticket or amounts input does not match order");
        uint256 positionNonce_ = Position(vault.positionManager()).nonce();
        vault.token().approve(address(vault), order.costOfPurchase);
        vault.purchase(
            address(this),
            _tickets,
            _amounts,
            uint32(startEpoch),
            uint32(endEpoch)
        );
        orderList[_orderNonce].nextTx = block.timestamp + order.executionDelay;
        payable(_subsidyRecipient).transfer(order.gasPerPurchase);
        emit PurchaseExecuted(owner, address(vault), _orderNonce, positionNonce_, startEpoch, endEpoch, order.gasPerPurchase);        
    }

    function executeAdjustmentOrder(
        address _subsidyRecipient,
        uint256 _orderNonce,
        uint256 _positionNonce,
        uint256 _auctionNonce
    ) external nonReentrant {
        Order memory order = orderList[_orderNonce];
        Vault vault = Vault(order.pool);
        address owner = order.buyer;
        require(gasStored[owner] >= order.gasPerAdjustment, "Avail gas too low");
        gasStored[owner] -= order.gasPerAdjustment;
        uint256 payout = vault.adjustTicketInfo(
            _positionNonce,
            _auctionNonce
        );
        tokensStored[owner][address(vault.token())] += payout;
        payable(_subsidyRecipient).transfer(order.gasPerAdjustment);
        emit AdjustmentExecuted(owner, address(vault), _orderNonce, _positionNonce, _auctionNonce, order.gasPerAdjustment);
    }

    function executeSellOrder(
        address _subsidyRecipient,
        uint256 _orderNonce,
        uint256 _positionNonce
    ) external nonReentrant {
        Order memory order = orderList[_orderNonce];
        Vault vault = Vault(order.pool);
        address owner = order.buyer;
        require(gasStored[owner] >= order.gasPerSale, "Avail gas too low");
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        uint256 endEpoch;
        (,endEpoch) = (vault.positionManager()).getPositionTimeline(_positionNonce);
        require(poolEpoch >= endEpoch || msg.sender == owner, "Must be owner or wait till position matures");
        gasStored[owner] -= order.gasPerSale;
        uint256 returned;
        uint256 lost;
        (returned, lost) = vault.sell(
            _positionNonce
        );
        address token = address(vault.token());
        tokensStored[owner][token] += order.costOfPurchase - lost;
        if(returned > (order.costOfPurchase - lost)) {
            profits[owner][token] += returned - (order.costOfPurchase - lost);    
        }
        payable(_subsidyRecipient).transfer(order.gasPerSale);
        emit SaleExecuted(owner, address(vault), _orderNonce, _positionNonce, returned, lost, order.gasPerSale);
    }

    /* ======== SUB MAINTENANCE ======== */
    function cancelOrder(
        uint256 _orderNonce
    ) external nonReentrant {
        require(msg.sender == orderList[_orderNonce].buyer);
        orderList[_orderNonce].active = false;
        emit SubCancelled(orderList[_orderNonce].buyer, orderList[_orderNonce].pool, _orderNonce);
    }

    function checkPurchaseValidity(
        address _pool,
        uint256 _orderNonce,
        uint256[] calldata _tickets,
        uint256[] calldata _amounts
    ) public view returns(bool valid) {
        Vault vault = Vault(_pool);
        uint256 tickets;
        uint256 amounts;
        (tickets, amounts,,) = BitShift.bitShift(
            vault.modTokenDecimal(),
            _tickets,
            _amounts
        );
        valid = (tickets == orderList[_orderNonce].tickets && amounts == orderList[_orderNonce].amountPerTicket);
    }

    function getCompressedGasValues(
        uint256 _gasPerPurchase,
        uint256 _gasPerAdjustment,
        uint256 _gasPerSale
    ) public pure returns(uint256 compressedGasValues) {
        compressedGasValues |= _gasPerSale;
        compressedGasValues <<= 83;
        compressedGasValues |= _gasPerAdjustment;
        compressedGasValues <<= 83;
        compressedGasValues |= _gasPerPurchase;
    }

    function getDecodedGasValues(
        uint256 _gasPerCall
    ) public pure returns(
        uint256 _gasPerPurchase,
        uint256 _gasPerAdjustment,
        uint256 _gasPerSale
    ) {
        _gasPerPurchase = _gasPerCall & (2**83 - 1);
        _gasPerSale = (_gasPerCall >> 83) & (2**83 - 1);
        _gasPerAdjustment = (_gasPerCall >> 166) & (2**83 - 1);
    }
}