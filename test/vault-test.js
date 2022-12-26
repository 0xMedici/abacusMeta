const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Spot pool", function () {
    let
        deployer,
        MockNft,
        mockNft,
        mockNft2,
        MockToken,
        mockToken,
        user1,
        user2,
        Factory,
        factory,
        Vault,
        AbacusController,
        controller,
        RiskPointCalculator,
        riskCalc,
        TrancheCalculator,
        trancheCalc,
        Position,
        manager
    
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

        MockNft = await ethers.getContractFactory("MockNft");
        mockNft = await MockNft.deploy();
        mockNft2 = await MockNft.deploy();
        
        MockToken = await ethers.getContractFactory("MockToken");
        mockToken = await MockToken.deploy();

        RiskPointCalculator = await ethers.getContractFactory("RiskPointCalculator");
        riskCalc = await RiskPointCalculator.deploy(controller.address);

        TrancheCalculator = await ethers.getContractFactory("TrancheCalculator");
        trancheCalc = await TrancheCalculator.deploy(controller.address);
        
        Auction = await ethers.getContractFactory("Auction");
        auction = await Auction.deploy(controller.address);

        Vault = await ethers.getContractFactory("Vault");
        Position = await ethers.getContractFactory("Position");

        const setBeta = await controller.setBeta(3);
        await setBeta.wait();
        const setAuction = await controller.setAuction(auction.address);
        await setAuction.wait();
        const setFactory = await controller.setFactory(factory.address);
        await setFactory.wait();
        const wlAddress = await controller.addWlUser([deployer.address]);
        await wlAddress.wait();
        const setCalc = await controller.setCalculator(trancheCalc.address);
        await setCalc.wait();
        const setRisk = await controller.setRiskCalculator(riskCalc.address);
        await setRisk.wait();
        mockToken.mint();
    });

    it("Proper compilation and setting", async function () {
        console.log("Contracts compiled and controller configured!");
    });

    it("includeNft()", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        expect(await maPool.getHeldTokenExistence(mockNft.address, 1)).to.equal(true);
    });

    it("findBounds() - basic", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        )
        expect(await maPool.getHeldTokenExistence(mockNft.address, 1)).to.equal(true);
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        await trancheCalc.mockCalculation(maPool.address, 1);
    });

    it("findRiskMultiplier() - basic", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await riskCalc.setMetrics(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8]
        );
        await riskCalc.calculateMultiplier(1);
    });

    it("begin()", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        expect(await maPool.epochLength()).to.equal(86400);
        expect(await maPool.amountNft()).to.equal(3);
        expect(await maPool.interestRate()).to.equal(100);
    });

    it("purchase() - basic", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 750;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2'
            ],
            [
                '108', '108', '108'
            ],
            0,
            2,
        );
        expect((await maPool.getPayoutPerReservation(0)).toString()).to.equal("108000000000000000");
        expect((await maPool.getTotalAvailableFunds(0)).toString()).to.equal("324000000000000000");
    });

    it("purchase() - multiple", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 750;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2'
            ],
            [
                '108', '54', '108'
            ],
            0,
            2,
        );
        totalCost = costPerToken * 150;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '1'
            ],
            [
                '54'
            ],
            0,
            2,
        );
        expect(await manager.nonce()).to.equal(2);
        totalCost = costPerToken * 600;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '3','4'
            ],
            [
                '108', '108'
            ],
            0,
            2,
        );
        expect(await manager.nonce()).to.equal(3);
        expect(await maPool.getTicketInfo(0, 3)).to.equal(108);
        await network.provider.send("evm_increaseTime", [172801]);
        totalCost = costPerToken * 900;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '5','6','7'
            ],
            [
                '108', '108', '108'
            ],
            2,
            4,
        );
        expect((await maPool.getPayoutPerReservation(0)).toString()).to.equal("180000000000000000");
        expect((await maPool.getTotalAvailableFunds(0)).toString()).to.equal("540000000000000000");
    });

    it("sell() - basic", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            ['0', '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await network.provider.send("evm_increaseTime", [86401 * 2]);
        await maPool.sell(
            0
        );
        expect((await maPool.getPayoutPerReservation(0)).toString()).to.equal("100000000000000000");
        expect((await maPool.getTotalAvailableFunds(0)).toString()).to.equal("300000000000000000");
        expect((await maPool.getPayoutPerReservation(1)).toString()).to.equal("100000000000000000");
        expect((await maPool.getTotalAvailableFunds(1)).toString()).to.equal("300000000000000000");
    });

    it("sell() - early", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            ['0', '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await maPool.sell(
            0
        );
        expect((await maPool.getPayoutPerReservation(0)).toString()).to.equal("0");
        expect((await maPool.getTotalAvailableFunds(0)).toString()).to.equal("0");
        expect((await maPool.getPayoutPerReservation(1)).toString()).to.equal("0");
        expect((await maPool.getTotalAvailableFunds(1)).toString()).to.equal("0");
    });

    it("purchase() sell() - repetition", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await maPool.sell(
            0
        );
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await maPool.sell(
            1
        );
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await maPool.sell(
            2
        );
        
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await maPool.sell(
            3
        );
        expect((await maPool.getPayoutPerReservation(0)).toString()).to.equal("0");
        expect((await maPool.getTotalAvailableFunds(0)).toString()).to.equal("0");
        expect((await maPool.getPayoutPerReservation(1)).toString()).to.equal("0");
        expect((await maPool.getTotalAvailableFunds(1)).toString()).to.equal("0");
    });

    it("closeNft() - basic", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            ['0', '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
    });

    it("closeNft() - multiple nfts, same collection", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            ['0', '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
    });

    it("closeNft() - multiple nfts, different collections", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        let nftIds1 = new Array();
        let nftAddresses1 = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft2.mintNew();
            nftIds1[i] = i + 1;
            nftAddresses1[i] = mockNft2.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.includeNft(
            nftAddresses1, 
            nftIds1
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            ['0', '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockNft2.approve(maPool.address, 1);
        await maPool.closeNft(mockNft2.address, 1);
    });

    it("closeNft() - multiple --staggered", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            ['0', '1', '2'],
            ['100', '100', '100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await network.provider.send("evm_increaseTime", [43201]);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await network.provider.send("evm_increaseTime", [43201]);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
    });

    it("closeNft() - all", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(6, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 6;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            ['0', '1', '2'],
            ['200', '200', '200'],
            0,
            5,
        );
        await mockNft.approve(maPool.address, 1);
        await mockNft.approve(maPool.address, 2);
        await mockNft.approve(maPool.address, 3);
        await mockNft.approve(maPool.address, 4);
        await mockNft.approve(maPool.address, 5);
        await mockNft.approve(maPool.address, 6);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(1, (5e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        // TODO Check pool values
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(2, (5e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        // TODO Check pool values
        await maPool.closeNft(mockNft.address, 3);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(3, (5e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(3);
        // TODO Check pool values
        await maPool.closeNft(mockNft.address, 4);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(4, (5e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(4);
        // TODO Check pool values
        await maPool.closeNft(mockNft.address, 5);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(5, (5e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(5);
        // TODO Check pool values
        await maPool.closeNft(mockNft.address, 6);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(6, (5e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(6);
        // TODO Check pool values
    });

    it("closeNft() - single NFT multiple times", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (5e17).toString());
        await auction.newBid(1, (5e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await auction.claimNft(1);
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (5e17).toString());
        await auction.newBid(2, (5e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        await auction.claimNft(2);
    });

    it("closeNft() - single NFT multiple times --staggered", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            5,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (5e17).toString());
        await auction.newBid(1, (5e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await auction.claimNft(1);
        await network.provider.send("evm_increaseTime", [43201]);
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await network.provider.send("evm_increaseTime", [43201]);
        await mockToken.approve(auction.address, (5e17).toString());
        await auction.newBid(2, (5e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
    });

    it("adjustTicketInfo() - basic", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (5e17).toString());
        await auction.newBid(1, (5e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
    });

    it("adjustTicketInfo() - single appraiser loss", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 13]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e14).toString());
        await auction.newBid(1, (2e14).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
        let userPosition = await manager.traderProfile(0);
        let riskLost = 900 - (2e14 / (1e17 / 3)) * 900;
        let tokensLocked = 2 * 1e17 / 3;
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.1); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.9); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(tokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(tokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400 * 5]);
        await maPool.sell(
            0
        );
    });

    it("adjustTicketInfo() - multiple appraisers loss single-closure", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e14).toString());
        await auction.newBid(1, (2e14).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
        let userPosition = await manager.traderProfile(0);
        let riskLost = 900 * (1 - (2e14 / 1e17));
        let userTokensLocked = 2 * 1e17 / 3;
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400]);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers loss multi-closure", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e14).toString());
        await auction.newBid(1, (2e14).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await auction.claimNft(1);
        await maPool.adjustTicketInfo(0, 1);
        let riskLost = 900 * (1 - (2e14 / 1e17));
        let userTokensLocked = 2 * 1e17 / 3;
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (2e14).toString());
        await auction.newBid(2, (2e14).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        await auction.claimNft(2);
        await maPool.adjustTicketInfo(0, 2);
        riskLost = 900 * (1 - (2e14 / 1e17)) * 2;
        userTokensLocked = 1e17 / 3
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400]);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers loss multi-closure --staggered", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e14).toString());
        await auction.newBid(1, (2e14).toString());
        await network.provider.send("evm_increaseTime", [21601]);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (2e14).toString());
        await auction.newBid(2, (2e14).toString());
        await network.provider.send("evm_increaseTime", [21601]);
        await auction.endAuction(1);
        await auction.claimNft(1);
        await maPool.adjustTicketInfo(0, 1);
        let riskLost = 900 * (1 - (2e14 / 1e17));
        let userTokensLocked = 2 * 1e17 / 3;
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        await auction.claimNft(2);
        await maPool.adjustTicketInfo(0, 2);
        riskLost *= 2;
        userTokensLocked = 1e17 / 3;
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(riskLost * 1.05); // RISK POINTS LOST 
        expect(parseInt(userPosition[5])).to.gte(riskLost * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(userTokensLocked * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(userTokensLocked * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400]);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers loss single-closure --early", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e14).toString());
        await auction.newBid(1, (2e14).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await auction.claimNft(1);
        await maPool.adjustTicketInfo(0, 1);
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers loss multi-closure --early", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e14).toString());
        await auction.newBid(1, (2e14).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await auction.claimNft(1);
        await maPool.adjustTicketInfo(0, 1);
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (2e14).toString());
        await auction.newBid(2, (2e14).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        await auction.claimNft(2);
        await maPool.adjustTicketInfo(0, 2);
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers neutral single-closure", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (1e17).toString());
        await auction.newBid(1, (1e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400 * 5]);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers neutral multi-closure", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (1e17).toString());
        await auction.newBid(1, (1e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await auction.claimNft(1);
        await maPool.adjustTicketInfo(0, 1);
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (1e17).toString());
        await auction.newBid(2, (1e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        await maPool.adjustTicketInfo(0, 2);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400 * 5]);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers neutral multi-closure --staggered", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            3,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (1e17).toString());
        await auction.newBid(1, (1e17).toString());
        await network.provider.send("evm_increaseTime", [21601]);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (1e17).toString());
        await auction.newBid(2, (1e17).toString());
        await network.provider.send("evm_increaseTime", [21601]);
        await auction.endAuction(1);
        await auction.claimNft(1);
        await maPool.adjustTicketInfo(0, 1);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        await maPool.adjustTicketInfo(0, 2);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400 * 5]);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers neutral single-closure --early", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (1e17).toString());
        await auction.newBid(1, (1e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers neutral multi-closure --early", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            5,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            5,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            5,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (1e17).toString());
        await auction.newBid(1, (1e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await auction.claimNft(1);
        await maPool.adjustTicketInfo(0, 1);
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (1e17).toString());
        await auction.newBid(2, (1e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        await maPool.adjustTicketInfo(0, 2);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers gain single-closure", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }

        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e17).toString());
        await auction.newBid(1, (2e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400 * 5]);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers gain multi-closure", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }

        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e17).toString());
        await auction.newBid(1, (2e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (2e17).toString());
        await auction.newBid(2, (2e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        await maPool.adjustTicketInfo(0, 2);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400 * 5]);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers gain multi-closure --staggered", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }

        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e17).toString());
        await auction.newBid(1, (2e17).toString());
        await network.provider.send("evm_increaseTime", [21601]);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (2e17).toString());
        await auction.newBid(2, (2e17).toString());
        await network.provider.send("evm_increaseTime", [21601]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        expect(parseInt(await maPool.getTotalAvailableFunds(0))).to.equal(3e17);
        expect(parseInt(await maPool.getTotalAvailableFunds(1))).to.equal(3e17);
        expect(parseInt(await maPool.getTotalAvailableFunds(2))).to.equal(0);
        expect(parseInt(await maPool.getPayoutPerReservation(0))).to.equal(1e17);
        expect(parseInt(await maPool.getPayoutPerReservation(1))).to.equal(1e17);
        expect(parseInt(await maPool.getPayoutPerReservation(2))).to.equal(0);
        await maPool.adjustTicketInfo(0, 2);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await network.provider.send("evm_increaseTime", [86400 * 5]);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers gain single-closure --early", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e17).toString());
        await auction.newBid(1, (2e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multiple appraisers gain multi-closure --early", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }

        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (2e17).toString());
        await auction.newBid(1, (2e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await maPool.adjustTicketInfo(0, 1);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (2e17).toString());
        await auction.newBid(2, (2e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(2);
        await maPool.adjustTicketInfo(0, 2);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.equal(0); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.equal(1e17); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - epoch variation", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['100'],
            0,
            2,
        );
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0],
            ['100'],
            0,
            5,
        );
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0],
            ['100'],
            0,
            9,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (1e16).toString());
        await auction.newBid(1, (1e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (1e16).toString());
        await auction.newBid(2, (1e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 5]);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await mockToken.approve(auction.address, (1e16).toString());
        await auction.newBid(3, (1e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 3]);
        await auction.endAuction(2);
        await auction.endAuction(3);
        await auction.claimNft(2);
        await auction.claimNft(3);
        await maPool.adjustTicketInfo(0, 1);
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(900); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(900 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(2 * 1e17 / 3 * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(2 * 1e17 / 3 * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.adjustTicketInfo(0, 2);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(1800); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(1800 * 0.95); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.lte(1e17 / 3 * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(1e17 / 3 * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.adjustTicketInfo(0, 3);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(1800); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(1800 * 0.95); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.lte(1e17 / 3 * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(1e17 / 3 * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.sell(
            0
        );
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(900); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(900 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(2e17 / 3 * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(2e17 / 3 * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(1800); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(1800 * 0.95); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.lte(1e17 / 3 * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(1e17 / 3 * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 3);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(2700); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(2700 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(10); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(0); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(900); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(900 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(2e17 / 3 * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(2e17 / 3 * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(1800); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(1800 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(1e17 / 3 * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(1e17 / 3 * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 3);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(2700); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(2700 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte(10); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(0); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).sell(
            2
        );
    });

    it("adjustTicketInfo() - multi tranche", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, 1, 2, 3],
            ['100', '100', '100', '100'],
            0,
            2,
        );
        totalCost = costPerToken * 300;
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0, 1, 2],
            ['100', '100', '100'],
            0,
            5,
        );
        totalCost = costPerToken * 200;
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0, 2],
            ['100', '100'],
            0,
            9,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(1, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await network.provider.send("evm_increaseTime", [43201 * 5]);
        await maPool.adjustTicketInfo(0, 1);
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(2, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 5]);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(3, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 3]);
        await auction.endAuction(2);
        await auction.endAuction(3);
        await auction.claimNft(2);
        await auction.claimNft(3);
        await maPool.adjustTicketInfo(0, 2);
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(10800); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(2700); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(2700 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte((4e17 - 33e15 * 4) * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte((4e17 - 33e15 * 4) * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(4e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(8100); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(3600); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(3600 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte((3e17 - 33e15 * 6) * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte((3e17 - 33e15 * 6) * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(3e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(5400); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(1800); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(1800 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte((2e17 - 33e15 * 4) * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte((2e17 - 33e15 * 4) * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(2e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.adjustTicketInfo(0, 3);
        userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(10800); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(2700); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(2700 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte((4e17 - 33e15 * 4) * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte((4e17 - 33e15 * 4) * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(4e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user1).adjustTicketInfo(1, 3);
        userPosition = await manager.traderProfile(1);
        expect(parseInt(userPosition[4])).to.equal(8100); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(3600); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(3600 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte((3e17 - 33e15 * 6) * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte((3e17 - 33e15 * 6) * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(3e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(2, 3);
        userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.equal(5400); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(2700); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(2700 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte((2e17 - 33e15 * 5) * 1.05); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte((2e17 - 33e15 * 5) * 0.95); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(2e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.lte((11e16 - 2e17 / 3) / 2 * 1.05); // TOKENS LOST
        expect(parseInt(userPosition[9])).to.gte((11e16 - 2e17 / 3) / 2 * 0.95); // TOKENS LOST
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
    });

    it("restore() - basic", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, '1', '2'],
            ['300', '300', '300'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(1, (5e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(2, (5e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(3, (5e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 3]);
        await auction.endAuction(1);
        await auction.endAuction(2);
        await auction.endAuction(3);
        await auction.claimNft(1);
        await auction.claimNft(2);
        await auction.claimNft(3);
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            ['0', '1', '2'],
            ['300', '300', '300'],
            2,
            6,
        );
        await network.provider.send("evm_increaseTime", [43201]);
        expect(parseInt(await maPool.spotsRemoved())).to.equal(3);
        await maPool.restore();
        expect(parseInt(await maPool.spotsRemoved())).to.equal(0);
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(4, (5e16).toString());
        expect(parseInt(await maPool.spotsRemoved())).to.equal(1);
        await network.provider.send("evm_increaseTime", [43201]);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(5, (5e16).toString());
        expect(parseInt(await maPool.spotsRemoved())).to.equal(2);
        await network.provider.send("evm_increaseTime", [43201]);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await mockToken.approve(auction.address, (5e16).toString());
        await auction.newBid(6, (5e16).toString());
        expect(parseInt(await maPool.spotsRemoved())).to.equal(3);
        expect(maPool.restore()).to.reverted;
        await network.provider.send("evm_increaseTime", [43201 * 3]);
        await auction.endAuction(4);
        await auction.endAuction(5);
        await auction.endAuction(6);
        await auction.claimNft(4);
        await auction.claimNft(5);
        await auction.claimNft(6);
        await network.provider.send("evm_increaseTime", [43201 * 13]);
        await maPool.restore();
        expect(parseInt(await maPool.spotsRemoved())).to.equal(0);
    });

    it("Special case - different entry times, multi tranche, stagnated duration", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, 1, 2, 3],
            ['100', '100', '100', '100'],
            0,
            2,
        );
        totalCost = costPerToken * 300;
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0, 1, 2],
            ['100', '100', '100'],
            0,
            5,
        );
        totalCost = costPerToken * 200;
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0, 2],
            ['100', '100'],
            0,
            9,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(1, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await network.provider.send("evm_increaseTime", [43201 * 5]);
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [10, 12],
            ['100', '100'],
            3,
            12,
        );
        await maPool.adjustTicketInfo(0, 1);
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(2, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 5]);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(3, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 3]);
        await auction.endAuction(2);
        await auction.endAuction(3);
        await auction.claimNft(2);
        await auction.claimNft(3);
        await maPool.adjustTicketInfo(0, 2);
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        await maPool.connect(user2).adjustTicketInfo(3, 2);
        await maPool.adjustTicketInfo(0, 3);
        await maPool.connect(user1).adjustTicketInfo(1, 3);
        await maPool.connect(user2).adjustTicketInfo(2, 3);
        let userPosition = await manager.traderProfile(2);
        expect(parseInt(userPosition[4])).to.lte(5400); // RISK POINTS
        expect(parseInt(userPosition[4])).to.gte(5400 * 0.95); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(2700); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(2700 * 0.95); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.lte((2e17 - Math.floor(1e17 / 3) * (6 * 0.95))); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte(0); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(2e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.connect(user2).adjustTicketInfo(3, 3);
        userPosition = await manager.traderProfile(3);
        expect(parseInt(userPosition[4])).to.lte(5400); // RISK POINTS
        expect(parseInt(userPosition[4])).to.gte(5400 * 0.95); // RISK POINTS
        expect(parseInt(userPosition[5])).to.lte(3600); // RISK POINTS LOST
        expect(parseInt(userPosition[5])).to.gte(3600 * 0.95); // RISK POINTS LOST 
        expect(parseInt(userPosition[7])).to.lte((2e17 - Math.floor(1e17 / 3) * (4 * 0.95))); // TOKENS LOCKED
        expect(parseInt(userPosition[7])).to.gte((2e17 - Math.floor(1e17 / 3) * (4 * 1.05))); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(2e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.equal(0); // TOKENS LOST
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
        await network.provider.send("evm_increaseTime", [43201 * 14]);
        await maPool.connect(user2).sell(
            3
        );
    });

    it("Special case - purchases in closure epoch after closure", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, 1, 2, 3],
            ['100', '100', '100', '100'],
            0,
            2,
        );
        totalCost = costPerToken * 300;
        await mockToken.connect(user1).approve(maPool.address, totalCost.toString());
        await maPool.connect(user1).purchase(
            user1.address,
            [0, 1, 2],
            ['100', '100', '100'],
            0,
            5,
        );
        totalCost = costPerToken * 200;
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [0, 2],
            ['100', '100'],
            0,
            9,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(1, (11e16).toString());
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        expect(maPool.connect(user2).purchase(
            user2.address,
            [3, 12],
            ['100', '100'],
            0,
            5,
        )).to.reverted;
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [10, 12],
            ['100', '100'],
            0,
            5,
        );
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await network.provider.send("evm_increaseTime", [43201 * 5]);
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [7, 8],
            ['100', '100'],
            3,
            12,
        );
        await maPool.adjustTicketInfo(0, 1);
        await maPool.connect(user1).adjustTicketInfo(1, 1);
        await maPool.connect(user2).adjustTicketInfo(2, 1);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(2, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 5]);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(3, (11e16).toString());
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [9, 13],
            ['100', '100'],
            5,
            13,
        );
        await network.provider.send("evm_increaseTime", [43201 * 3]);
        await auction.endAuction(2);
        await mockToken.connect(user2).approve(maPool.address, totalCost.toString());
        await maPool.connect(user2).purchase(
            user2.address,
            [5, 6],
            ['100', '100'],
            7,
            13,
        );
        await auction.endAuction(3);
        await auction.claimNft(2);
        await auction.claimNft(3);
        await maPool.adjustTicketInfo(0, 2);
        await maPool.connect(user1).adjustTicketInfo(1, 2);
        await maPool.connect(user2).adjustTicketInfo(2, 2);
        await maPool.connect(user2).adjustTicketInfo(3, 2);
        await maPool.connect(user2).adjustTicketInfo(4, 2);
        await maPool.connect(user2).adjustTicketInfo(5, 2);
        await maPool.adjustTicketInfo(0, 3);
        await maPool.connect(user1).adjustTicketInfo(1, 3);
        await maPool.connect(user2).adjustTicketInfo(2, 3);
        await maPool.connect(user2).adjustTicketInfo(3, 3);
        await maPool.connect(user2).adjustTicketInfo(4, 3);
        await maPool.connect(user2).adjustTicketInfo(5, 3);
        await maPool.sell(
            0
        );
        await maPool.connect(user1).sell(
            1
        );
        await maPool.connect(user2).sell(
            2
        );
        await network.provider.send("evm_increaseTime", [43201 * 14]);
        await maPool.connect(user2).sell(
            3
        );
        await maPool.connect(user2).sell(
            4
        );
        await maPool.connect(user2).sell(
            5
        );
        await maPool.connect(user2).sell(
            6
        );
    });

    it("Edge case - risk points loss exceeds risk points due to multiple in the money closures with an out of the money position", async function () {
        await mockToken.connect(user1).mint();
        await mockToken.connect(user2).mint();
        let nftIds = new Array();
        let nftAddresses = new Array();
        for(let i = 0; i < 6; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            nftAddresses, 
            nftIds
        );
        await maPool.setEquations(
            [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
            [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
        );
        await maPool.begin(3, 100, 86400, mockToken.address, 100, 10);
        manager = await Position.attach((await maPool.positionManager()).toString());
        let costPerToken = 1e15;
        let totalCost = costPerToken * 400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [5],
            ['100'],
            0,
            10,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(1, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await auction.endAuction(1);
        await network.provider.send("evm_increaseTime", [43201 * 5]);
        await maPool.adjustTicketInfo(0, 1);
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(2, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 5]);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(3, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 3]);
        await auction.endAuction(2);
        await auction.endAuction(3);
        await auction.claimNft(2);
        await auction.claimNft(3);
        await maPool.adjustTicketInfo(0, 2);
        await maPool.adjustTicketInfo(0, 3);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await mockToken.approve(auction.address, (11e16).toString());
        await auction.newBid(4, (11e16).toString());
        await network.provider.send("evm_increaseTime", [43201 * 3]);
        await auction.endAuction(4);
        await maPool.adjustTicketInfo(0, 4);
        let userPosition = await manager.traderProfile(0);
        expect(parseInt(userPosition[4])).to.equal(2700); // RISK POINTS
        expect(parseInt(userPosition[5])).to.gte(2700); // RISK POINTS LOST
        expect(parseInt(userPosition[7])).to.equal(0); // TOKENS LOCKED
        expect(parseInt(userPosition[8])).to.equal(1e17); // STATIC TOKENS LOCKED
        expect(parseInt(userPosition[9])).to.lte((11e16 - 1e17 / 3) * 4 * 1.05); // TOKENS LOST
        expect(parseInt(userPosition[9])).to.gte((11e16 - 1e17 / 3) * 4 * 0.95); // TOKENS LOST
        await maPool.sell(
            0
        );
    });
});