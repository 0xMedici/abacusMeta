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

    /* ======== ADDRESS ======== */

    /// @notice proposed list of users to be whitelisted for beta stage 1 
    address[] public pendingWLUserAddition;

    /// @notice proposed list of user to be removed from the whitelist for beta stage 1
    address[] public pendingWLUserRemoval;

    /// @notice proposed list of collection to be added to the collection whitelist
    address[] public pendingWLAdditions;

    /// @notice proposed list of collections to be removed from the collection whitelist
    address[] public pendingWLRemoval;

    /// @notice contract address for Credit Bonds 
    address public creditBonds;

    /// @notice controller admin address (controlled by governance)
    address public admin;

    /// @notice contract address for ABC
    address public abcToken;

    /// @notice contract address for Allocator
    address public allocator;

    /// @notice contract address for Epoch Vault
    address public epochVault;

    /// @notice proposed address of new Factory contract
    address public pendingFactory;
    
    /// @notice controller multisig address (controlled by council)
    address public multisig;

    /* ======== UINT ======== */

    uint256 public totalVolumeTraversed;

    uint256 public voteEndTime;

    /// @notice amount of live factories that can create emission producing spot pools 
    uint256 public amountOfFactories;

    /// @notice proposed beta stage
    uint256 public pendingBeta;

    /// @notice beta stage
    uint256 public beta;

    /* ======== BOOL ======== */

    bool public changeLive;

    /* ======== MAPPING ======== */

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

    /// @notice track factories approved to generate new pools and grant them accredited status
    /// [address] -> factory
    /// [bool] -> whitelist status 
    mapping(address => bool) public factoryWhitelist;

    /// @notice track collections that have been whitelisted for pool creation
    /// [address] -> collection
    /// [bool] -> whitelist status
    mapping(address => bool) public collectionWhitelist;

    /// @notice track early users that have been whitelisted for permission to create pools
    /// [address] -> user
    /// [bool] -> whitelist status
    mapping(address => bool) public userWhitelist;

    /// @notice track factory address associated with a factory version
    /// [uint256] -> version
    /// [address] -> factory
    mapping(uint256 => address) public factoryVersions;

    /* ======== EVENTS ======== */

    event AdminSet(address _admin);
    event NftEthSet(address _nftEth);
    event CreditBondsSet(address _creditBonds);
    event TokenSet(address _token);
    event AllocatorSet(address _veToken);
    event EpochVaultSet(address _epochVault);
    event UpdateNftInUse(address pool, address nft, uint256 id, bool status);
    event ProposeWLUserAddition(address[] _user);
    event WLLpApproved(address[] _user);
    event WLUserApproved(address[] _user);
    event WLUserRejected(address[] _user);
    event ProposeWLUserRemoval(address[] _user);
    event WLUserRemovalApproved(address[] _user);
    event WLUserRemovalRejected(address[] _user);
    event ProposeWLAddressesAddition(address[] collections);
    event WLAddressesAdditionApproved(address[] collections);
    event WLAddressesAdditionRejected(address[] collections);
    event ProposeWLAddressesRemoval(address[] collections);
    event WLAddressesRemovalApproved(address[] collections);
    event WLAddressesRemovalRejected(address[] collections);
    event ProposeBetaStage(uint256 stage);
    event BetaStageApproved(uint256 stage);
    event BetaStageRejected(uint256 stage);
    event ProposeFactoryAddition(address _newFactory);
    event FactoryAdditionApproved(address _newFactory);
    event FactoryAdditionRejected(address _newAddress);
    event ProposePoolSizeLimit(uint256 limit);
    event PoolSizeLimitApproved(uint256 prev, uint256 limit);
    event PoolSizeLimitRejected(uint256 limit);
    event ProposeNewMultisig(address _multisig);
    event MultisigApproved(address previous, address _multisig);
    event MultisigRejected(address _multisig);
    event ProposeNewAdmin(address _admin);
    event AdminApproved(address previous, address _admin);
    event AdminRejected(address _admin);
    event ProposeNewTreasury(address _treasury);
    event TreasuryApproved(address previous, address _treasury);
    event TreasuryRejected(address _treasury);

    /* ======== MODIFIERS ======== */

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyMultisig() {
        require(msg.sender == multisig);
        _;
    }

    /* ======== CONSTRUCTOR ======== */

    constructor(address _multisig) {
        multisig = _multisig;
        amountOfFactories = 1;
        beta = 1;
    }

    /* ======== IMMUTABLE SETTERS ======== */

    function setCreditBonds(address _creditBonds) external onlyMultisig {
        require(creditBonds == address(0), "Already set");
        creditBonds = _creditBonds;
        emit CreditBondsSet(_creditBonds);
    }

    function setToken(address _token) external onlyMultisig {
        require(abcToken == address(0), "Already set");
        abcToken = _token;
        emit TokenSet(_token);
    }

    function setAllocator(address _allocator) external onlyMultisig {
        require(allocator == address(0), "Already set");
        allocator = _allocator;
        emit AllocatorSet(_allocator);
    }

    function setEpochVault(address _epochVault) external onlyMultisig {
        require(epochVault == address(0), "Already set");
        epochVault = _epochVault;
        emit EpochVaultSet(_epochVault);
    }

    function setAdmin(address _admin) external onlyMultisig {
        require(admin == address(0), "Already set");
        admin = _admin;
        emit AdminSet(_admin);
    }

    /* ======== AUTOMATED SETTERS ======== */

    function addAccreditedAddressesMulti(address newAddress) external {
        require(factoryWhitelist[msg.sender] || accreditedAddresses[msg.sender]);
        accreditedAddresses[newAddress] = true;
    }

    function updateNftUsage(address pool, address nft, uint256 id, bool status) external {
        require(factoryWhitelist[msg.sender] || accreditedAddresses[msg.sender]);
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

    function updateTotalVolumeTraversed(uint256 _amount) external {
        require(accreditedAddresses[msg.sender]);
        totalVolumeTraversed += _amount;
    }

    /* ======== PROPOSALS BETA 1 ======== */

    function proposeWLUser(address[] memory users) external onlyMultisig {
        // require(beta == 1);
        uint256 length = users.length;
        emit WLUserApproved(users);
        for(uint256 i = 0; i < length; i++) {
            userWhitelist[users[i]] = true;
        }
    }

    function proposeWLUserRemoval(address[] memory users) external onlyMultisig {
        uint256 length = users.length;
        for(uint256 i = 0; i < length; i++) {
            delete userWhitelist[users[i]];
        }
        emit ProposeWLUserRemoval(users);
    }

    function setBeta(uint256 _stage) external onlyMultisig {
        require(pendingBeta == 0, "Must vote first");
        require(_stage > beta);
        beta = _stage;
        emit BetaStageApproved(_stage);
    }

    /* ======== PROPOSALS ADDRESSES ======== */

    function proposeWLAddresses(address[] memory collections) external onlyAdmin {
        require(pendingWLAdditions.length == 0, "Must vote first");
        require(!changeLive);
        changeLive = true;
        voteEndTime = block.timestamp + 5 days;
        pendingWLAdditions = collections;
        emit ProposeWLAddressesAddition(collections);
    }

    function approveWLAddresses() external onlyAdmin {
        require(changeLive);
        delete changeLive;
        uint256 length = pendingWLAdditions.length;
        emit WLAddressesAdditionApproved(pendingWLAdditions);
        for(uint256 i = 0; i < length; i++) {
            collectionWhitelist[pendingWLAdditions[i]] = true;
        }
        delete pendingWLAdditions;
    }

    function rejectWLAddresses() external onlyAdmin {
        require(changeLive);
        delete changeLive;
        emit WLAddressesAdditionRejected(pendingWLAdditions);
        delete pendingWLAdditions;
    }

    function proposeWLRemoval(address[] memory collections) external onlyAdmin {
        require(pendingWLRemoval.length == 0, "Must vote first");
        require(!changeLive);
        changeLive = true;
        voteEndTime = block.timestamp + 5 days;
        pendingWLRemoval = collections;
        emit ProposeWLAddressesRemoval(collections);
    }

    function approveWLRemoval() external onlyAdmin {
        require(changeLive);
        delete changeLive;
        uint256 length = pendingWLRemoval.length;
        emit WLAddressesRemovalApproved(pendingWLRemoval);
        for(uint256 i = 0; i < length; i++) {
            collectionWhitelist[pendingWLRemoval[i]] = false;
        }
        delete pendingWLRemoval;
    }

    function rejectWLRemoval() external onlyAdmin {
        require(changeLive);
        delete changeLive;
        emit WLAddressesRemovalRejected(pendingWLRemoval);
        delete pendingWLRemoval;
    }

    function proposeFactoryAddition(address _newFactory) external onlyAdmin {
        require(!factoryWhitelist[_newFactory]);
        require(pendingFactory == address(0), "Must vote first");
        require(_newFactory != address(0), "Address is zero");
        require(!changeLive);
        changeLive = true;
        voteEndTime = block.timestamp + 10 days;
        pendingFactory = _newFactory;
        emit ProposeFactoryAddition(_newFactory);
    }

    function approveFactoryAddition() external onlyAdmin {
        require(changeLive);
        delete changeLive;
        factoryWhitelist[pendingFactory] = true;
        factoryVersions[amountOfFactories] = pendingFactory;
        amountOfFactories++;
        emit FactoryAdditionApproved(pendingFactory);
        delete pendingFactory;
    }

    function rejectFactoryAddition() external onlyAdmin {
        require(changeLive);
        delete changeLive;
        emit FactoryAdditionRejected(pendingFactory);
        delete pendingFactory;
    }
}