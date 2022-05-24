const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("veABC", function () {
    let
      deployer,
      MockNft,
      mockNft,
      mockNft2,
      user1,
      user2,
      provider,
      VaultFactory,
      factory,
      Vault,
      vault,
      TestOwner,
      owner,
      Treasury,
      treasury,
      Auction,
      auction,
      AbcToken,
      abcToken,
      VeAbcToken,
      veToken,
      ClosePool,
      close,
      AbacusController,
      controller,
      EpochVault,
      eVault

    beforeEach(async() => {
      [
        deployer, 
        mockNft,
        mockNft2, 
        user1, 
        user2, 
        user3, 
        user4, 
        user5
      ] = await ethers.getSigners();

      provider = ethers.getDefaultProvider();

      AbacusController = await ethers.getContractFactory("AbacusController");
      controller = await AbacusController.deploy(deployer.address);

      Treasury = await ethers.getContractFactory("Treasury");
      treasury = await Treasury.deploy(deployer.address);
        
      VaultFactory = await ethers.getContractFactory("VaultFactory");
      factory = await VaultFactory.deploy(controller.address);

      AbcToken = await ethers.getContractFactory("ABCToken");
      abcToken = await AbcToken.deploy(controller.address);

      BribeFactory = await ethers.getContractFactory("BribeFactory");
      bribe = await BribeFactory.deploy(controller.address);

      CreditBonds = await ethers.getContractFactory("CreditBonds");
      bonds = await CreditBonds.deploy(controller.address);

      VeAbcToken = await ethers.getContractFactory("VeABC");
      veToken = await VeAbcToken.deploy(controller.address);

      MockNft = await ethers.getContractFactory("MockNft");
      mockNft = await MockNft.deploy();

      EpochVault = await ethers.getContractFactory("EpochVault");
      eVault = await EpochVault.deploy(controller.address, 1209600);

      TestOwner = await ethers.getContractFactory("TestOwner");
      owner = await TestOwner.deploy();
      
      Vault = await ethers.getContractFactory("Vault");

      ClosePool = await ethers.getContractFactory("ClosePool");

      const setCreditBonds = await controller.setCreditBonds(bonds.address);
      await setCreditBonds.wait()
      const approveCreditBonds = await controller.approveCreditBonds();
      await approveCreditBonds.wait()
      const setBondPremium = await controller.setBondMaxPremiumThreshold((100e18).toString());
      await setBondPremium.wait();
      const approveBondPremium = await controller.approveBondMaxPremiumThreshold();
      await approveBondPremium.wait();
      const proposeFactoryAddition = await controller.proposeFactoryAddition(factory.address);
      await proposeFactoryAddition.wait()
      const approveFactoryAddition = await controller.approveFactoryAddition();
      await approveFactoryAddition.wait()
      const setTreasury = await controller.setTreasury(treasury.address);
      await setTreasury.wait();
      const approveTreasuryChange = await controller.approveTreasuryChange();
      await approveTreasuryChange.wait();
      const setToken = await controller.setToken(abcToken.address);
      await setToken.wait();
      const approveTokenChange = await controller.approveTokenChange();
      await approveTokenChange.wait();
      const setVeToken = await controller.setVeToken(veToken.address);
      await setVeToken.wait();
      const approveVeChange = await controller.approveVeChange();
      await approveVeChange.wait();
      const setEpochVault = await controller.setEpochVault(eVault.address);
      await setEpochVault.wait();
      const approveEvaultChange = await controller.approveEvaultChange();
      await approveEvaultChange.wait();
      const setGas = await controller.setAbcGasFee('10000000000000000000');
      await setGas.wait();
      const approveGasFee = await controller.approveGasFeeChange();
      await approveGasFee.wait();
      const setVaultFactory = await controller.setVaultFactory(factory.address);
      await setVaultFactory.wait();
      const approveFactoryChange = await controller.approveFactoryChange();
      await approveFactoryChange.wait();
      const approveGasFeeChange = await controller.approveGasFeeChange();
      await approveGasFeeChange.wait();
      const changeTreasuryRate = await controller.setTreasuryRate(11);
      await changeTreasuryRate.wait();
      const approveRateChange = await controller.approveRateChange();
      await approveRateChange.wait();
      const wlAddress = await factory.addToEarlyMemberWhitelist(deployer.address);
      await wlAddress.wait();

      await abcToken.transfer(user1.address, '1000000000000000000000000000');
      await eVault.begin();
    });

    it("Proper compilation and setting", async function () {
      console.log("Contracts compiled and controller configured!");
    });

    it("Lock tokens", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('100000000000000000000', 1209600);
      expect(await veToken.balanceOf(deployer.address)).to.equal('100000000000000000000');
    });

    it("Add tokens", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('100000000000000000000', 1209600);
      await veToken.addTokens('100000000000000000000');
      expect(await veToken.balanceOf(deployer.address)).to.equal('200000000000000000000');
    });

    it("Unlock tokens", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('100000000000000000000', 1209600);
      await veToken.addTokens('100000000000000000000');
      await network.provider.send("evm_increaseTime", [1209600]);
      await veToken.unlockTokens();
      expect(await veToken.balanceOf(deployer.address)).to.equal(0);
    });

    it("Allocate to collection", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('100000000000000000000', 1209600);
      await veToken.addTokens('100000000000000000000');
      await veToken.allocateToCollection(mockNft.address, '20000000000000000000');
    });

    it("Change collection allocation", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('100000000000000000000', 1209600);
      await veToken.addTokens('100000000000000000000');
      await veToken.allocateToCollection(mockNft.address, '20000000000000000000');
      await veToken.changeAllocation(mockNft.address, mockNft2.address, '20000000000000000000');
    });

    it("Auto allocate", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('100000000000000000000', 1209600);
      await veToken.addTokens('100000000000000000000');
      await veToken.addAutoAllocation('20000000000000000000');
      expect(await veToken.getAmountAllocated(deployer.address)).to.equal('20000000000000000000');
    });
    
    it("Claim ve rewards", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('200000000000000000000', 1209600);
      await veToken.addTokens('100000000000000000000');
      await veToken.addAutoAllocation('10000000000000000000');
      await veToken.allocateToCollection(mockNft.address, '20000000000000000000');
      await mockNft.approve(factory.address, '1');
      const createVaultTx = await factory.createVault(
        "Test", 
        "TST", 
        mockNft.address, 
        '1'
      );

      await createVaultTx.wait();

      let vaultAddress = await factory.nftVault(0, mockNft.address, '1');
      vault = Vault.attach(vaultAddress);

      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });

      await veToken.unlockTokens();
      await veToken.lockTokens('200000000000000000000', 1209600);
      await veToken.addTokens('100000000000000000000');
      await veToken.addAutoAllocation('10000000000000000000');
      await veToken.allocateToCollection(mockNft.address, '20000000000000000000');

      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['6000000000000000000', '7000000000000000000', '8000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await vault.purchase(deployer.address, deployer.address, ['9000000000000000000', '10000000000000000000', '11000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      await vault.sell(user1.address);
      await vault.sell(deployer.address);
      await veToken.claimRewards(deployer.address);
    });

    it("Claim bribe rewards", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('100000000000000000000', 4838400);
      await veToken.addTokens('100000000000000000000');
      await veToken.connect(user1).lockTokens('100000000000000000000', 4838400);
      await veToken.connect(user1).addTokens('100000000000000000000');
      await veToken.addAutoAllocation('20000000000000000000');
      await veToken.connect(user1).addAutoAllocation('20000000000000000000');
      await veToken.bribeAuto(mockNft.address, { value: '20000000000000000000'});
      await network.provider.send("evm_increaseTime", [1209600]);

      await veToken.bribeAuto(mockNft.address, { value: '20000000000000000000'});
      await network.provider.send("evm_increaseTime", [1209600]);

      await veToken.claimRewards(deployer.address);
      await veToken.connect(user1).claimRewards(user1.address);
    });

    it("Calculate proper boost - bribe based", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('100000000000000000000', 4838400);
      await veToken.addTokens('100000000000000000000');
      await veToken.connect(user1).lockTokens('100000000000000000000', 4838400);
      await veToken.connect(user1).addTokens('100000000000000000000');
      await veToken.addAutoAllocation('20000000000000000000');
      await veToken.connect(user1).addAutoAllocation('20000000000000000000');
      await veToken.bribeAuto(mockNft.address, { value: '20000000000000000000'});
      await network.provider.send("evm_increaseTime", [1209600]);

      await veToken.calculateBoost(mockNft.address);
    });

    it("Calculate proper boost - bribe + natural allocation", async function () {
      await abcToken.transfer(user1.address, '20000000000000000000000');
      await abcToken.transfer(user2.address, '20000000000000000000000');
      await veToken.lockTokens('100000000000000000000', 4838400);
      await veToken.addTokens('100000000000000000000');
      await veToken.connect(user1).lockTokens('100000000000000000000', 4838400);
      await veToken.connect(user1).addTokens('100000000000000000000');
      await veToken.allocateToCollection(mockNft.address, '10000000000000000000');
      await veToken.connect(user1).allocateToCollection(mockNft2.address, '10000000000000000000');
      await veToken.addAutoAllocation('10000000000000000000');
      await veToken.connect(user1).addAutoAllocation('10000000000000000000');
      await veToken.bribeAuto(mockNft.address, { value: '30000000000000000000'});
      await veToken.bribeAuto(mockNft2.address, { value: '70000000000000000000'});
      await network.provider.send("evm_increaseTime", [1209600]);

      await veToken.calculateBoost(mockNft.address);
      await veToken.calculateBoost(mockNft2.address);
    });

});