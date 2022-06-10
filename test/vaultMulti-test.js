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

      VaultFactoryMulti = await ethers.getContractFactory("VaultFactoryMulti");
      factoryMulti = await VaultFactoryMulti.deploy(controller.address);

      AbcToken = await ethers.getContractFactory("ABCToken");
      abcToken = await AbcToken.deploy(controller.address);

      BribeFactory = await ethers.getContractFactory("BribeFactory");
      bribe = await BribeFactory.deploy(controller.address);

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
      const setPoolSizeLimit = await controller.proposePoolSizeLimit(50);
      await setPoolSizeLimit.wait();
      const approvePoolSizeLimit = await controller.approvePoolSizeLimit();
      await approvePoolSizeLimit.wait();
      const changeTreasuryRate = await controller.setTreasuryRate(10);
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
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
    });

    it("Start emission", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );

        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address],
            [1,2],
            mockNft.address
        );

        expect(await maPool.emissionsStarted()).to.equal(false);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address],
            [3],
            mockNft.address
        );
        expect(await maPool.emissionsStarted()).to.equal(true);
    });

    it("End emissions", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );

        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address],
            [1,2],
            mockNft.address
        );
        expect(await maPool.emissionsStarted()).to.equal(false);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address],
            [3],
            mockNft.address
        );
        expect(await maPool.emissionsStarted()).to.equal(true);

        await maPool.remove(mockNft.address, 2);
        expect(await maPool.emissionsStarted()).to.equal(false);

        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address],
            [4],
            mockNft.address
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
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3],
            mockNft.address
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 10000 * 1.5;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            ['0', '1', '2','3','4','5','6','7','8','9'],
            ['1500', '1500', '1500', '1500', '1500', '1500', '1500', '1500', '1500', '1500'],
            0,
            2,
            0,
            { value: totalCost.toString() }
        );

        await maPool.getDecodedLPInfo(deployer.address, 0);
    });

    it("Purchase with credit bond funds", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3],
            mockNft.address
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 3000 * 3;
        await bonds.bond( {value:totalCost.toString()} );
        await network.provider.send("evm_increaseTime", [86401]);
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, 1, 2],
            ['3000', '3000', '3000'],
            1,
            4,
            0
        );
    });

    it("Transfer", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3],
            mockNft.address
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 3000 * 5;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            ['0', '1', '2', '3', '4'],
            ['3000', '3000', '3000', '3000', '3000'],
            0,
            2,
            0,
            { value: totalCost.toString() }
        );

        await maPool.getDecodedLPInfo(user1.address, 0);
        await maPool.transferFrom(
            deployer.address,
            user1.address,
            0,
            ['4', '3', '2', '1', '0'],
            ['0', '0', '1500', '1500', '1500'],
        );
        
        await maPool.getDecodedLPInfo(deployer.address, 0);
        await maPool.getDecodedLPInfo(user1.address, 0);
    });

    it("Sale", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
            { value: totalCost.toString() }
        );
        
        await expect(maPool.sell(
            deployer.address,
            0,
            1000
        )).to.reverted;

        await network.provider.send("evm_increaseTime", [172801]);
        await maPool.sell(
            deployer.address,
            0,
            1000
        );
        
        console.log("Credits earned:", (await eVault.getUserCredits(2, deployer.address)).toString());
    });

    it("General bribe", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
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
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
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
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });

        expect(await maPool.reservationMade(1, mockNft.address, 1)).to.equal(true);
        expect(await maPool.reservations(1)).to.equal(1);
    });

    it("Close nft", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
            { value: totalCost.toString() }
        );

        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(true);
        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
    });

    it("Close nft - multiple", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
            { value: totalCost.toString() }
        );
            
        console.log("First:", (await maPool.getCostToReserve(2)).toString());
        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        console.log("Second:", (await maPool.getCostToReserve(2)).toString());
        await maPool.reserve(mockNft.address, 2, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        console.log("Third:", (await maPool.getCostToReserve(2)).toString());
        await maPool.reserve(mockNft.address, 3, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);

        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
    });

    it("Close nft - all", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            6
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            mockNft.address
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 3000 * 6;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['6000', '6000', '6000'],
            0,
            2,
            0,
            { value: totalCost.toString() }
        );

        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(true);
        expect(await controller.nftVaultSigned(mockNft.address, 2)).to.equal(true);
        expect(await controller.nftVaultSigned(mockNft.address, 3)).to.equal(true);
        expect(await controller.nftVaultSigned(mockNft.address, 4)).to.equal(true);
        expect(await controller.nftVaultSigned(mockNft.address, 5)).to.equal(true);
        expect(await controller.nftVaultSigned(mockNft.address, 6)).to.equal(true);

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await maPool.reserve(mockNft.address, 2, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await maPool.reserve(mockNft.address, 3, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await maPool.reserve(mockNft.address, 4, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await maPool.reserve(mockNft.address, 5, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await maPool.reserve(mockNft.address, 6, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await mockNft.approve(maPool.address, 2);
        await mockNft.approve(maPool.address, 3);
        await mockNft.approve(maPool.address, 4);
        await mockNft.approve(maPool.address, 5);
        await mockNft.approve(maPool.address, 6);
        await maPool.closeNft(mockNft.address, 1);
        await maPool.closeNft(mockNft.address, 2);
        await maPool.closeNft(mockNft.address, 3);
        await maPool.closeNft(mockNft.address, 4);
        await maPool.closeNft(mockNft.address, 5);
        await maPool.closeNft(mockNft.address, 6);

        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
        expect(await controller.nftVaultSigned(mockNft.address, 2)).to.equal(false);
        expect(await controller.nftVaultSigned(mockNft.address, 3)).to.equal(false);
        expect(await controller.nftVaultSigned(mockNft.address, 4)).to.equal(false);
        expect(await controller.nftVaultSigned(mockNft.address, 5)).to.equal(false);
        expect(await controller.nftVaultSigned(mockNft.address, 6)).to.equal(false);

        await expect(maPool.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['6000', '6000', '6000'],
            0,
            2,
            0,
            { value: totalCost.toString() }
        )).to.reverted;
    });

    it("Adjust ticket info", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3],
            mockNft.address
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 1000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0],
            ['3000'],
            0,
            2,
            0,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await ClosePoolMulti.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 1);
        await closureMulti.calculatePrincipal(deployer.address, 0, mockNft.address, 1);
    });

    it("Remove nft", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3],
            mockNft.address
        );
        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(true);
        await maPool.remove(mockNft.address, 1);
        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
    });

    it("Restore pool", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await ClosePoolMulti.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 1);
        await closureMulti.calculatePrincipal(deployer.address, 0, mockNft.address, 1);
        console.log("Before Res:", (await maPool.payoutPerRes(1)).toString());
        await maPool.restore();
        console.log("After Res:", (await maPool.payoutPerRes(1)).toString());
    });

    it("Restore pool - multi", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await ClosePoolMulti.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 1);
        await closureMulti.calculatePrincipal(deployer.address, 0, mockNft.address, 1);
        console.log("Before Res:", (await maPool.payoutPerRes(1)).toString());
        await maPool.restore();
        console.log("After Res:", (await maPool.payoutPerRes(1)).toString());
        
        await maPool.reserve(mockNft.address, 2, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await closureMulti.newBid(mockNft.address, 2, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 2);
        await closureMulti.calculatePrincipal(deployer.address, 0, mockNft.address, 2);
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
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
            { value: totalCost.toString() }
        );

        await factoryMulti.closePool(maPool.address, [mockNft.address, mockNft.address, mockNft.address, mockNft.address], [1,2,3,4]);

        await expect(maPool.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['3000', '3000', '3000'],
            0,
            2,
            { value: totalCost.toString() }
        )).to.reverted;

        await network.provider.send("evm_increaseTime", [172800]);
        await maPool.sell(
            deployer.address,
            0,
            1000
        );
    });

    it("Reclaim pending returns", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4,5,6],
            3
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let maPool = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
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
            0,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await ClosePoolMulti.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 1);
        await closureMulti.calculatePrincipal(deployer.address, 0, mockNft.address, 1);
        await maPool.restore();

        await factoryMulti.claimPendingReturns();
        expect(await factoryMulti.pendingReturns(deployer.address)).to.equal(0);
    });
});