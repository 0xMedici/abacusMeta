//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vault } from "./Vault.sol";
import { AbacusController } from "./AbacusController.sol";
import { TrancheCalculator } from "./TrancheCalculator.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./helpers/ReentrancyGuard.sol";
// import "hardhat/console.sol";

/// @title NFT Lender
/// @author Gio Medici
/// @notice Borrow against the value of a backing Abacus Spot pool
contract Lend is ReentrancyGuard {

    /* ======== ADDRESS IMMUTABLE ======== */
    AbacusController public immutable controller;
    TrancheCalculator public immutable trancheCalc;

    /* ======== MAPPING ======== */
    mapping(address => mapping(uint256 => uint256)) public ticketLiqAccessed;

    /// @notice Track loan metrics
    /// [address] -> NFT Collection address
    /// [uint256] -> NFT ID
    mapping(address => mapping(uint256 => Position)) public loans;
    
    /* ======== STRUCT ======== */
    /// @notice Struct to hold information regarding deployed loan
    /// [borrower] -> User with the borrower
    /// [pool] -> Underlying Spot pool
    /// [transferFromPermission] -> Stores the address of a user with transfer permission
    /// [startEpoch] -> The epoch that the loan was taken out
    /// [amount] -> Outstanding loan amount
    /// [timesInterestPaid] -> Amout of epochs that interest has been paid
    /// [interestPaid] -> Track whether a loan has had interest paid during an epoch
        /// [uint256] -> epoch
    struct Position {
        address borrower;
        address transferFromPermission;
        uint256 loanStart;
        uint256 loanHash;
    }

    /* ======== EVENT ======== */
    event EthBorrowed(address _user, address _pool, address nft, uint256 id, uint256 _amount);
    event InterestPaid(address _user, address _pool, address nft, uint256 id, uint256[] _epoch, uint256 _amountPaid);
    event EthRepayed(address _user, address _pool, address nft, uint256 id, uint256 _amount);
    event BorrowerLiquidated(address _user, address _pool, address nft, uint256 id, uint256 _amount);
    event LoanTransferred(address _pool, address from, address to, address nft, uint256 id);

    /* ======== CONSTRUCTOR ======== */
    constructor(address _controller) {
        controller = AbacusController(_controller);
        trancheCalc = controller.calculator();
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== LENDING ======== */
    function agnosticRemoval(
        address[] calldata _currency,
        uint256[] calldata _amounts
    ) external {
        require(
            controller.agnosticRemovalWl[msg.sender]
            , "Contract not allowed!"
        );
        uint256 length = _nft.length;
        for(uint256 i = 0; i < length; i++) {
            ERC20(_currency[i]).transfer(msg.sender, _amounts[i]);
        }
    }

    function newBorrow(
        address currency,
        bytes32[][] calldata _merkleProof, 
        address[] calldata _nfts, 
        uint256[] calldata _ids,
        address[][] calldata _pools,
        uint256[][] calldata _tickets,
        uint256[][] calldata _amounts
    ) external {
        uint256 length = _pools.length;
        uint256 totalBorrow;
        for(uint256 i = 0; i < length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            Position storage openLoan = loans[_nft][_id];
            require(
                openLoan.borrower == address(0)
                , "Loan deployed"
            );
            require(
                this.getNormalizerCheck(_pools[i], _tickets[i])
                , "Normalization failed"
            );
            bytes32 newLoanHash;
            for(uint256 j = 0; j < _tickets[i].length; j++) {
                uint256 _ticket = _tickets[i][j];
                uint256 _amount = _amounts[i][j];
                Vault vault = Vault(_pools[i][j]);
                require(
                    currency == address(vault.token())
                    , "Incorrect currency"
                );
                require(
                    controller.accreditedAddresses(address(vault))
                    , "NA"
                );
                require(
                    vault.getHeldTokenExistence(_merkleProof[i], _nft, _id)
                    , "Invalid borrow choice"
                );
                require(
                    vault.getTicketInfo(_ticket) >= _amount
                    && vault.getTrancheSize(_ticket) >= _amount
                    , "Trying to borrow too much"
                );
                require(
                    vault.getTicketInfo(_ticket) - ticketLiqAccessed[address(vault)][_ticket] >= _amount
                    , "Not enough available in that tranche"
                );
                ticketLiqAccessed[address(vault)][_ticket] += _amount;
                uint256 temp;
                temp |= uint160(address(vault));
                temp <<= 30;
                temp |= _ticket;
                temp <<= 65;
                temp |= _amount;
                newLoanHash = keccak256(abi.encode(temp, newLoanHash));
                totalBorrow += _amount;
            }
            openLoan.borrower = msg.sender;
            openLoan.loanStart = block.timestamp;
            openLoan.loanHash = newLoanHash;
        }
        controller.flow().routBorrow(
            msg.sender,
            currency,
            totalBorrow
        );
    }

    function existingBorrow(
        address currency,
        bytes32[][] calldata _merkleProof, 
        address[] calldata _nfts, 
        uint256[] calldata _ids,
        address[][] calldata _pools,
        uint256[][] calldata _tickets,
        uint256[][] calldata _existingAmounts,
        uint256[][] calldata _addedAmounts
    ) external {
        uint256 length = _pools.length;
        uint256 totalBorrow;
        for(uint256 i = 0; i < length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            Position storage openLoan = loans[_nft][_id];
            require(
                openLoan.borrower == address(0)
                , "Loan deployed"
            );
            require(
                this.getNormalizerCheck(_pools[i], _tickets[i])
                , "Normalization failed"
            );
            uint256 interestAmount;
            bytes32 existingLoanHash;
            bytes32 newLoanHash;
            uint256[] memory newList = new uint256[](_pools[i].length);
            for(uint256 j = 0; j < _tickets[i].length; j++) {
                uint256 _ticket = _tickets[i][j];
                uint256 _amount = _existingAmounts[i][j];
                uint256 _addedAmount = _addedAmounts[i][j];
                Vault vault = Vault(_pools[i][j]);
                require(
                    currency == address(vault.token())
                    , "Incorrect currency"
                );
                require(
                    controller.accreditedAddresses(address(vault))
                    , "NA"
                );
                require(
                    vault.getHeldTokenExistence(_merkleProof[i], _nft, _id)
                    , "Invalid borrow choice"
                );
                require(
                    vault.getTicketInfo(_ticket) >= _amount + _addedAmount
                    && vault.getTrancheSize(_ticket) >= _amount + _addedAmount
                    , "Trying to borrow too much"
                );
                require(
                    vault.getTicketInfo(_ticket) - ticketLiqAccessed[address(vault)][_ticket] >= _addedAmount
                    , "Not enough available in that tranche"
                );
                ticketLiqAccessed[address(vault)][_ticket] += _addedAmount;
                uint256 temp;
                temp |= uint160(address(vault));
                temp <<= 30;
                temp |= _ticket;
                temp <<= 65;
                if(_amount != 0) {
                    temp |= _amount;
                    existingLoanHash = keccak256(abi.encode(temp, existingLoanHash));
                    temp = ~(2**65 - 1);
                }
                temp |= _amount + _addedAmount;
                newLoanHash = keccak256(abi.encode(temp, newLoanHash));
                interestAmount += vault.interestRate() * _amount / 10_000 
                        * (block.timestamp - openLoan.loanStart) / (52 weeks);
                newList[j] = interestAmount;
                totalBorrow += _addedAmount;
            }
            require(
                existingLoanHash == openLoan.loanHash
                , "Improper loan proof"
            );
            controller.flow().processFees(
                msg.sender,
                currency,
                _pools[i],
                newList
            );
            openLoan.loanStart = block.timestamp;
            openLoan.loanHash = newLoanHash;
        }
        controller.flow().routBorrow(
            msg.sender,
            currency,
            totalBorrow
        );
    }

    function repay(
        address currency,
        address[] calldata _nfts,
        uint256[] calldata _ids,
        address[][] calldata _pools,
        uint256[][] calldata _tickets,
        uint256[][] calldata _amounts,
        uint256[][] calldata _repaidAmounts
    ) external nonReentrant {
        uint256 length = _pools.length;
        uint256 totalRepay;
        for(uint256 i = 0; i < length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            Position storage openLoan = loans[_nft][_id];
            bytes32 existingLoanHash;
            bytes32 newLoanHash;
            bool loanRepaid;
            uint256[] memory newList = new uint256[](_pools[i].length);
            for(uint256 j = 0; j < _tickets[i].length; j++) {
                uint256 _ticket = _tickets[i][j];
                uint256 _amount = _existingAmounts[i][j];
                uint256 _repaidAmount = _repaidAmounts[i][j];
                Vault vault = Vault(_pools[i][j]);
                require(
                    currency == address(vault.token())
                    , "Incorrect currency"
                );
                require(
                    controller.accreditedAddresses(address(vault))
                    , "NA"
                );
                require(
                    vault.getHeldTokenExistence(_merkleProof[i], _nft, _id)
                    , "Invalid borrow choice"
                );
                ticketLiqAccessed[address(vault)][_ticket] -= _repaidAmount;
                uint256 temp;
                temp |= uint160(address(vault));
                temp <<= 30;
                temp |= _ticket;
                temp <<= 65;
                temp |= _amount;
                existingLoanHash = keccak256(abi.encode(temp, existingLoanHash));
                temp = ~(2**65 - 1);
                temp |= _amount - _repaidAmount;
                if(_amount == _repaidAmount) {
                    loanRepaid = true;
                } else {
                    loanRepaid = false;
                }
                newLoanHash = keccak256(abi.encode(temp, newLoanHash));
                interestAmount = vault.interestRate() * _amount / 10_000 
                        * (block.timestamp - openLoan.loanStart) / (52 weeks);
                newList[j] = interestAmount;
                totalRepay += _amount;
            }
            require(
                existingLoanHash == openLoan.loanHash
                , "Improper loan proof"
            );
            require(
                openLoan.borrower == msg.sender
                , "Not borrower"
            );
            controller.flow().processFees(
                msg.sender,
                currency,
                _pools[i],
                newList
            );
            if(loanRepaid) {
                delete openLoan;
                IERC721(nft).transferFrom(address(this), msg.sender, id);
            } else {
                openLoan.loanStart = block.timestamp;
                openLoan.loanHash = newLoanHash;
            }
        }
        controller.flow().serviceBorrow(
            msg.sender,
            currency,
            totalRepay
        );
    }

    function liquidate(
        address currency,
        address[] calldata _nfts, 
        uint256[] calldata _ids,
        address[][] calldata _pools,
        uint256[][] calldata _tickets,
        uint256[][] calldata _amounts,
        address[] calldata _sellers
    ) external {
        uint256 length = _pools.length;
        for(uint256 i = 0; i < length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            Position storage openLoan = loans[_nft][_id];
            bytes32 existingLoanHash;
            bool activateLiquidation;
            uint256 loanSize;
            uint256 liquidationSize;
            uint256 uniquePoolIndex;
            uint256 prevPool;
            address[] memory uniquePools = new address[](_tickets[i].length);
            uint256[] memory poolFees = new uint256[](_tickets[i].length);
            uint256[] memory liquidationSizes = new uint256[](_nfts.length);
            for(uint256 j = 0; j < _tickets[i].length; j++) {
                uint256 _ticket = _tickets[i][j];
                uint256 _amount = _existingAmounts[i][j];
                Vault vault = Vault(_pools[i][j]);
                require(
                    currency == address(vault.token())
                    , "Incorrect currency"
                );
                require(
                    controller.accreditedAddresses(address(vault))
                    , "NA"
                );
                require(
                    uint160(address(vault)) >= prevPool
                    , "Pool out of order!"    
                );
                if(uint160(address(vault)) != prevPool) {
                    uniquePools[uniquePoolIndex] = address(vault);
                    uniquePoolIndex++;
                } else {
                    poolFees[uniquePoolIndex] += 
                        99 * ((vault.getTicketInfo(_ticket) > vault.getTrancheSize(_ticket) ? 
                            vault.getTrancheSize(_ticket) : vault.getTicketInfo(_ticket)) 
                                - _amounts[i][j]) / 100;
                }
                require(
                    vault.getHeldTokenExistence(_merkleProof[i], _nft, _id)
                    , "Invalid borrow choice"
                );
                if(
                    vault.getTicketInfo(_ticket) - ticketLiqAccessed[address(vault)][_ticket] 
                    <= vault.position().getUserPending(_sellers[i], _ticket)
                ) {
                    require(
                        vault.positionManager().withdrawalTime(_sellers[i]) 
                            <= block.timestamp + vault.liquidationWindow()
                        , "Liquidating too early"
                    );
                    activateLiquidation = true;
                }
                uint256 temp;
                temp |= uint160(address(vault));
                temp <<= 30;
                temp |= _ticket;
                temp <<= 65;
                temp |= _amount;
                loanSize += _amount;
                liquidationSize += 
                    vault.getTicketInfo(_ticket) > vault.getTrancheSize(_ticket) ? 
                        vault.getTrancheSize(_ticket) : vault.getTicketInfo(_ticket);
                existingLoanHash = keccak256(abi.encode(temp, existingLoanHash));
                prevPool = uint160(address(vault));
            }
            require(
                existingLoanHash == openLoan.loanHash
                , "Improper loan proof"
            );
            //Reward liquidator
            //Reward spread - liquidator cut to each pool in the form of fees
            //Spread each pool gets is the ticket - the total borrowable amount
            require(
                activateLiquidation
                , "Liq failed"
            );
            ERC20(_currency).transfer(msg.sender, 1 * (liquidationSize - loanSize) / 100);
            controller.flow().processFees(
                address(this),
                _currency,
                uniquePools[:uniquePoolIndex],
                poolFees[:uniquePoolIndex]
            );
            delete openLoan;
            liquidationSizes[i] = liquidationSize;
            IERC721(nft).transferFrom(address(this), address(controller.auction()), id);
        }
        controller.handler().closeNFTsLiquidate(
            _nfts,
            _ids,
            liquidationSizes,
            _pools
        );
    }

    /// SEE ILend.sol FOR COMMENTS
    function allowTransferFrom(
        address nft, 
        uint256 id, 
        address allowee
    ) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(msg.sender == openLoan.borrower, "Not borrower");
        openLoan.transferFromPermission = allowee;
    }

    /// SEE ILend.sol FOR COMMENTS
    function transferFromLoanOwnership(
        address from,
        address to, 
        address nft, 
        uint256 id
    ) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(
            msg.sender == openLoan.borrower
            || openLoan.transferFromPermission == msg.sender, "No permission"
        );
        delete openLoan.transferFromPermission;
        openLoan.borrower = to;
        emit LoanTransferred(openLoan.pool, from, to, nft, id);
    }
    
    /* ======== INTERNAL ======== */
    function processLiquidation(
        Vault vault,
        bytes32[] calldata _merkleProof,
        address nft,
        uint256 id
    ) internal {
        uint256 loanAmount = loans[nft][id].amount;
        IERC721(nft).approve(address(vault), id);
        uint256 payout = vault.closeNft(_merkleProof, nft, id);
        require((vault.token()).transfer(msg.sender, (payout - loanAmount) / 10));
        require((vault.token()).transfer(address(vault), payout - loanAmount - ((payout - loanAmount) / 10)));
        vault.processFees(payout - loanAmount - ((payout - loanAmount) / 10));
    }

    /* ======== GETTERS ======== */
    function getNormalizerCheck(
        address[] calldata _pools,
        uint256[] calldata _tickets
    ) external view returns(bool) {
        uint256 length = _tickets.length;
        for(uint256 i = 0; i < length - 1; i++) {
            uint256 upperBound = trancheCalc.mockCalculation(_pool[i], _tickets[i]);
            uint256 lowerBound = trancheCalc.mockCalculation(_pool[i + 1], _tickets[i + 1]);
            if(
                upperBound <= lowerBound
            ) return false;
        }
        return true;
    }

    /// SEE ILend.sol FOR COMMENTS
    function getPosition(
        address nft,
        uint256 id
    ) external view returns(
        address borrower,
        address pool,
        address transferFromPermission,
        uint256 startEpoch,
        uint256 amount,
        uint256 interestEpoch
    ) {
        Position storage loan = loans[nft][id];
        borrower = loan.borrower;
        pool = loan.pool;
        transferFromPermission = loan.transferFromPermission;
        startEpoch = loan.startEpoch;
        amount = loan.amount;
        interestEpoch = loan.interestEpoch;
    }

    /// SEE ILend.sol FOR COMMENTS
    function getInterestPayment(uint256[] calldata _epoch, address _nft, uint256 _id) external view returns(uint256) {
        Vault vault = Vault(payable(loans[_nft][_id].pool));
        uint256 totalInterest;
        uint256 length = _epoch.length;
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        if(
            loans[_nft][_id].amount == 0
            || loans[_nft][_id].interestEpoch == poolEpoch + 1
        ) {
            return 0;
        }
        uint256 epochsMissed = poolEpoch + 1 - loans[_nft][_id].interestEpoch;
        for(uint256 i; i < length; i++) {
            uint256 epoch = _epoch[i];
            totalInterest += vault.interestRate() * vault.getPayoutPerReservation(epoch) / 10_000 
                        * vault.epochLength() / (52 weeks) * ((epochsMissed >= 2) ? 3 * epochsMissed / 2 : 1);
        }
        return totalInterest;
    }
}