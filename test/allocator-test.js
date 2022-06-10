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

      VaultFactoryMulti = await ethers.getContractFactory("VaultFactoryMulti");
      factoryMulti = await VaultFactoryMulti.deploy(controller.address);

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
      mockNft2 = await MockNft.deploy();

      NftEth = await ethers.getContractFactory("NftEth");
      nEth = await NftEth.deploy(controller.address);

      VaultMulti = await ethers.getContractFactory("VaultMulti");

      ClosePoolMulti = await ethers.getContractFactory("ClosePoolMulti");

      const setReservationFee = await controller.proposeReservationFee(1);
      await setReservationFee.wait();
      const approveReservationFee = await controller.approveReservationFee();
      await approveReservationFee.wait();
      const setNftEth = await controller.setNftEth(nEth.address);
      await setNftEth.wait();
      const setBeta = await controller.setBeta(3);
      await setBeta.wait();
      const approveBeta = await controller.approveBeta();
      await approveBeta.wait();
      const setCreditBonds = await controller.setCreditBonds(bonds.address);
      await setCreditBonds.wait()
      const setBondPremium = await controller.setBondMaxPremiumThreshold((100e18).toString());
      await setBondPremium.wait();
      const approveBondPremium = await controller.approveBondMaxPremiumThreshold();
      await approveBondPremium.wait();
      const proposeFactoryAddition1 = await controller.proposeFactoryAddition(factoryMulti.address);
      await proposeFactoryAddition1.wait()
      const approveFactoryAddition1 = await controller.approveFactoryAddition();
      await approveFactoryAddition1.wait()
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
      const changeTreasuryRate = await controller.setTreasuryRate(10);
      await changeTreasuryRate.wait();
      const approveRateChange = await controller.approveRateChange();
      await approveRateChange.wait();
      const wlAddress = await controller.proposeWLUser([deployer.address]);
      await wlAddress.wait();
      const confirmWlAddress = await controller.approveWLUser();
      await confirmWlAddress.wait();
      const wlCollection = await controller.proposeWLAddresses([mockNft.address, mockNft2.address]);
      await wlCollection.wait();
      const confirmWlCollection = await controller.approveWLAddresses();
      await confirmWlCollection.wait();
      const setPoolSizeLimit = await controller.proposePoolSizeLimit(50);
      await setPoolSizeLimit.wait();
      const approvePoolSizeLimit = await controller.approvePoolSizeLimit();
      await approvePoolSizeLimit.wait();

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
      await mockNft.approve(factoryMulti.address, '1');

      await expect(factoryMulti.initiateMultiAssetVault(
          [mockNft.address],
          [1],
          3
      )).to.reverted;

      await factoryMulti.initiateMultiAssetVault(
        [mockNft.address],
        [1],
        1
      );
      
      let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
      let vault = await VaultMulti.attach(vaultAddress);
      await factoryMulti.signMultiAssetVault(
          0,
          [mockNft.address],
          [1],
          mockNft.address
      );

      await network.provider.send("evm_increaseTime", [86400]);
      await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
      
      let costPerToken = 1e15;
      let totalCost = 1.01 * costPerToken * 3000;
      await vault.purchase(
          deployer.address,
          user1.address,
          [0, '1', '2'],
          ['1000', '1000', '1000'],
          1,
          2,
          0,
          { value: totalCost.toString() }
      );

      await network.provider.send("evm_increaseTime", [86400]);
      await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
      await vault.connect(user1).sell(
        user1.address,
        0,
        1000
      );

      await network.provider.send("evm_increaseTime", [86400]);
      await alloc.allocateToCollection(mockNft.address, '100000000000000000000');
      totalCost = costPerToken * 3000;
      await vault.purchase(
        deployer.address,
        deployer.address,
        [0, '1', '2'],
        ['1000', '1000', '1000'],
        3,
        4,
        0,
        { value: totalCost.toString() }
      );
      console.log("Payout:", (await alloc.getRewards(deployer.address)).toString());
      await alloc.claimReward(deployer.address);
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