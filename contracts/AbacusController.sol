//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

/// @title Abacus Controller
/// @author Gio Medici
/// @notice Abacus protocol controller contract that holds all relevant addresses and metrics 
contract AbacusController {

    /* ======== ADDRESS ======== */

    /// @notice proposed address for accredation (the right to mint EDC)
    address public pendingAccredation;

    /// @notice proposed list of users to be whitelisted for beta stage 1 
    address[] public pendingWLUserAddition;

    /// @notice proposed list of user to be removed from the whitelist for beta stage 1
    address[] public pendingWLUserRemoval;

    /// @notice proposed list of collection to be added to the collection whitelist
    address[] public pendingWLAdditions;

    /// @notice proposed list of collections to be removed from the collection whitelist
    address[] public pendingWLRemoval;

    /// @notice proposed recipient of pool trading fees
    address public pendingFeeRecipient;

    /// @notice recipient of pool trading fees
    address public feeRecipient;

    /// @notice proposed addition to addresses with permission *redacted*
    address public pendingSpecialPermissions;

    /// @notice contract address for Credit Bonds 
    address public creditBonds;

    /// @notice contract address for Presale
    address public presale;

    /// @notice proposed address of new admin
    address public pendingAdmin;

    /// @notice controller admin address (controlled by governance)
    address public admin;

    /// @notice proposed Treasury contract
    address public pendingTreasury;

    /// @notice contract address for Treasury
    address public abcTreasury;

    /// @notice contract address for ABC
    address public abcToken;

    /// @notice contract address for Allocator
    address public allocator;

    /// @notice contract address for Epoch Vault
    address public epochVault;

    /// @notice proposed address of new Factory contract
    address public pendingFactory;

    /// @notice contract address of NFT ETH
    address public nEth;

    /// @notice proposed address of new Multisig
    address public pendingMultisig;
    
    /// @notice controller multisig address (controlled by council)
    address public multisig;

    /* ======== BOOL ======== */

    /// @notice proposed status of ABC gas fee requirement
    bool public pendingGasFeeStatus;

    /// @notice status of ABC gas fee requirement
    bool public gasFeeStatus;

    /* ======== UINT ======== */

    uint256 public pendingPoolSizeLimit;

    uint256 public poolSizeLimit;

    /// @notice proposed fee to remove an NFT from a pool after signing (not to be confused with closure fee)
    uint256 public pendingRemovalFee;

    /// @notice fee to remove an NFT from a pool after signing
    uint256 public removalFee;

    /// @notice proposed fee to create a new pool
    uint256 public pendingCreationFee;

    /// @notice fee to create a new pool
    uint256 public creationFee;

    /// @notice proposed target percentage (units of 1 percentage point) of total ETH
    /// volume in pools to be directed towards NFT ETH stakers
    uint256 public pendingNEthTarget;

    /// @notice target percentage (units of 1 percentage point) of total ETH
    /// volume in pools to be directed towards NFT ETH stakers
    uint256 public nEthTarget;

    /// @notice proposed percentage cost (of the payout value) to close a pool (units of 
    /// 1 percentage point)
    uint256 public pendingClosureFee;

    /// @notice percentage cost (of the payout value) to close a pool (units of 
    /// 1 percentage point)
    uint256 public vaultClosureFee;

    /// @notice proposed fee (units of 1 percentage point) to be paid out in order
    /// to reserve the right to close an NFT in an epoch
    uint256 public pendingReservationFee;

    /// @notice fee (units of 1 percentage point) to be paid out in order
    /// to reserve the right to close an NFT in an epoch
    uint256 public reservationFee;

    /// @notice proposed percentage of revenue generated that is streamed to 
    /// the treasury
    uint256 public pendingTreasuryRate;

    /// @notice percentage of revenue generated that is streamed to the treasury
    uint256 public treasuryRate;

    /// @notice proposed max threshold (in units of ETH) that unlocks the full 2x multiplier
    /// for a spot pool trader
    uint256 public pendingBondMaxPremiumThreshold;

    /// @notice max threshold (in units of ETH) that unlocks the full 2x multiplier for a
    /// spot pool trader
    uint256 public bondMaxPremiumThreshold;

    /// @notice amount of live factories that can create emission producing spot pools 
    uint256 public amountOfFactories;

    /// @notice proposed beta stage
    uint256 public pendingBeta;

    /// @notice beta stage
    uint256 public beta;

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

    /// @notice track if a lender has access to mint NFT ETH
    /// [address] -> lender
    /// [bool] -> access status
    mapping(address => bool) public specialPermissions;

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
    
    event ProposeManualAccredation(address _addr);
    event ManualAccredationApproved(address _addr);
    event ManualAccredationRejected(address _addr);
    event NftEthSet(address _nftEth);
    event CreditBondsSet(address _creditBonds);
    event PresaleSet(address _presale);
    event TokenSet(address _token);
    event AllocatorSet(address _veToken);
    event EpochVaultSet(address _epochVault);
    event UpdateNftInUse(address pool, address nft, uint256 id, bool status);
    event ProposeRemovalFee(uint256 _fee);
    event RemovalFeeApproved(uint256 previous, uint256 _new);
    event RemovalFeeRejected(uint256 _fee);
    event ProposeCreationFee(uint256 creationFee);
    event CreationFeeApproved(uint256 previous, uint256 creationFee);
    event CreationFeeRejected(uint256 creationFee);
    event ProposeNEthTarget(uint256 target);
    event nEthTargetApproved(uint256 previousTarget, uint256 target);
    event nEthTargetRejected(uint256 target);
    event ProposeReservationFee(uint256 reservationFee);
    event ReservationFeeApproved(uint256 _prevFee, uint256 _newFee);
    event ReservationFeeRejected(uint256 reservationFee);
    event ProposeSpecialPermissionsAddition(address _newPermission);
    event SpecialPermissionsProposalApproved(address _newPermission);
    event SpecialPermissionsProposalRejected(address _newPermission);
    event ProposeFeeRecipient(address _newRecipient);
    event FeeRecipientApproved(address _previousRecipient, address _newRecipient);
    event FeeRecipientRejected(address _newRecipient);
    event ProposeTurnOnGas();
    event TurnOnGasApproved();
    event TurnOnGasRejected();
    event ProposeWLUserAddition(address[] _user);
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
    event ProposeTreasuryRate(uint256 rate);
    event TreasuryRateApproved(uint256 previous, uint256 rate);
    event TreasuryRateRejected(uint256 rate);
    event ProposeNewMultisig(address _multisig);
    event MultisigApproved(address previous, address _multisig);
    event MultisigRejected(address _multisig);
    event ProposeNewAdmin(address _admin);
    event AdminApproved(address previous, address _admin);
    event AdminRejected(address _admin);
    event ProposeNewTreasury(address _treasury);
    event TreasuryApproved(address previous, address _treasury);
    event TreasuryRejected(address _treasury);
    event ProposeClosureFee(uint256 closureFee);
    event ClosureFeeApproved(uint256 previous, uint256 closureFee);
    event ClosureFeeRejected(uint256 closureFee);
    event ProposeMaxBondThreshold(uint256 amount);
    event MaxBondThresholdApproved(uint256 previous, uint256 amount);
    event MaxBondThresholdRejected(uint256 amount);

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
        vaultClosureFee = 3;
        beta = 1;
    }

    /* ======== IMMUTABLE SETTERS ======== */

    function setNftEth(address _nEth) external onlyMultisig {
        require(nEth == address(0), "Already set");
        nEth = _nEth;
        emit NftEthSet(_nEth);
    }

    function setCreditBonds(address _creditBonds) external onlyMultisig {
        require(creditBonds == address(0), "Already set");
        creditBonds = _creditBonds;
        emit CreditBondsSet(_creditBonds);
    }

    function setPresale(address _presale) external onlyMultisig {
        require(presale == address(0), "Already set");
        presale = _presale;
        emit PresaleSet(_presale);
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

    /* ======== AUTOMATED SETTERS ======== */

    function addAccreditedAddressesMulti(address newAddress) external {
        require(factoryWhitelist[msg.sender] || accreditedAddresses[msg.sender]);
        accreditedAddresses[newAddress] = true;
    }

    function updateNftUsage(address pool, address nft, uint256 id, bool status) external {
        require(factoryWhitelist[msg.sender] || this.accreditedAddresses(msg.sender));
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

    /* ======== PROPOSALS ADDRESSES ======== */

    function proposeManualAccredation(address _addr) external onlyMultisig {
        require(pendingAccredation == address(0), "Must vote first");
        pendingAccredation = _addr;
        emit ProposeManualAccredation(_addr);
    }

    function approveManualAccredation() external onlyAdmin {
        emit ManualAccredationApproved(pendingAccredation);
        accreditedAddresses[pendingAccredation] = true;
        delete pendingAccredation;
    }

    function rejectManualAccredation() external onlyAdmin {
        emit ManualAccredationRejected(pendingAccredation);
        delete pendingAccredation;
    }

    function proposeSpecialPermissions(address _newPermission) external onlyMultisig {
        require(pendingSpecialPermissions == address(0), "Must vote first");
        pendingSpecialPermissions = _newPermission;
        emit ProposeSpecialPermissionsAddition(_newPermission);
    }

    function approveSpecialPermissions() external onlyAdmin {
        specialPermissions[pendingSpecialPermissions] = true;
        emit SpecialPermissionsProposalApproved(pendingSpecialPermissions);
        delete pendingSpecialPermissions;
    }

    function rejectSpecialPermissions() external onlyAdmin {
        emit SpecialPermissionsProposalRejected(pendingSpecialPermissions);
        delete pendingSpecialPermissions;
    }

    function proposeFeeRecipient(address _newRecipient) external onlyMultisig {
        require(pendingFeeRecipient == address(0), "Must vote first");
        pendingFeeRecipient = _newRecipient;
        emit ProposeFeeRecipient(_newRecipient);
    }

    function approveFeeRecipient() external onlyAdmin {
        emit FeeRecipientApproved(feeRecipient, pendingFeeRecipient);
        feeRecipient = pendingFeeRecipient;
        delete pendingFeeRecipient;
    }

    function rejectFeeRecipient() external onlyAdmin {
        emit FeeRecipientRejected(pendingFeeRecipient);
        delete pendingFeeRecipient;
    }

    function proposeWLUser(address[] memory users) external onlyMultisig {
        require(pendingWLUserAddition.length == 0, "Must vote first");
        pendingWLUserAddition = users;
        emit ProposeWLUserAddition(users);
    }

    function approveWLUser() external onlyAdmin {
        uint256 length = pendingWLUserAddition.length;
        emit WLUserApproved(pendingWLUserAddition);
        for(uint256 i = 0; i < length; i++) {
            userWhitelist[pendingWLUserAddition[i]] = true;
        }
        delete pendingWLUserAddition;
    }

    function rejectWLUser() external onlyAdmin {
        emit WLUserRejected(pendingWLUserAddition);
        delete pendingWLUserAddition;
    }

    function proposedWLUserRemoval(address[] memory users) external onlyMultisig {
        require(pendingWLUserRemoval.length == 0, "Must vote first");
        pendingWLUserRemoval = users;
        emit ProposeWLUserRemoval(users);
    }

    function approveWLUserRemoval() external onlyAdmin {
        uint256 length = pendingWLUserRemoval.length;
        emit WLUserRemovalApproved(pendingWLUserRemoval);
        for(uint256 i = 0; i < length; i++) {
            userWhitelist[pendingWLUserRemoval[i]] = false;
        }
        delete pendingWLUserRemoval;
    }

    function rejectWLUserRemoval() external onlyAdmin {
        emit WLUserRemovalRejected(pendingWLUserRemoval);
        delete pendingWLUserRemoval;
    }

    function proposeWLAddresses(address[] memory collections) external onlyMultisig {
        require(pendingWLAdditions.length == 0, "Must vote first");
        pendingWLAdditions = collections;
        emit ProposeWLAddressesAddition(collections);
    }

    function approveWLAddresses() external onlyAdmin {
        uint256 length = pendingWLAdditions.length;
        emit WLAddressesAdditionApproved(pendingWLAdditions);
        for(uint256 i = 0; i < length; i++) {
            collectionWhitelist[pendingWLAdditions[i]] = true;
        }
        delete pendingWLAdditions;
    }

    function rejectWLAddresses() external onlyAdmin {
        emit WLAddressesAdditionRejected(pendingWLAdditions);
        delete pendingWLAdditions;
    }

    function proposedWLRemoval(address[] memory collections) external onlyMultisig {
        require(pendingWLRemoval.length == 0, "Must vote first");
        pendingWLRemoval = collections;
        emit ProposeWLAddressesRemoval(collections);
    }

    function approveWLRemoval() external onlyAdmin {
        uint256 length = pendingWLRemoval.length;
        emit WLAddressesRemovalApproved(pendingWLRemoval);
        for(uint256 i = 0; i < length; i++) {
            collectionWhitelist[pendingWLRemoval[i]] = false;
        }
        delete pendingWLRemoval;
    }

    function rejectWLRemoval() external onlyAdmin {
        emit WLAddressesRemovalRejected(pendingWLRemoval);
        delete pendingWLRemoval;
    }

    function proposeFactoryAddition(address _newFactory) external onlyMultisig {
        require(pendingFactory == address(0), "Must vote first");
        require(_newFactory != address(0), "Address is zero");
        pendingFactory = _newFactory;
        emit ProposeFactoryAddition(_newFactory);
    }

    function approveFactoryAddition() external onlyAdmin {
        factoryWhitelist[pendingFactory] = true;
        factoryVersions[amountOfFactories] = pendingFactory;
        amountOfFactories++;
        emit FactoryAdditionApproved(pendingFactory);
        delete pendingFactory;
    }

    function rejectFactoryAddition() external onlyAdmin {
        emit FactoryAdditionRejected(pendingFactory);
        delete pendingFactory;
    }

    function setMultisig(address _multisig) external onlyMultisig {
        require(pendingMultisig == address(0), "Must vote first");
        require(_multisig != address(0), "Address is zero");
        pendingMultisig = _multisig;
        emit ProposeNewMultisig(_multisig);
    }

    function approveMultisigChange() external onlyAdmin {
        emit MultisigApproved(multisig, pendingMultisig);
        multisig = pendingMultisig;
        delete pendingMultisig;
    }

    function rejectMultisigChange() external onlyAdmin {
        emit MultisigRejected(pendingMultisig);
        delete pendingMultisig;
    }

    function setAdmin(address _admin) external onlyMultisig {
        require(pendingAdmin == address(0), "Must vote first");
        require(_admin != address(0), "Address is zero");
        pendingAdmin = _admin;
        emit ProposeNewAdmin(_admin);
    }

    function approveAdminChange() external onlyAdmin {
        emit AdminApproved(admin, pendingAdmin);
        admin = pendingAdmin;
        delete pendingAdmin;
    }

    function rejectAdminChange() external onlyAdmin {
        emit AdminRejected(pendingAdmin);
        delete pendingAdmin;
    }

    function setTreasury(address _abcTreasury) external onlyMultisig {
        require(pendingTreasury == address(0), "Must vote first");
        require(_abcTreasury != address(0), "Address is zero");
        pendingTreasury = _abcTreasury;
        emit ProposeNewTreasury(_abcTreasury);
    }

    function approveTreasuryChange() external onlyAdmin {
        emit TreasuryApproved(abcTreasury, pendingTreasury);
        abcTreasury = pendingTreasury;
        delete pendingTreasury;
    }

    function rejectTreasuryChange() external onlyAdmin {
        emit TreasuryRejected(pendingTreasury);
        delete pendingTreasury;
    }

    /* ======== PROPOSALS METRICS ======== */

    function proposePoolSizeLimit(uint256 _sizeLimit) external onlyMultisig {
        require(pendingPoolSizeLimit == 0, "Must vote first");
        pendingPoolSizeLimit = _sizeLimit;

        emit ProposePoolSizeLimit(_sizeLimit);
    }

    function approvePoolSizeLimit() external onlyAdmin {
        emit PoolSizeLimitApproved(poolSizeLimit, pendingPoolSizeLimit);
        poolSizeLimit = pendingPoolSizeLimit;
        delete pendingPoolSizeLimit;
    }

    function rejectPoolSizeLimit() external onlyAdmin {
        emit PoolSizeLimitRejected(pendingPoolSizeLimit);
        delete pendingPoolSizeLimit;
    }

    function proposeRemovalFee(uint256 _fee) external onlyMultisig {
        require(pendingRemovalFee == 0, "Must vote first");
        require(_fee <= 200e18);
        pendingRemovalFee = _fee;
        emit ProposeRemovalFee(_fee);
    }

    function approveRemovalFee() external onlyAdmin {
        emit RemovalFeeApproved(removalFee, pendingRemovalFee);
        removalFee = pendingRemovalFee;
        delete pendingRemovalFee;
    }

    function rejectRemovalFee() external onlyAdmin {
        emit RemovalFeeRejected(pendingRemovalFee);
        delete pendingRemovalFee;
    }

    function proposeCreationFee(uint256 _amount) external onlyMultisig {
        require(pendingCreationFee == 0, "Must vote first"); 
        require(_amount <= 2000e18);
        pendingCreationFee = _amount;
        emit ProposeCreationFee(pendingCreationFee);
    }

    function approveCreationFee() external onlyAdmin {
        emit CreationFeeApproved(creationFee, pendingCreationFee);
        creationFee = pendingCreationFee;
        delete pendingCreationFee;
    }

    function rejectCreationFee() external onlyAdmin {
        emit CreationFeeRejected(pendingCreationFee);
        delete pendingCreationFee;
    }
 
    function proposeNEthTarget(uint256 _amount) external onlyMultisig {
        require(pendingNEthTarget == 0, "Must vote first");
        require(_amount <= 6);
        pendingNEthTarget = _amount;
        emit ProposeNEthTarget(_amount);
    }

    function approveNEthTarget() external onlyAdmin {
        emit nEthTargetApproved(nEthTarget, pendingNEthTarget);
        nEthTarget = pendingNEthTarget;
        delete pendingNEthTarget;
    }

    function rejectNEthTarget() external onlyAdmin {
        emit nEthTargetRejected(pendingNEthTarget);
        delete pendingNEthTarget;
    }

    function proposeReservationFee(uint256 _pendingReservationFee) external onlyMultisig {
        require(pendingReservationFee == 0, "Must vote first");
        require(_pendingReservationFee <= 200);
        pendingReservationFee = _pendingReservationFee;
        emit ProposeReservationFee(pendingReservationFee);
    }

    function approveReservationFee() external onlyAdmin {
        emit ReservationFeeApproved(reservationFee, pendingReservationFee);
        reservationFee = pendingReservationFee;
        delete pendingReservationFee;
    }

    function rejectReservationFee() external onlyAdmin {
        emit ReservationFeeRejected(pendingReservationFee);
        delete pendingReservationFee;
    }

    function proposeTurnOnGas() external onlyMultisig {
        require(pendingGasFeeStatus == false, "Must vote first");
        require(!pendingGasFeeStatus);
        pendingGasFeeStatus = true;
        emit ProposeTurnOnGas();
    }

    function approveTurnOnGas() external onlyAdmin {
        gasFeeStatus = pendingGasFeeStatus;
        delete pendingGasFeeStatus;
        emit TurnOnGasApproved();
    }

    function rejectTurnOnGas() external onlyMultisig {
        delete pendingGasFeeStatus;
        emit TurnOnGasRejected();
    }

    function setBeta(uint256 _stage) external onlyMultisig {
        require(pendingBeta == 0, "Must vote first");
        pendingBeta = _stage;
        emit ProposeBetaStage(_stage);
    }

    function approveBeta() external onlyAdmin {
        beta = pendingBeta;
        emit BetaStageApproved(pendingBeta);
        delete pendingBeta;
    }

    function rejectBeta() external onlyAdmin {
        emit BetaStageRejected(pendingBeta);
        delete pendingBeta;
    }

    function setTreasuryRate(uint256 rate) external onlyMultisig {
        require(pendingTreasuryRate == 0, "Must vote first");
        require(rate <= 10);
        pendingTreasuryRate = rate;
        emit ProposeTreasuryRate(rate);
    }

    function approveRateChange() external onlyAdmin {
        emit TreasuryRateApproved(treasuryRate, pendingTreasuryRate);
        treasuryRate = pendingTreasuryRate;
        delete pendingTreasuryRate;
    }

    function rejectRateChange() external onlyAdmin {
        emit TreasuryRateRejected(pendingTreasuryRate);
        delete pendingTreasuryRate;
    }

    function setClosureFee(uint256 _amount) external onlyMultisig {
        require(pendingClosureFee == 0, "Must vote first");
        require(_amount <= 4);
        pendingClosureFee = _amount;
        emit ProposeClosureFee(_amount);
    }

    function approveFeeChange() external onlyAdmin {
        emit ClosureFeeApproved(vaultClosureFee, pendingClosureFee);
        vaultClosureFee = pendingClosureFee;
        delete pendingClosureFee;
    }

    function rejectFeeChange() external onlyAdmin {
        emit ClosureFeeRejected(pendingClosureFee);
        delete pendingClosureFee;
    }

    function setBondMaxPremiumThreshold(uint256 _amount) external onlyMultisig {
        require(pendingBondMaxPremiumThreshold == 0, "Must vote first");
        require(_amount <= 200e18);
        pendingBondMaxPremiumThreshold = _amount;
        emit ProposeMaxBondThreshold(_amount);
    }

    function approveBondMaxPremiumThreshold() external onlyAdmin {
        emit MaxBondThresholdApproved(bondMaxPremiumThreshold, pendingBondMaxPremiumThreshold);
        bondMaxPremiumThreshold = pendingBondMaxPremiumThreshold;
        delete pendingBondMaxPremiumThreshold;
    }

    function rejectBondMaxPremiumThreshold() external onlyAdmin {
        emit MaxBondThresholdRejected(pendingBondMaxPremiumThreshold);
        delete pendingBondMaxPremiumThreshold;
    }
}