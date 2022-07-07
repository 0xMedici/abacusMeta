const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Epoch Vault", function () {
    let
        deployer,
        MockNft,
        mockNft,
        user1,
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

      AbcToken = await ethers.getContractFactory("ABCToken");
      abcToken = await AbcToken.deploy(controller.address);

    //   BribeFactory = await ethers.getContractFactory("BribeFactory");
    //   bribe = await BribeFactory.deploy(controller.address);

      EpochVault = await ethers.getContractFactory("EpochVault");
      eVault = await EpochVault.deploy(controller.address, 86400);

      CreditBonds = await ethers.getContractFactory("CreditBonds");
      bonds = await CreditBonds.deploy(controller.address, eVault.address);

      Allocator = await ethers.getContractFactory("Allocator");
      alloc = await Allocator.deploy(controller.address, eVault.address);

      MockNft = await ethers.getContractFactory("MockNft");
      mockNft = await MockNft.deploy();

      NftEth = await ethers.getContractFactory("NftEth");
      nEth = await NftEth.deploy(controller.address);

      Vault = await ethers.getContractFactory("Vault");

      Closure = await ethers.getContractFactory("Closure");

      const setNftEth = await controller.setNftEth(nEth.address);
      await setNftEth.wait();
      const setBeta = await controller.setBeta(3);
      await setBeta.wait();
      const approveBeta = await controller.approveBeta();
      await approveBeta.wait();
      const setCreditBonds = await controller.setCreditBonds(bonds.address);
      await setCreditBonds.wait();
      const proposeFactoryAddition1 = await controller.proposeFactoryAddition(factory.address);
      await proposeFactoryAddition1.wait();
      const approveFactoryAddition1 = await controller.approveFactoryAddition();
      await approveFactoryAddition1.wait();
      const setTreasury = await controller.setTreasury(treasury.address);
      await setTreasury.wait();
      const approveTreasuryChange = await controller.approveTreasuryChange();
      await approveTreasuryChange.wait();
      const setToken = await controller.setToken(abcToken.address);
      await setToken.wait();
      const setAllocator = await controller.setAllocator(alloc.address);
      await setAllocator.wait();
      const setEpochVault = await controller.setEpochVault(eVault.address);
      await setEpochVault.wait();
      const wlAddress = await controller.proposeWLUser([deployer.address]);
      await wlAddress.wait();
      const wlCollection = await controller.proposeWLAddresses([mockNft.address]);
      await wlCollection.wait();
      const confirmWlCollection = await controller.approveWLAddresses();
      await confirmWlCollection.wait();

      await abcToken.transfer(user1.address, '1000000000000000000000000000');
      await eVault.begin();

    });

  it("Proper compilation and setting", async function () {
    console.log("Contracts compiled and controller configured!");
  });

  it("Test update epoch - non boosted", async function () {
    await abcToken.transfer(user1.address, '1000000000000000000000000');
    await alloc.depositAbc('2000000000000000000000');
    await network.provider.send("evm_increaseTime", [86400]);
    await alloc.depositAbc('2000000000000000000000');
    
    expect(await eVault.getCollectionBoost(mockNft.address)).to.equal(100);
  });

  it("Test update epoch - boosted", async function () {
    await abcToken.transfer(user1.address, '1000000000000000000000000');
    await alloc.depositAbc('2000000000000000000000');
    await alloc.allocateToCollection(mockNft.address, '10000000000000000000');
    await network.provider.send("evm_increaseTime", [86400]);
    await alloc.depositAbc('2000000000000000000000');
    
    expect(await eVault.getCollectionBoost(mockNft.address)).to.equal(200);
  });

  it("Claim emissions rewards", async function () {
    await mockNft.mintNew();
    await mockNft.mintNew();
    await mockNft.mintNew();
    await mockNft.mintNew();
    await mockNft.mintNew();
    await abcToken.transfer(user1.address, '1000000000000000000000000');
    await factory.initiateMultiAssetVault(
        "HelloWorld"
    );

    let vaultAddress = await factory.vaultNames("HelloWorld", 0);
    let maPool = await Vault.attach(vaultAddress);

    await maPool.includeNft(
        await factory.encodeCompressedValue(
            [mockNft.address, mockNft.address, mockNft.address],
            [1, 2, 3],
        )
    );

    await maPool.begin(3);
    await factory.signMultiAssetVault(
        0,
        [mockNft.address, mockNft.address, mockNft.address],
        [1,2,3],
        mockNft.address
    );

    let costPerToken = 1e15;
    let totalCost = costPerToken * 3000 * 3;
    await maPool.purchase(
        deployer.address,
        deployer.address,
        [0, '1', '2'],
        ['3000', '3000', '3000'],
        0,
        2,
        { value: totalCost.toString() }
    );
    await network.provider.send("evm_increaseTime", [86400 * 2]);
    await maPool.sell(
      deployer.address,
      0,
      1000
    );

    await network.provider.send("evm_increaseTime", [86400]);
    await eVault.claimAbcReward(deployer.address, 0);
    await eVault.claimAbcReward(deployer.address, 1);
    await eVault.claimAbcReward(deployer.address, 2);
  });
});