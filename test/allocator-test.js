const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Allocator", function () {
    let
        deployer,
        MockNft,
        mockNft,
        mockNft2,
        user1,
        AbcToken,
        abcToken,
        Allocator,
        alloc,
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

      Factory = await ethers.getContractFactory("Factory");
      factory = await Factory.deploy(controller.address);

      AbcToken = await ethers.getContractFactory("ABCToken");
      abcToken = await AbcToken.deploy(controller.address);

      EpochVault = await ethers.getContractFactory("EpochVault");
      eVault = await EpochVault.deploy(controller.address, 86400);

      CreditBonds = await ethers.getContractFactory("CreditBonds");
      bonds = await CreditBonds.deploy(controller.address, eVault.address);

      Allocator = await ethers.getContractFactory("Allocator");
      alloc = await Allocator.deploy(controller.address, eVault.address);

      MockNft = await ethers.getContractFactory("MockNft");
      mockNft = await MockNft.deploy();
      mockNft2 = await MockNft.deploy();

      Vault = await ethers.getContractFactory("Vault");

      Closure = await ethers.getContractFactory("Closure");

      const setAdmin = await controller.setAdmin(deployer.address);
      await setAdmin.wait();
      const setBeta = await controller.setBeta(3);
      await setBeta.wait();
      const setCreditBonds = await controller.setCreditBonds(bonds.address);
      await setCreditBonds.wait();
      const proposeFactoryAddition1 = await controller.proposeFactoryAddition(factory.address);
      await proposeFactoryAddition1.wait();
      const approveFactoryAddition1 = await controller.approveFactoryAddition();
      await approveFactoryAddition1.wait();
      const setToken = await controller.setToken(abcToken.address);
      await setToken.wait();
      const setAllocator = await controller.setAllocator(alloc.address);
      await setAllocator.wait();
      const setEpochVault = await controller.setEpochVault(eVault.address);
      await setEpochVault.wait();
      const wlAddress = await controller.proposeWLUser([deployer.address]);
      await wlAddress.wait();
      const wlCollection = await controller.proposeWLAddresses([mockNft.address, mockNft2.address]);
      await wlCollection.wait();
      const confirmWlCollection = await controller.approveWLAddresses();
      await confirmWlCollection.wait();

      await abcToken.transfer(user1.address, '1000000000000000000000000000');
      await eVault.begin();

    });

    it("Proper compilation and setting", async function () {
      console.log("Contracts compiled and controller configured!");
    });

    it("Allocate to collection", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await alloc.depositAbc('100000000000000000000');
      expect(await alloc.getTokensLocked(deployer.address)).to.equal('100000000000000000000');
      await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
    });

    it("Allocate to collection - edge", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await alloc.depositAbc('100000000000000000000');
      expect(await alloc.getTokensLocked(deployer.address)).to.equal('100000000000000000000');
      for(let i = 0; i < 30; i++) {
        await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
        await network.provider.send("evm_increaseTime", [86400]);
        console.log("Current epoch:", (await eVault.getCurrentEpoch()).toString());
      }
    });

    it("Change collection allocation", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await alloc.depositAbc('100000000000000000000');
      await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
      await alloc.changeAllocation(mockNft.address, mockNft2.address, '100000000000000000000');
    });

    it("Auto allocate", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await alloc.depositAbc('100000000000000000000');
      await alloc.addAutoAllocation('100000000000000000000');
      expect(await alloc.getAmountAllocated(deployer.address, 0)).to.equal('100000000000000000000');
    });
    
    it("Claim rewards", async function () {
      await mockNft.mintNew();
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await alloc.depositAbc('2000000000000000000000');
      await alloc.addAutoAllocation('100000000000000000000');
      await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
      await alloc.bribeAuto(mockNft.address, { value:(1e18).toString() });
      await mockNft.approve(factory.address, '1');

      await factory.initiateMultiAssetVault(
        "HelloWorld"
      );
      
      let vaultAddress = await factory.vaultNames("HelloWorld", 0);
      let maPool = await Vault.attach(vaultAddress);

      await maPool.includeNft(
        await factory.encodeCompressedValue(
            [mockNft.address], 
            [1]
        )
      );

      await maPool.begin(1, 1000);

      await network.provider.send("evm_increaseTime", [86400]);
      await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
      
      let costPerToken = 1e15;
      let totalCost = 1.01 * costPerToken * 3000;
      await maPool.purchase(
          deployer.address,
          user1.address,
          [0, '1', '2'],
          ['1000', '1000', '1000'],
          1,
          2,
          { value: totalCost.toString() }
      );

      await network.provider.send("evm_increaseTime", [86400]);
      await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
      await maPool.connect(user1).sell(
        user1.address,
        0,
        1000
      );

      await network.provider.send("evm_increaseTime", [86400]);
      await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
      totalCost = costPerToken * 3000;
      await maPool.purchase(
        deployer.address,
        deployer.address,
        [0, '1', '2'],
        ['1000', '1000', '1000'],
        3,
        4,
        { value: totalCost.toString() }
      );
      console.log("Payout:", (await alloc.getRewards(deployer.address)).toString());
      await network.provider.send("evm_increaseTime", [86400 * 10]);
      await alloc.withdrawAbc();
    });

    it("Calculate proper boost - bribe based", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await alloc.depositAbc('2000000000000000000000');
      await alloc.connect(user1).depositAbc('2000000000000000000000');
      await alloc.addAutoAllocation('20000000000000000000');
      await alloc.connect(user1).addAutoAllocation('20000000000000000000');
      await alloc.bribeAuto(mockNft.address, { value: '20000000000000000000'});
      await network.provider.send("evm_increaseTime", [86401]);
      await alloc.depositAbc('2000000000000000000000');

      await alloc.calculateBoost(mockNft.address);
    });

    it("Calculate proper boost - bribe + natural allocation", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await alloc.depositAbc('2000000000000000000000');
      await alloc.connect(user1).depositAbc('2000000000000000000000');
      await alloc.allocateToCollection(mockNft.address, '10000000000000000000');
      await alloc.connect(user1).allocateToCollection(mockNft2.address, '10000000000000000000');
      await alloc.addAutoAllocation('10000000000000000000');
      await alloc.connect(user1).addAutoAllocation('10000000000000000000');
      await alloc.bribeAuto(mockNft.address, { value: '30000000000000000000'});
      await alloc.bribeAuto(mockNft2.address, { value: '70000000000000000000'});
      await network.provider.send("evm_increaseTime", [86400]);
      await alloc.depositAbc('2000000000000000000000');

      await alloc.calculateBoost(mockNft.address);
      await alloc.calculateBoost(mockNft2.address);
    });

});