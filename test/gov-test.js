const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MA Vault", function () {
    let
        deployer,
        MockNft,
        mockNft,
        user1,
        user2,
        VaultFactoryMulti,
        factoryMulti,
        VaultMulti,
        Treasury,
        treasury,
        AbcToken,
        abcToken,
        Allocator,
        alloc,
        ClosePoolMulti,
        NftEth,
        nEth,
        AbacusController,
        controller,
        EpochVault,
        eVault
    
    beforeEach(async() => {
      [
        deployer, 
        user1, 
        user2 
      ] = await ethers.getSigners();

    provider = ethers.getDefaultProvider();

    AbacusController = await ethers.getContractFactory("AbacusController");
    controller = await AbacusController.deploy(deployer.address);

    Treasury = await ethers.getContractFactory("Treasury");
    treasury = await Treasury.deploy(deployer.address);

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.deploy(controller.address);

    Factory = await ethers.getContractFactory("Factory");
    factory2 = await Factory.deploy(controller.address);

    AbcToken = await ethers.getContractFactory("ABCToken");
    abcToken = await AbcToken.deploy(controller.address);

    Governor = await ethers.getContractFactory("Governor");
    governor = await Governor.deploy(controller.address, abcToken.address);

    // BribeFactory = await ethers.getContractFactory("BribeFactory");
    // bribe = await BribeFactory.deploy(controller.address);

    EpochVault = await ethers.getContractFactory("EpochVault");
    eVault = await EpochVault.deploy(controller.address, 86400 * 30);

    CreditBonds = await ethers.getContractFactory("CreditBonds");
    bonds = await CreditBonds.deploy(controller.address, eVault.address);

    Allocator = await ethers.getContractFactory("Allocator");
    alloc = await Allocator.deploy(controller.address, eVault.address);

    MockNft = await ethers.getContractFactory("MockNft");
    mockNft = await MockNft.deploy();

    MockNft = await ethers.getContractFactory("MockNft");
    mockNft2 = await MockNft.deploy();

    NftEth = await ethers.getContractFactory("NftEth");
    nEth = await NftEth.deploy(controller.address);

    Vault = await ethers.getContractFactory("Vault");

    Closure = await ethers.getContractFactory("Closure");

    const setBeta = await controller.setBeta(3);
    await setBeta.wait();
    const setCreditBonds = await controller.setCreditBonds(bonds.address);
    await setCreditBonds.wait();
    const setToken = await controller.setToken(abcToken.address);
    await setToken.wait();
    const setAllocator = await controller.setAllocator(alloc.address);
    await setAllocator.wait();
    const setEpochVault = await controller.setEpochVault(eVault.address);
    await setEpochVault.wait();
    const setAdmin = await controller.setAdmin(governor.address);
    await setAdmin.wait();
    const wlAddress = await controller.proposeWLUser([deployer.address]);
    await wlAddress.wait();

    await abcToken.transfer(user1.address, '1000000000000000000000000000');
    await eVault.begin();

    });

    it("Proper compilation and setting", async function () {
        console.log("Contracts compiled and controller configured!");
    });

    it("Positional movement - acceptance", async function () {
        await abcToken.approve(governor.address, '50000000000000000000000000');
        await governor.lockCredit('50000000000000000000000000');
        await governor.proposePositionalMovement('3000000000000000000000000');
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.votePositionalMovement(true, '500000000000000000000000000');
        await governor.connect(user1).votePositionalMovement(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.movementAcceptance();
        expect(await governor.positionalMovement()).to.equal('3000000000000000000000000');
    });

    it("Positional movement - rejection lost vote", async function () {
        await abcToken.approve(governor.address, '50000000000000000000000000');
        await governor.lockCredit('50000000000000000000000000');
        await governor.proposePositionalMovement('3000000000000000000000000');
        await abcToken.approve(governor.address, '250000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '500000000000000000000000000');
        await governor.votePositionalMovement(true, '250000000000000000000000000');
        await governor.connect(user1).votePositionalMovement(false, '500000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.movementRejection();
        expect(await governor.positionalMovement()).to.equal('2000000000000000000000000');
    });

    it("Positional movement - rejection quorum missed", async function () {
        await abcToken.approve(governor.address, '50000000000000000000000000');
        await governor.lockCredit('50000000000000000000000000');
        await governor.proposePositionalMovement('3000000000000000000000000');
        await abcToken.approve(governor.address, '250000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '500000000000000000000000000');
        await governor.votePositionalMovement(false, '25000000000000000000000');
        await governor.connect(user1).votePositionalMovement(true, '50000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.movementRejection();
        expect(await governor.positionalMovement()).to.equal('2000000000000000000000000');
    });

    it("Add collection - acceptance", async function () {
        await abcToken.approve(governor.address, '20000000000000000000000000');
        await governor.lockCredit('20000000000000000000000000');
        await governor.proposeNewCollection([mockNft2.address]);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteNewCollections(true, '500000000000000000000000000');
        await governor.connect(user1).voteNewCollections(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.newCollectionAcceptance();
        expect(await controller.collectionWhitelist(mockNft2.address)).to.equal(true);
    });

    it("Add collection - rejection lost vote", async function () {
        await abcToken.approve(governor.address, '20000000000000000000000000');
        await governor.lockCredit('20000000000000000000000000');
        await governor.proposeNewCollection([mockNft2.address]);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteNewCollections(false, '500000000000000000000000000');
        await governor.connect(user1).voteNewCollections(true, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.newCollectionRejection();
        expect(await controller.collectionWhitelist(mockNft2.address)).to.equal(false);
    });

    it("Add collection - rejection quorum missed", async function () {
        await abcToken.approve(governor.address, '20000000000000000000000000');
        await governor.lockCredit('20000000000000000000000000');
        await governor.proposeNewCollection([mockNft2.address]);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteNewCollections(false, '500000000000000000000000');
        await governor.connect(user1).voteNewCollections(true, '2500000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.newCollectionRejection();
        expect(await controller.collectionWhitelist(mockNft2.address)).to.equal(false);
    });

    it("Remove collection - acceptance", async function () {
        await abcToken.approve(governor.address, '20000000000000000000000000');
        await governor.lockCredit('20000000000000000000000000');
        await governor.proposeRemoveCollection([mockNft2.address]);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteRemoveCollection(true, '500000000000000000000000000');
        await governor.connect(user1).voteRemoveCollection(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.removeCollectionAcceptance();
    });
    
    it("Remove collection - rejection lost vote", async function () {
        await abcToken.approve(governor.address, '20000000000000000000000000');
        await governor.lockCredit('20000000000000000000000000');
        await governor.proposeRemoveCollection([mockNft2.address]);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteRemoveCollection(false, '500000000000000000000000000');
        await governor.connect(user1).voteRemoveCollection(true, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.removeCollectionRejection();
    });

    it("Remove collection - rejection quorum missed", async function () {
        await abcToken.approve(governor.address, '20000000000000000000000000');
        await governor.lockCredit('20000000000000000000000000');
        await governor.proposeRemoveCollection([mockNft2.address]);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteRemoveCollection(true, '500000000000000000000000');
        await governor.connect(user1).voteRemoveCollection(false, '250000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.removeCollectionRejection();
    });

    it("Add factory - acceptance", async function () {
        await abcToken.approve(governor.address, '100000000000000000000000000');
        await governor.lockCredit('100000000000000000000000000');
        await governor.proposeFactoryAddition(factory2.address);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(true, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await expect(governor.factoryAdditionAcceptance()).to.reverted;
        await network.provider.send("evm_increaseTime", [86401 * 7]);
        await governor.factoryAdditionAcceptance();
    });

    it("Add factory - rejection lost vote", async function () {
        await abcToken.approve(governor.address, '100000000000000000000000000');
        await governor.lockCredit('100000000000000000000000000');
        await governor.proposeFactoryAddition(factory2.address);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(false, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(true, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.factoryAdditionRejection();
    });

    it("Add factory - rejection quorum missed", async function () {
        await abcToken.approve(governor.address, '100000000000000000000000000');
        await governor.lockCredit('100000000000000000000000000');
        await governor.proposeFactoryAddition(factory2.address);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(true, '50000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(false, '25000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.factoryAdditionRejection();
    });

    it("Add factory - challenge - acceptance", async function () {
        await abcToken.approve(governor.address, '100000000000000000000000000');
        await governor.lockCredit('100000000000000000000000000');
        await governor.proposeFactoryAddition(factory2.address);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(true, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.challengeAdditionVote();
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(true, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.factoryAdditionAcceptance();
    });

    it("Add factory - challenge - rejection", async function () {
        await abcToken.approve(governor.address, '100000000000000000000000000');
        await governor.lockCredit('100000000000000000000000000');
        await governor.proposeFactoryAddition(factory2.address);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(true, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.challengeAdditionVote();
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(false, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(true, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.factoryAdditionRejection();
    });

    it("Claim credit", async function () {
        await abcToken.approve(governor.address, '100000000000000000000000000');
        await governor.lockCredit('100000000000000000000000000');
        await governor.proposeFactoryAddition(factory2.address);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(true, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.challengeAdditionVote();
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(false, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(true, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.factoryAdditionRejection();

        await network.provider.send("evm_increaseTime", [86401 * 40]);
        await governor.claimCredit();
    });

    it("Claim vote locked", async function () {
        await abcToken.approve(governor.address, '100000000000000000000000000');
        await governor.lockCredit('100000000000000000000000000');
        await governor.proposeFactoryAddition(factory2.address);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(true, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.challengeAdditionVote();
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(false, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(true, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.factoryAdditionRejection();

        await network.provider.send("evm_increaseTime", [86401 * 40]);
        await governor.claimVoteLocked();
    });

    it("Proposal time restriction", async function () {
        await abcToken.approve(governor.address, '100000000000000000000000000');
        await governor.lockCredit('100000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 15]);
        await expect(governor.proposeFactoryAddition(factory2.address)).to.reverted;
        await network.provider.send("evm_increaseTime", [86401 * 16]);
        await governor.proposeFactoryAddition(factory2.address);
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(true, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(false, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 15]);
        await governor.challengeAdditionVote();
        await abcToken.approve(governor.address, '500000000000000000000000000');
        await abcToken.connect(user1).approve(governor.address, '250000000000000000000000000');
        await governor.voteFactoryAddition(false, '500000000000000000000000000');
        await governor.connect(user1).voteFactoryAddition(true, '250000000000000000000000000');
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await governor.factoryAdditionRejection();
    });
});