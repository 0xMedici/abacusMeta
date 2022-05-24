const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Vault", function () {
    let
        deployer,
        MockNft,
        mockNft,
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
        mockNFT, 
        user1, 
        user2 
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

    it("Beta adherence - phase 1", async function () {
      await abcToken.transfer(user1.address, '10');
      await abcToken.connect(user1).approve(deployer.address, 10);
      await abcToken.transferFrom(user1.address, deployer.address, 10);
      await mockNft.approve(factory.address, '1');
      await expect(factory.connect(user1).createVault("Test", "TST", mockNft.address, '1')).to.reverted;
      
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
      let totalCost = 1.0125 * (10 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0], ['10000000000000000000'], 1209600, { value: (totalCost).toString() });
      totalCost = 1.0125 * (100 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0], ['100000000000000000000'], 1209600, { value: (totalCost).toString() });
    });

    it("Beta adherence - phase 2", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
      await factory.setBeta(2);
      await factory.addToCollectionWhitelist(mockNft.address);
      await mockNft.approve(factory.address, '1');
      
      const createVaultTx = await factory.connect(user1).createVault(
        "Test", 
        "TST", 
        mockNft.address, 
        '1'
      );

      await createVaultTx.wait();

      let vaultAddress = await factory.nftVault(0, mockNft.address, '1');
      vault = Vault.attach(vaultAddress);
      
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (1000 * costPerToken);
      await expect(vault.purchase(deployer.address, deployer.address, [(1e18).toString()], ['1000000000000000000000'], 1209600, { value: (totalCost).toString() })).to.reverted;
      await vault.purchase(deployer.address, deployer.address, [(0).toString()], ['1000000000000000000000'], 1209600, { value: (totalCost).toString() });
      await vault.purchase(deployer.address, deployer.address, [(1e18).toString()], ['1000000000000000000000'], 1209600, { value: (totalCost).toString() })
    });

    it("Buy - multi ticket purchase range", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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
      
      let totalCost = 1.0125 * (3000 * 1e15);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      expect((await vault.totalSupply() / 1e18).toString()).to.equal((3000).toString());
      totalCost = 1.0125 * (3000 * 1e15);
      await vault.purchase(deployer.address, deployer.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      expect((await vault.totalSupply() / 1e18).toString()).to.equal((6000).toString());
    });

    it("Sell - self", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      await expect(vault.sell(deployer.address)).to.reverted;
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
    });

    it("Sell - other", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814401]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
    });

    it("Sell - fulfill new order call", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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
      await network.provider.send("evm_increaseTime", [1814401]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.createPendingOrder(deployer.address, user1.address, 0, 1209600, (1e18).toString(), { value: (1.0125 * 1000 * costPerToken + 1e18).toString() });
      await vault.createPendingOrder(deployer.address, deployer.address, 0, 1209600, (2e18).toString(), { value: (1.0125 * 1000 * costPerToken + 2e18).toString() });
      await vault.createPendingOrder(deployer.address, user1.address, 0, 1209600, (3e18).toString(), { value: (1.0125 * 1000 * costPerToken + 3e18).toString() });
      await vault.sell(deployer.address);
    });

    it("Sell - fulfill new order call", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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
      await network.provider.send("evm_increaseTime", [1814401]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.createPendingOrder(deployer.address, user1.address, 0, 1209600, (1e18).toString(), { value: (1.0125 * 1000 * costPerToken + 1e18).toString() });
      await vault.createPendingOrder(deployer.address, deployer.address, 0, 1209600, (2e18).toString(), { value: (1.0125 * 1000 * costPerToken + 2e18).toString() });
      await vault.createPendingOrder(deployer.address, user1.address, 0, 1209600, (3e18).toString(), { value: (1.0125 * 1000 * costPerToken + 3e18).toString() });
      await vault.sell(deployer.address);
      await factory.claimPendingReturns();
      await factory.connect(user1).claimPendingReturns();
    });

    it("Sell - Multiple sell calls required", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (30000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address,
        [
          0, '1000000000000000000', '2000000000000000000',
          '3000000000000000000', '4000000000000000000', '5000000000000000000',
          '6000000000000000000', '7000000000000000000', '8000000000000000000',
          '9000000000000000000', '10000000000000000000', '11000000000000000000',
          '12000000000000000000', '13000000000000000000', '14000000000000000000',
          '15000000000000000000', '16000000000000000000', '17000000000000000000',
          '18000000000000000000', '19000000000000000000', '20000000000000000000',
          '21000000000000000000', '22000000000000000000', '23000000000000000000',
          '24000000000000000000', '25000000000000000000', '26000000000000000000',
          '27000000000000000000', '28000000000000000000', '29000000000000000000'
        ], 
        [
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
        ], 1814400, { value: totalCost.toString() });
      await vault.createPendingOrder(deployer.address, user1.address, 0, 1209600, (1e18).toString(), { value: (1.0125 * 1000 * costPerToken + 1e18).toString() });
      await vault.createPendingOrder(deployer.address, deployer.address, 0, 1209600, (2e18).toString(), { value: (1.0125 * 1000 * costPerToken + 2e18).toString() });
      await vault.createPendingOrder(deployer.address, user1.address, 0, 1209600, (3e18).toString(), { value: (1.0125 * 1000 * costPerToken + 3e18).toString() });
      await network.provider.send("evm_increaseTime", [1814401]);
      await vault.sell(deployer.address);
      await vault.sell(deployer.address);
      expect(await eVault.getUserCredits(1, deployer.address)).to.gt((89e18).toString());
      expect(await eVault.getUserCredits(1, deployer.address)).to.lt((90e18).toString());
    });

    it("Check payout ratio", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      await vault.sell(deployer.address);
      await vault.sell(user1.address);
      expect(await eVault.getUserCredits(1, deployer.address)).to.equal('7650000000000000000');
      expect(await eVault.getUserCredits(1, user1.address)).to.equal('10350000000000000000');
    });

    it("Fee distribution", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });

      expect(await veToken.epochFeesAccumulated(1)).to.equal('2610000000000000000');
    });

    it("Close pool", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
      const createVaultTx = await factory.createVault(
        "Test", 
        "TST", 
        mockNft.address, 
        '1'
      );

      await createVaultTx.wait();

      let vaultAddress = await factory.nftVault(0, mockNft.address, '1');
      vault = Vault.attach(vaultAddress);

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });

      await mockNft.approve(vault.address, '1');
      await vault.connect(deployer).closePool();

      let closePoolAddress = await vault.closePoolContract();
      close = await ClosePool.attach(closePoolAddress);
    });

    it("Close account - overbid", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1209600]);
      await mockNft.approve(vault.address, '1');
      await vault.closePool();

      let closePoolAddress = await vault.closePoolContract();
      close = await ClosePool.attach(closePoolAddress);

      await close.newBid({ value: '20000000000000000000'});
      await network.provider.send("evm_increaseTime", [259200]);
      await close.endAuction();
      
      let deployerCredits = await vault.getAvailableCredits(deployer.address);
      let user1Credits = await vault.getAvailableCredits(user1.address);
      await close.calculatePositionPremiums();
      await close.calculatePrincipal();
      await close.calculateAvailableCredits();
      await close.connect(user1).calculatePrincipal();
      await close.connect(user1).calculateAvailableCredits();
      await close.closeAccount(deployerCredits.toString());
      await close.connect(user1).closeAccount(user1Credits.toString());
      
      expect(await eVault.getUserCredits(2, deployer.address)).to.equal(deployerCredits.toString());
      expect(await eVault.getUserCredits(2, user1.address)).to.equal(user1Credits.toString());
    });

    it("Close account - underbid", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1209600]);
      await mockNft.approve(vault.address, '1');
      await vault.closePool();

      let closePoolAddress = await vault.closePoolContract();
      close = await ClosePool.attach(closePoolAddress);

      await close.newBid({ value: '1500000000000000000'});
      await network.provider.send("evm_increaseTime", [259200]);
      await close.endAuction();
      
      let deployerCredits = await vault.getAvailableCredits(deployer.address);
      let user1Credits = await vault.getAvailableCredits(user1.address);
      await close.calculatePositionPremiums();
      await close.calculatePrincipal();
      await close.calculateAvailableCredits();
      await close.connect(user1).calculatePrincipal();
      await close.connect(user1).calculateAvailableCredits();
      await close.closeAccount((deployerCredits * 0.5).toString());
      await close.connect(user1).closeAccount((user1Credits * 0).toString());
    });

    it("Close account - underbid with split top position", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      totalCost = 1.0125 * (1500 * costPerToken);
      await vault.connect(user1).purchase(user1.address, deployer.address, [0, '1000000000000000000'], ['1000000000000000000000', '500000000000000000000'], 1814400, { value: totalCost.toString() });
      totalCost = 1.0125 * (500 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['1000000000000000000'], ['500000000000000000000'], 1814400, { value: totalCost.toString() });
      totalCost = 1.0125 * (1000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, deployer.address, ['2000000000000000000'], ['1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1209600]);
      await mockNft.approve(vault.address, '1');
      await vault.closePool();

      let closePoolAddress = await vault.closePoolContract();
      close = await ClosePool.attach(closePoolAddress);

      await close.newBid({ value: '1500000000000000000'});
      await network.provider.send("evm_increaseTime", [259200]);
      await close.endAuction();
      
      let deployerCredits = await vault.getAvailableCredits(deployer.address);
      let user1Credits = await vault.getAvailableCredits(user1.address);
      await close.calculatePositionPremiums();
      await close.calculatePrincipal();
      await close.calculateAvailableCredits();
      await close.connect(user1).calculatePrincipal();
      await close.connect(user1).calculateAvailableCredits();
      expect(await close.principal(user1.address)).to.equal((25e16).toString());
      expect(await close.principal(deployer.address)).to.equal((125e16).toString());
      await close.closeAccount((deployerCredits * 125e16 / 25e17).toString());
      await close.connect(user1).closeAccount((user1Credits * 25e16 / 35e17).toString());
    });

    it("Close account - underbid with split stack position", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      totalCost = 1.0125 * (500 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, [0], ['500000000000000000000'], 1814400, { value: totalCost.toString() });
      totalCost = 1.0125 * (2500 * costPerToken);
      await vault.connect(user1).purchase(user1.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['500000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1209600]);
      await mockNft.approve(vault.address, '1');
      await vault.closePool();

      let closePoolAddress = await vault.closePoolContract();
      close = await ClosePool.attach(closePoolAddress);

      await close.newBid({ value: '1500000000000000000'});
      await network.provider.send("evm_increaseTime", [259200]);
      await close.endAuction();
      
      let deployerCredits = await vault.getAvailableCredits(deployer.address);
      let user1Credits = await vault.getAvailableCredits(user1.address);
      await close.calculatePositionPremiums();
      await close.calculatePrincipal();
      await close.calculateAvailableCredits();
      await close.connect(user1).calculatePrincipal();
      await close.connect(user1).calculateAvailableCredits();
      expect(await close.principal(user1.address)).to.equal((5e17).toString());
      expect(await close.principal(deployer.address)).to.equal((1e18).toString());
      await close.closeAccount((deployerCredits * 1e18 / 25e17).toString());
      await close.connect(user1).closeAccount((user1Credits * 5e17 / 35e17).toString());
    });

    it("Create new pool post closure", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000000');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      totalCost = 1.0125 * (500 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, [0], ['500000000000000000000'], 1814400, { value: totalCost.toString() });
      totalCost = 1.0125 * (2500 * costPerToken);
      await vault.connect(user1).purchase(user1.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['500000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1209600]);
      await mockNft.approve(vault.address, '1');

      await expect(factory.createVault("Test", "TST", mockNft.address, '1')).to.reverted;
      await vault.closePool();

      let closePoolAddress = await vault.closePoolContract();
      close = await ClosePool.attach(closePoolAddress);

      await close.newBid({ value: '1500000000000000000'});
      await network.provider.send("evm_increaseTime", [259200]);
      await close.endAuction();
      
      let deployerCredits = await vault.getAvailableCredits(deployer.address);
      let user1Credits = await vault.getAvailableCredits(user1.address);
      await close.calculatePositionPremiums();
      await close.calculatePrincipal();
      await close.calculateAvailableCredits();
      await close.connect(user1).calculatePrincipal();
      await close.connect(user1).calculateAvailableCredits();
      expect(await close.principal(user1.address)).to.equal((5e17).toString());
      expect(await close.principal(deployer.address)).to.equal((1e18).toString());
      await close.closeAccount((deployerCredits * 1e18 / 25e17).toString());
      await close.connect(user1).closeAccount((user1Credits * 5e17 / 35e17).toString());

      await mockNft.approve(factory.address, '1');
      const createVaultTx1 = await factory.createVault(
        "Test", 
        "TST", 
        mockNft.address, 
        '1'
      );

      await createVaultTx1.wait();

      vaultAddress = await factory.nftVault(1, mockNft.address, '1');
      vault = Vault.attach(vaultAddress);
      
      await vault.startEmissions();
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1814400]);
      totalCost = 1.0125 * (3000 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1209600, { value: totalCost.toString() });
      await vault.sell(deployer.address);
      totalCost = 1.0125 * (500 * costPerToken);
      await vault.connect(user1).purchase(user1.address, user1.address, [0], ['500000000000000000000'], 1814400, { value: totalCost.toString() });
      totalCost = 1.0125 * (2500 * costPerToken);
      await vault.connect(user1).purchase(user1.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['500000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1209600]);
      await mockNft.approve(vault.address, '1');
      await vault.closePool();
    });

    it("Close pool - multiple calculations required to calculate credits", async function () {
      await abcToken.transfer(user1.address, '1000000000000000000000010');
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

      await vault.startEmissions();
      let costPerToken = 1e15;
      let totalCost = 1.0125 * (30000 * costPerToken);
      await vault.purchase(deployer.address, deployer.address, 
        [
          0, '1000000000000000000', '2000000000000000000',
          '3000000000000000000', '4000000000000000000', '5000000000000000000',
          '6000000000000000000', '7000000000000000000', '8000000000000000000',
          '9000000000000000000', '10000000000000000000', '11000000000000000000',
          '12000000000000000000', '13000000000000000000', '14000000000000000000',
          '15000000000000000000', '16000000000000000000', '17000000000000000000',
          '18000000000000000000', '19000000000000000000', '20000000000000000000',
          '21000000000000000000', '22000000000000000000', '23000000000000000000',
          '24000000000000000000', '25000000000000000000', '26000000000000000000',
          '27000000000000000000', '28000000000000000000', '29000000000000000000'
        ], 
        [
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
          '1000000000000000000000', '1000000000000000000000', '1000000000000000000000',
        ], 1814400, { value: totalCost.toString() });
      await network.provider.send("evm_increaseTime", [1209600]);
      await mockNft.approve(vault.address, '1');
      await vault.closePool();

      let closePoolAddress = await vault.closePoolContract();
      close = await ClosePool.attach(closePoolAddress);

      await close.newBid({ value: (30e18).toString() });
      await network.provider.send("evm_increaseTime", [259200]);
      await close.endAuction();
      
      let deployerCredits = await vault.getAvailableCredits(deployer.address);
      await close.calculatePositionPremiums();
      await close.calculatePrincipal();
      await close.calculateAvailableCredits();
      await close.calculateAvailableCredits();
      await close.closeAccount(deployerCredits.toString());
    });

});