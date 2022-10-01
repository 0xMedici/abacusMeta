//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

               //\\                 ||||||||||||||||||||||||||                   //\\                 ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
              ///\\\                |||||||||||||||||||||||||||                 ///\\\                ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
             ////\\\\               |||||||             ||||||||               ////\\\\               ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
            /////\\\\\              |||||||             ||||||||              /////\\\\\              |||||||                       ||||||||            ||||||||  ||||||||||
           //////\\\\\\             |||||||             ||||||||             //////\\\\\\             |||||||                       ||||||||            ||||||||  ||||||||||
          ///////\\\\\\\            |||||||             ||||||||            ///////\\\\\\\            |||||||                       ||||||||            ||||||||  ||||||||||
         ////////\\\\\\\\           ||||||||||||||||||||||||||||           ////////\\\\\\\\           |||||||                       ||||||||            ||||||||  ||||||||||
        /////////\\\\\\\\\          ||||||||||||||                        /////////\\\\\\\\\          |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
       /////////  \\\\\\\\\         ||||||||||||||||||||||||||||         /////////  \\\\\\\\\         |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
      /////////    \\\\\\\\\        |||||||             ||||||||        /////////    \\\\\\\\\        |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
     /////////||||||\\\\\\\\\       |||||||             ||||||||       /////////||||||\\\\\\\\\       |||||||                       ||||||||            ||||||||                    ||||||||||
    /////////||||||||\\\\\\\\\      |||||||             ||||||||      /////////||||||||\\\\\\\\\      |||||||                       ||||||||            ||||||||                    ||||||||||
   /////////          \\\\\\\\\     |||||||             ||||||||     /////////          \\\\\\\\\     |||||||                       ||||||||            ||||||||                    ||||||||||
  /////////            \\\\\\\\\    |||||||             ||||||||    /////////            \\\\\\\\\    ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||
 /////////              \\\\\\\\\   |||||||||||||||||||||||||||    /////////              \\\\\\\\\   ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||
/////////                \\\\\\\\\  ||||||||||||||||||||||||||    /////////                \\\\\\\\\  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||

/// @title Abacus Controller
/// @author Gio Medici
/// @notice Abacus protocol controller contract that holds all relevant addresses and metrics 
contract AbacusController {

    ///TODO: UPDATE change practices

    /* ======== ADDRESS ======== */
    /// @notice controller multisig address (controlled by council)
    address public multisig;
    address public factory;
    address public lender;

    /* ======== UINT ======== */
    /// @notice beta stage
    uint256 public beta;

    /* ======== MAPPING ======== */

    mapping(address => address) public registry;

    /// @notice track if an NFT has already been used to sign a pool
    /// [address] -> NFT collection address
    /// [uint256] -> NFT token ID
    /// [bool] -> status of usage
    mapping(address => mapping(uint256 => bool)) public nftVaultSigned;

    /// @notice track the pool that an NFT signed
    /// [address] -> NFT collection address
    /// [uint256] -> NFT token id
    /// [address] -> pool address
    mapping(address => mapping(uint256 => address)) public nftVaultSignedAddress;

    /// @notice track addresses that are allowed to produce EDC
    /// [address] -> producer
    /// [bool] -> accredited status
    mapping(address => bool) public accreditedAddresses;

    /// @notice track early users that have been whitelisted for permission to create pools
    /// [address] -> user
    /// [bool] -> whitelist status
    mapping(address => bool) public userWhitelist;

    /// @notice track factory address associated with a factory version
    /// [uint256] -> version
    /// [address] -> factory
    mapping(uint256 => address) public factoryVersions;

    /* ======== EVENTS ======== */

    event UpdateNftInUse(address pool, address nft, uint256 id, bool status);
    event WLUserAdded(address[] _user);
    event WLUserRemoved(address[] _user);
    event BetaStageApproved(uint256 stage);

    /* ======== MODIFIERS ======== */

    modifier onlyMultisig() {
        require(msg.sender == multisig);
        _;
    }

    /* ======== CONSTRUCTOR ======== */

    constructor(address _multisig) {
        multisig = _multisig;
        beta = 1;
    }

    /* ======== IMMUTABLE SETTERS ======== */

    function setLender(address _lender) external onlyMultisig {
        require(lender == address(0));
        lender = _lender;
    }

    function setFactory(address _factory) external onlyMultisig {
        require(factory == address(0));
        factory = _factory;
    }

    /* ======== AUTOMATED SETTERS ======== */

    function addAccreditedAddressesMulti(address newAddress) external {
        require(factory == msg.sender || accreditedAddresses[msg.sender]);
        accreditedAddresses[newAddress] = true;
    }

    function updateNftUsage(address pool, address nft, uint256 id, bool status) external {
        require(factory == msg.sender || accreditedAddresses[msg.sender]);
        if(status) {
            nftVaultSigned[nft][id] = true;
            nftVaultSignedAddress[nft][id] = pool;
        }
        else {
            delete nftVaultSigned[nft][id];
            delete nftVaultSignedAddress[nft][id];
        }
        emit UpdateNftInUse(pool, nft, id, status);
    }

    /* ======== PROPOSALS BETA 1 ======== */

    function addWlUser(address[] calldata users) external onlyMultisig {
        uint256 length = users.length;
        for(uint256 i = 0; i < length; i++) {
            userWhitelist[users[i]] = true;
        }
        emit WLUserAdded(users);
    }

    function removeWlUser(address[] calldata users) external onlyMultisig {
        uint256 length = users.length;
        for(uint256 i = 0; i < length; i++) {
            delete userWhitelist[users[i]];
        }
        emit WLUserRemoved(users);
    }

    function setBeta(uint256 _stage) external onlyMultisig {
        require(_stage > beta);
        beta = _stage;
        emit BetaStageApproved(_stage);
    }

    /* ======== PROXY REGISTRY ======== */
    function setProxy(address _proxy) external {
        registry[msg.sender] = _proxy;
    }

    function clearProxy() external {
        delete registry[msg.sender];
    }
}