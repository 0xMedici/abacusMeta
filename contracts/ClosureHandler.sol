//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Vault } from "./Vault.sol";
import { Lend } from "./Lend.sol";
import { Auction } from "./Auction.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract ClosureHandler {

    AbacusController public controller;

    constructor(
        address _controller
    ) {
        controller = AbacusController(_controller);
    }

    function closeNFTs(
        address _currency,
        bytes32[][][] calldata _merkleProofs, 
        address[] calldata _nfts, 
        uint256[] calldata _ids,
        address[][] calldata _pools,
        uint256[][] calldata _tickets,
        uint256[][] calldata _amounts
    ) external {
        uint256 totalPPR;
        for(uint256 i = 0; i < _nfts.length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            require(
                controller.lend().getNormalizerCheck(_pools[i], _tickets[i])
                , "Normalization failed"
            );
            uint256 uniquePoolIndex;
            uint256 prevPool;
            uint256 ppr;
            address[] memory uniquePools = new address[](_tickets[i].length);
            uint256[] memory poolFees = new uint256[](_tickets[i].length);
            for(uint256 j = 0; j < _tickets[i].length; j++) {
                Vault vault = Vault(_pools[i][j]);
                require(
                    controller.accreditedAddresses(address(vault))
                    , "NA"
                );
                require(
                    uint160(address(vault)) >= prevPool
                    , "Pool out of order!"    
                );
                if(uint160(address(vault)) != prevPool) {
                    require(
                        vault.getHeldTokenExistence(_merkleProof[i][j], _nft, _id)
                        , "Invalid closure choice"
                    );
                    uniquePools[uniquePoolIndex] = address(vault);
                    uniquePoolIndex++;
                } else {
                    poolFees[uniquePoolIndex] += _amounts[i][j];
                }
                require(
                    currency == address(vault.token())
                    , "Incorrect currency"
                );
                require(
                    vault.getTicketInfo(_ticket) >= _amount
                    && vault.getTrancheSize(_ticket) >= _amount
                    , "Trying to borrow too much"
                );
                require(
                    vault.getTicketInfo(_ticket) - controller.lend().ticketLiqAccessed(address(vault), _ticket) >= _amount
                    , "Not enough available in that tranche"
                );
                ppr += _amounts[i][j];
                prevPool = uint160(address(vault));
            }
            for(uint256 k = 0; k < uniquePoolIndex; k++) {
                Vault vault = Vault(uniquePools[k]);
                vault.closeNft(auction.nonce, ppr);
            }
            controller.flow().processFees(
                address(this),
                _currency,
                uniquePools[:uniquePoolIndex],
                poolFees[:uniquePoolIndex]
            );
            auction.startAuction(_currency, _nft, _id, ppr);
            IERC721(_nft).transferFrom(msg.sender, address(auction), _id);
            // emit NftClosed(
            //     adjustmentsRequired,
            //     nonce,
            //     _nft,
            //     _id,
            //     msg.sender,
            //     ppr, 
            //     address(auction)
            // );
            totalPPR += ppr;
        }
        controller.flow().payoutSaleClosure(
            msg.sender,
            _currency,
            totalPPR * 10**ERC20(_currency).decimals() / 1000
        );
    }

    function closeNFTsLiquidate(
        address[] calldata _nfts, 
        uint256[] calldata _ids,
        uint256[] calldata _liquidationSizes,
        address[][] calldata _pools
    ) external {
        for(uint256 i = 0; i < _nfts.length; i++) {
            for(uint256 j = 0; j < _pools[i].length; j++) {
                Vault vault = Vault(_pools[i][j]);
                vault.closeNft(auction.nonce, _liquidationSizes[i]);
            }
            auction.startAuction(address(vault.token()), _nfts[i], _ids[i], _liquidationSizes[i]);
        }
    }
}