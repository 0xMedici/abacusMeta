//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

/// @title Abacus Controller
/// @author Gio Medici
/// @notice Protocol directory
contract AbacusController {

    /* ======== ADDRESS ======== */

    address[] public pendingWLUserAddition;
    address[] public pendingWLUserRemoval;

    address[] public pendingWLAdditions;
    address[] public pendingWLRemoval;

    address public pendingCreditBonds;
    address public creditBonds;

    address public pendingPresale;
    address public presale;

    address public pendingAdmin;
    address public admin;

    address public pendingTreasury;
    address public abcTreasury;

    address public pendingToken;
    address public abcToken;

    address public pendingVeToken;
    address public veAbcToken;

    address public pendingEvault;
    address public epochVault;

    address public pendingFactory;

    address public pendingMultisig;
    address public multisig;

    /* ======== UINT ======== */
    
    uint256 public pendingMaxPoolsPerToken;
    uint256 public maxPoolsPerToken;

    /// @notice rate of inflation after 3 years
    uint256 public pendingInflationRate;
    uint256 public inflationRate;

    /// @notice cost to close a pool
    uint256 public pendingClosureFee;
    uint256 public vaultClosureFee;

    /// @notice network gas fee
    uint256 public pendingGasFee;
    uint256 public abcGasFee;

    /// @notice amount of revenue that goes to the treasury
    uint256 public pendingTreasuryRate;
    uint256 public treasuryRate;

    /// @notice rate of inflation after 3 years
    uint256 public pendingBondMaxPremiumThreshold;
    uint256 public bondMaxPremiumThreshold;

    /// @notice amount of factory versions
    uint256 public amountOfFactories;

    uint256 public pendingBeta;
    uint256 public beta;

    /* ======== MAPPING ======== */

    /// @notice addresses that can update EDC 
    mapping(address => bool) public accreditedAddresses;

    /// @notice whitelist of approved factories
    mapping(address => bool) public factoryWhitelist;

    /// @notice whitelist of approved collections
    mapping(address => bool) public collectionWhitelist;

    /// @notice whitelist of early users
    mapping(address => bool) public userWhitelist;

    /// @notice mapping of factory versions
    mapping(uint256 => address) public factoryVersions;

    /// @notice mapping of pools to version type
    mapping(address => mapping(uint => uint256)) public nftVaultVersion;


    /* ======== EVENTS ======== */
    
    event TreasuryRateChangeProposed(uint256 _currentRate, uint256 _pendingRate);
    event TreasuryRateChangeApproved(uint256 _confirmedRate);
    event ClosureFeeChangeProposed(uint256 _currentClosureFee, uint256 _pendingClosureFee);
    event ClosureFeeChangeApproved(uint256 _confirmedClosureFee);
    event NetworkFeeChangeProposed(uint256 _currentNetworkFee, uint256 _pendingNetworkFee);
    event NetworkFeeChangeApproved(uint256 _confirmedNetworkFee);
    event InflationChangeProposed(uint256 _currentInflation, uint256 _pendingInflation);
    event InflationChangeApproved(uint256 _confirmedInflation);
    event ThresholdChangeProposed(uint256 _currentThreshold, uint256 _pendingThreshold);
    event ThresholdApproved(uint256 _confirmedThreshold);


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
        admin = msg.sender;
        multisig = _multisig;
        amountOfFactories = 1;
        vaultClosureFee = 100e18;
        abcGasFee = 10e18;
        beta = 1;
    }

    /* ======== SETTERS ======== */

    function proposeWLUser(address[] memory users) onlyAdmin external {
        pendingWLUserAddition = users;
    }

    function approveWLUser() onlyMultisig external {
        uint256 length = pendingWLUserAddition.length;
        for(uint256 i = 0; i < length; i++) {
            userWhitelist[pendingWLUserAddition[i]] = true;
        }
    }

    function proposedWLUserRemoval(address[] memory users) onlyAdmin external {
        pendingWLUserRemoval = users;
    }

    function approveWLUserRemoval() onlyMultisig external {
        uint256 length = pendingWLUserAddition.length;
        for(uint256 i = 0; i < length; i++) {
            userWhitelist[pendingWLUserAddition[i]] = false;
        }
    }

    function proposeWLAddresses(address[] memory collections) onlyAdmin external {
        pendingWLAdditions = collections;
    }

    function approveWLAddresses() onlyMultisig external {
        uint256 length = pendingWLAdditions.length;
        for(uint256 i = 0; i < length; i++) {
            collectionWhitelist[pendingWLAdditions[i]] = true;
        }
    }

    function proposedWLRemoval(address[] memory collections) onlyAdmin external {
        pendingWLRemoval = collections;
    }

    function approveWLRemoval() onlyMultisig external {
        uint256 length = pendingWLRemoval.length;
        for(uint256 i = 0; i < length; i++) {
            collectionWhitelist[pendingWLRemoval[i]] = false;
        }
    }

    function setBeta(uint256 _stage) onlyAdmin external {
        pendingBeta = _stage;
    }

    function approveBeta() onlyMultisig external {
        beta = pendingBeta;
    }

    function setMaxPoolsPerToken(uint256 _maxPoolsPerToken) onlyAdmin external {
        require(_maxPoolsPerToken <= 10);
        pendingMaxPoolsPerToken = _maxPoolsPerToken;
    }

    function approveMaxPoolsPerToken() onlyMultisig external {
        maxPoolsPerToken = pendingMaxPoolsPerToken;
    }

    function setInflation(uint256 _rate) onlyAdmin external {
        require(_rate <= 8 && _rate >= 2);
        pendingInflationRate = _rate;
    }

    function approveInflation() onlyMultisig external {
        inflationRate = pendingInflationRate;
    }

    function setCreditBonds(address _creditBonds) onlyAdmin external {
        pendingCreditBonds = _creditBonds;
    }

    function approveCreditBonds() onlyMultisig external {
        creditBonds = pendingCreditBonds;
    }

    function setPresale(address _presale) onlyAdmin external {
        pendingPresale = _presale;
    }

    function approvePresale() onlyMultisig external {
        presale = pendingPresale;
    }

    function proposeFactoryAddition(address _newFactory) onlyAdmin external {
        require(_newFactory != address(0), "Address is zero");
        pendingFactory = _newFactory;
    }

    function approveFactoryAddition() onlyMultisig external {
        factoryWhitelist[pendingFactory] = true;
        factoryVersions[amountOfFactories] = pendingFactory;
        amountOfFactories++;
    }

    function addAccreditedAddresses(address newAddress, address nft, uint256 id, uint256 version) external {
        require(
            factoryWhitelist[msg.sender]
            || accreditedAddresses[msg.sender]
        );
        if(nft != address(0)) {
            nftVaultVersion[nft][id] = version;
        }
        accreditedAddresses[newAddress] = true;
    }

    function addAccreditedAddressesMulti(address newAddress) external {
        require(factoryWhitelist[msg.sender]);
        accreditedAddresses[newAddress] = true;
    }

    function setTreasuryRate(uint256 rate) onlyAdmin external {
        pendingTreasuryRate = rate;

        emit TreasuryRateChangeProposed(treasuryRate, rate);
    }

    function approveRateChange() onlyMultisig external {
        treasuryRate = pendingTreasuryRate;

        emit TreasuryRateChangeApproved(treasuryRate);
    }

    function setMultisig(address _multisig) onlyAdmin external {
        require(_multisig != address(0), "Address is zero");
        pendingMultisig = _multisig;
    }

    function approveMultisigChange() onlyMultisig external {
        multisig = pendingMultisig;
    }

    function setAdmin(address _admin) onlyAdmin external {
        require(_admin != address(0), "Address is zero");
        pendingAdmin = _admin;
    }

    function approveAdminChange() onlyMultisig external {
        admin = pendingAdmin;
    }

    function setTreasury(address _abcTreasury) onlyAdmin external {
        require(_abcTreasury != address(0), "Address is zero");
        pendingTreasury = _abcTreasury;
    }

    function approveTreasuryChange() onlyMultisig external {
        abcTreasury = pendingTreasury;
    }

    function setToken(address _token) onlyAdmin external {
        require(_token != address(0), "Address is zero");
        pendingToken = _token;
    }

    function approveTokenChange() onlyMultisig external {
        abcToken = pendingToken;
    }

    function setVeToken(address _veToken) onlyAdmin external {
        require(_veToken != address(0), "Address is zero");
        pendingVeToken = _veToken;
    }

    function approveVeChange() onlyMultisig external {
        veAbcToken = pendingVeToken;
    }   

    function setEpochVault(address _epochVault) onlyAdmin external {
        require(_epochVault != address(0), "Address is zero");
        pendingEvault = _epochVault;
    }

    function approveEvaultChange() onlyMultisig external {
        epochVault = pendingEvault;
    }

    function setVaultFactory(address _factory) onlyAdmin external {
        require(_factory != address(0), "Address is zero");
        pendingFactory = _factory;
    }

    function approveFactoryChange() onlyMultisig external {
        factoryWhitelist[pendingFactory] = true;
    }

    function setClosureFee(uint256 _amount) onlyAdmin external {
        require(_amount <= 10000e18);
        pendingClosureFee = _amount;

        emit ClosureFeeChangeProposed(vaultClosureFee, _amount);
    }

    function approveFeeChange() onlyMultisig external {
        vaultClosureFee = pendingClosureFee;

        emit ClosureFeeChangeApproved(vaultClosureFee);
    }

    function setAbcGasFee(uint256 _amount) onlyAdmin external {
        require(_amount <= 1000e18);
        pendingGasFee = _amount;

        emit NetworkFeeChangeProposed(abcGasFee, _amount);
    }

    function approveGasFeeChange() onlyMultisig external {
        abcGasFee = pendingGasFee;

        emit NetworkFeeChangeApproved(abcGasFee);
    }

    function setBondMaxPremiumThreshold(uint256 _amount) onlyAdmin external {
        pendingBondMaxPremiumThreshold = _amount;

        emit ThresholdChangeProposed(bondMaxPremiumThreshold, pendingBondMaxPremiumThreshold);
    }

    function approveBondMaxPremiumThreshold() onlyMultisig external {
        bondMaxPremiumThreshold = pendingBondMaxPremiumThreshold;

        emit ThresholdApproved(bondMaxPremiumThreshold);
    }
}