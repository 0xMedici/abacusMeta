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
        provider,
        VaultFactory,
        factory,
        Vault,
        vault,
        VaultFactoryMulti,
        factoryMulti,
        VaultMulti,
        vaultMulti,
        Treasury,
        treasury,
        AbcToken,
        abcToken,
        VeAbcToken,
        veToken,
        ClosePool,
        close,
        ClosePoolMulti,
        closeMulti,
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
        
      VaultFactory = await ethers.getContractFactory("VaultFactory");
      factory = await VaultFactory.deploy(controller.address);

      VaultFactoryMulti = await ethers.getContractFactory("VaultFactoryMulti");
      factoryMulti = await VaultFactoryMulti.deploy(controller.address);

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
      eVault = await EpochVault.deploy(controller.address, 86400);
      
      Vault = await ethers.getContractFactory("Vault");
      
      ClosePool = await ethers.getContractFactory("ClosePool");

      VaultMulti = await ethers.getContractFactory("VaultMulti");

      ClosePoolMulti = await ethers.getContractFactory("ClosePoolMulti");

      const setBeta = await controller.setBeta(3);
      await setBeta.wait();
      const approveBeta = await controller.approveBeta();
      await approveBeta.wait();
      const setMaxPoolsPerToken = await controller.setMaxPoolsPerToken(10);
      await setMaxPoolsPerToken.wait();
      const approveMaxPoolsPerToken = await controller.approveMaxPoolsPerToken();
      await approveMaxPoolsPerToken.wait();
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
      const wlAddress = await controller.proposeWLUser([deployer.address]);
      await wlAddress.wait();
      const confirmWlAddress = await controller.approveWLUser();
      await confirmWlAddress.wait();
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

    it("Create MA pool", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        expect(await maPool.creator()).to.equal(deployer.address);
    });

    it("Start emission", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2]
        );
        expect(await maPool.emissionsStarted()).to.equal(false);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [3]
        );
        expect(await maPool.emissionsStarted()).to.equal(true);
    });

    it("Purchase", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await factoryMulti.closePool(maPool.address, mockNft.address, [1,2,3,4]);

        await expect(maPool.purchase(
            deployer.address,
            deployer.address,
            ['3000000000000000000', '4000000000000000000', '5000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        )).to.reverted;

        await network.provider.send("evm_increaseTime", [300000]);

        await maPool.sell(
            deployer.address
        );

        await expect(maPool.sell(
            deployer.address
        )).to.reverted;
    });

    it("Purchase with credit bond funds", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await bonds.bond( {value:totalCost.toString()} );
        await network.provider.send("evm_increaseTime", [86401]);
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            4
        );
    });

    it("Sale", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );
        
        await expect(maPool.sell(
            deployer.address
        )).to.reverted;

        await network.provider.send("evm_increaseTime", [86400]);
        await maPool.sell(
            deployer.address
        );
        
        console.log("Credits earned:", (await eVault.getUserCredits(1, deployer.address)).toString());
    });

    it("Multiple sale required", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 30000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
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
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000',
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000',
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000',
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000',
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000',
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000',
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000',
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000',
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000',
                '3000000000000000000000', '3000000000000000000000', '3000000000000000000000'
            ],
            2,
            { value: totalCost.toString() }
        );
        
        await expect(maPool.sell(
            deployer.address
        )).to.reverted;

        await network.provider.send("evm_increaseTime", [86400]);
        await maPool.sell(
            deployer.address
        );
        await maPool.sell(
            deployer.address
        );

        await expect(maPool.sell(
            deployer.address
        )).to.reverted;

        console.log("Credits earned:", (await eVault.getUserCredits(1, deployer.address)).toString());
    });

    it("Pending order", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );
        
        totalCost = 1.0125 * costPerToken * 1000 * 3;
        await maPool.createPendingOrder(
            deployer.address,
            user1.address,
            0,
            4,
            (1e18).toString(),
            { value:(totalCost + 1e18).toString() }
        );

        await network.provider.send("evm_increaseTime", [172800]);

        await maPool.sell(
            deployer.address
        );
    });

    it("Reclaim pending order post closure", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );
        
        totalCost = 1.0125 * costPerToken * 1000 * 3;
        await maPool.createPendingOrder(
            deployer.address,
            user1.address,
            0,
            4,
            (1e18).toString(),
            { value:(totalCost + 1e18).toString() }
        );
        
        await factoryMulti.closePool(maPool.address, mockNft.address, [1,2,3,4]);
        await network.provider.send("evm_increaseTime", [172800]);
        
        await maPool.sell(
            deployer.address
        );

        let currentPending = await factoryMulti.pendingReturns(user1.address);
        console.log("Current pending balance:", currentPending.toString());
        expect(await factoryMulti.pendingReturns(user1.address)).to.equal((currentPending).toString());
    });

    it("General bribe", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await maPool.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );

        expect(await maPool.generalBribe(1)).to.equal(1e18.toString());
        expect(await maPool.generalBribe(2)).to.equal(1e18.toString());
        expect(await maPool.generalBribe(3)).to.equal(1e18.toString());
    });

    it("Concentrated bribe", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await maPool.offerConcentratedBribe(
            1, 
            4, 
            ['1000000000000000000', '2000000000000000000'], 
            [(1e18).toString(), (1e18).toString()],
            { value:(6e18).toString() }
        );

        expect(await maPool.concentratedBribe(1, '1000000000000000000')).to.equal(1e18.toString());
        expect(await maPool.concentratedBribe(2, '1000000000000000000')).to.equal(1e18.toString());
        expect(await maPool.concentratedBribe(3, '1000000000000000000')).to.equal(1e18.toString());
        expect(await maPool.concentratedBribe(1, '2000000000000000000')).to.equal(1e18.toString());
        expect(await maPool.concentratedBribe(2, '2000000000000000000')).to.equal(1e18.toString());
        expect(await maPool.concentratedBribe(3, '2000000000000000000')).to.equal(1e18.toString());
    });

    it("Reserve for closure", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(1, 2);

        expect(await maPool.reservationMade(1,1)).to.equal(true);
        expect(await maPool.reservations(1)).to.equal(1);
    });

    it("Close nft", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(1, 2);
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(1);

        expect(await factoryMulti.nftInUse(maPool.heldCollection(), 1)).to.equal(0);
    });

    it("Adjust ticket info", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 1000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0],
            ['3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(1, 2);
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(1);

        let closureMulti = await ClosePoolMulti.attach(await maPool.closePoolContract());
        await closureMulti.newBid(1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(1);
        console.log("Before:", (await maPool.getNominalTokensPerEpoch(deployer.address, 1)).toString());
        await closureMulti.calculatePrincipal(deployer.address, 1);
        console.log("After:", (await maPool.getNominalTokensPerEpoch(deployer.address, 1)).toString());
    });

    it("Adjust ticket info - multiple required", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(1, 2);
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(1);

        let closureMulti = await ClosePoolMulti.attach(await maPool.closePoolContract());
        await closureMulti.newBid(1, { value:(2e18).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(1);
        console.log("Before:", (await maPool.getNominalTokensPerEpoch(deployer.address, 1)).toString());
        await closureMulti.calculatePrincipal(deployer.address, 1);
        await closureMulti.calculatePrincipal(deployer.address, 1);
        await closureMulti.calculatePrincipal(deployer.address, 1);
        console.log("After:", (await maPool.getNominalTokensPerEpoch(deployer.address, 1)).toString());
        await expect(closureMulti.calculatePrincipal(deployer.address, 1)).to.reverted;
    });

    it("Remove nft", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );

        await maPool.remove(1);
        expect(await factoryMulti.nftInUse(maPool.heldCollection(), 1)).to.equal(0);
    });

    it("Restore pool", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(1, 2);
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(1);

        let closureMulti = await ClosePoolMulti.attach(await maPool.closePoolContract());
        await closureMulti.newBid(1, { value:(2e18).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(1);
        console.log("Before Nom:", (await maPool.getNominalTokensPerEpoch(deployer.address, 1)).toString());
        await closureMulti.calculatePrincipal(deployer.address, 1);
        await closureMulti.calculatePrincipal(deployer.address, 1);
        await closureMulti.calculatePrincipal(deployer.address, 1);
        console.log("After Nom:", (await maPool.getNominalTokensPerEpoch(deployer.address, 1)).toString());
        console.log("Before Res:", (await maPool.payoutPerRes(1)).toString());
        await maPool.restore();
        console.log("After Res:", (await maPool.payoutPerRes(1)).toString());
    });

    it("Close pool", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await factoryMulti.closePool(maPool.address, maPool.heldCollection(), [1,2,3,4]);

        await expect(maPool.purchase(
            deployer.address,
            deployer.address,
            ['3000000000000000000', '4000000000000000000', '5000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        )).to.reverted;

        await network.provider.send("evm_increaseTime", [172800]);
        await maPool.sell(
            deployer.address
        );
    });

    it("Reclaim pending returns", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            mockNft.address,
            [1,2,3,4,5,6],
            3,
            "Test",
            "TST"
        );
        
        let vaultAddress = await factoryMulti.listOfPoolsPerNft(mockNft.address, 1, 0);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            mockNft.address,
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = 1.0125 * costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1000000000000000000', '2000000000000000000'],
            ['3000000000000000000000', '3000000000000000000000', '3000000000000000000000'],
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(1, 2);
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(1);

        let closureMulti = await ClosePoolMulti.attach(await maPool.closePoolContract());
        await closureMulti.newBid(1, { value:(4e18).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(1);
        await closureMulti.calculatePrincipal(deployer.address, 1);
        await maPool.restore();

        await factoryMulti.claimPendingReturns();
        expect(await factoryMulti.pendingReturns(deployer.address)).to.equal(0);
    });

});