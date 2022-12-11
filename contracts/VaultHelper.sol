//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vault } from "./Vault.sol";

contract VaultHelper {

    mapping(bytes32 => bool) public hashes;

    event TxHash(bytes32 txHash);

    function submitPurchase(
        address _pool,
        address _buyer,
        uint256 _salt,
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint32 startEpoch,
        uint32 finalEpoch,
        bytes memory signature
    ) external {
        Vault vault = Vault(payable(_pool));
        bytes32 txHash = this.generateHash(
            _pool,
            _buyer,
            _salt,
            tickets, 
            amountPerTicket,
            startEpoch,
            finalEpoch
        );
        if (_buyer != msg.sender) {
            address signer = this.getSigner(
                txHash,
                signature
            );
            require(signer == _buyer, "");
        }
        require(!hashes[txHash], "already executed");
        hashes[txHash] = true;
        uint256 _amount;
        for(uint256 i = 0; i < amountPerTicket.length; i++) {
            _amount += amountPerTicket[i];
        }
        (vault.token()).transferFrom(_buyer, address(this), _amount * (10 ** vault.token().decimals()) / 1000);
        (vault.token()).approve(_pool, _amount * (10 ** vault.token().decimals()) / 1000);
        vault.purchase(
            _buyer,
            tickets, 
            amountPerTicket,
            startEpoch,
            finalEpoch
        );

        emit TxHash(txHash);
    }

    function getSigner(bytes32 txHash, bytes memory signature) external pure returns (address signer){
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        signer = ecrecover(getEthSignedMessageHash(txHash), v, r, s);
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function generateHash(
        address _pool,
        address _buyer,
        uint256 _salt,
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint32 startEpoch,
        uint32 finalEpoch
    ) external view returns(bytes32 txHash) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        txHash = keccak256(abi.encodePacked(
            _pool,
            _buyer,
            _salt,
            tickets, 
            amountPerTicket,
            startEpoch,
            finalEpoch,
            chainId
        ));
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}