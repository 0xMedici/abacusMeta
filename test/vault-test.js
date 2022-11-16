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
        Closure,
        AbacusController,
        controller
    
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

        Vault = await ethers.getContractFactory("Vault");
        Closure = await ethers.getContractFactory("Closure");

        const setBeta = await controller.setBeta(3);
        await setBeta.wait();
        const setFactory = await controller.setFactory(factory.address);
        await setFactory.wait();
        const wlAddress = await controller.addWlUser([deployer.address]);
        await wlAddress.wait();
        mockToken.mint();
    });

    it("Proper compilation and setting", async function () {
        console.log("Contracts compiled and controller configured!");
    });

    it("Purchase", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 750;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2'
            ],
            [
                '300', '150', '300'
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
                '150'
            ],
            0,
            2,
        );
        expect(await maPool.positionNonce(deployer.address)).to.equal(2);
        totalCost = costPerToken * 600;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '3','4'
            ],
            [
                '300', '300'
            ],
            0,
            2,
        );
        expect(await maPool.positionNonce(deployer.address)).to.equal(3);
        expect(await maPool.getTicketInfo(0, 3)).to.equal(300);
        await network.provider.send("evm_increaseTime", [172801]);
        totalCost = costPerToken * 900;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '5','6','7'
            ],
            [
                '300', '300', '300'
            ],
            2,
            4,
        );
        expect((await maPool.getTokensPurchased(0)).toString()).to.equal("1500");
        expect((await maPool.getPayoutPerReservation(0)).toString()).to.equal("500000000000000000");
        expect((await maPool.getTotalAvailableFunds(0)).toString()).to.equal("1500000000000000000");
        await network.provider.send("evm_increaseTime", [172801 * 10]);
        await maPool.sell(
            deployer.address,
            0
        );
        await maPool.sell(
            deployer.address,
            2
        );
    });

    it("Sale", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 16, 86400, mockToken.address);
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
        await maPool.sell(
            deployer.address,
            0
        );
    });

    it("Buy - sale repetition", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 16, 86400, mockToken.address);
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
        await maPool.sell(
            deployer.address,
            0
        );
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, '1', '2'],
            ['300', '300', '300'],
            0,
            2,
        );
        await maPool.sell(
            deployer.address,
            1
        );
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, '1', '2'],
            ['300', '300', '300'],
            0,
            2,
        );
        await maPool.sell(
            deployer.address,
            2
        );
        
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, '1', '2'],
            ['300', '300', '300'],
            0,
            2,
        );
        await maPool.sell(
            deployer.address,
            3
        );
    });

    it("Close nft", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
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

        //Close an NFT
        //  1. NFT address
        //  2. NFT ID
        await maPool.closeNft(mockNft.address, 1);
    });

    it("Close nft - multiple collections", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.includeNft(
            await factory.getEncodedCompressedValue(nftAddresses1, nftIds1)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
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
        await mockNft2.approve(maPool.address, 1);
        await maPool.closeNft(mockNft2.address, 1);
    });

    it("Close nft - multiple", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
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
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
    });

    it("Close nft - all", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(6, 100, 15, 86400, mockToken.address);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 6;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0, '1', '2'],
            ['600', '600', '600'],
            0,
            2,
        );
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
    });

    it("Adjust ticket info", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['300'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await mockToken.approve(closureMulti.address, (5e17).toString());
        await closureMulti.newBid(mockNft.address, 1, (5e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 1);
    });

    it("Adjust ticket info - loss", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['300'],
            0,
            2,
        );
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await mockToken.approve(closureMulti.address, (2e14).toString());
        await closureMulti.newBid(mockNft.address, 1, (2e14).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 1);
        await network.provider.send("evm_increaseTime", [86400 * 5]);
        await maPool.sell(
            deployer.address,
            0
        );
    });

    it("Adjust ticket info - multiple appraisers loss", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
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
        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await mockToken.approve(closureMulti.address, (2e14).toString());
        await closureMulti.newBid(mockNft.address, 1, (2e14).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 1);
        await maPool.connect(user1).adjustTicketInfo(user1.address, 0, mockNft.address, 1, 1);
        await maPool.connect(user2).adjustTicketInfo(user2.address, 0, mockNft.address, 1, 1);
        await network.provider.send("evm_increaseTime", [86400]);
        await maPool.sell(
            deployer.address,
            0
        );
        await maPool.connect(user1).sell(
            user1.address,
            0
        );
        await maPool.connect(user2).sell(
            user2.address,
            0
        );
    });

    it("Adjust ticket info - multiple appraisers neutral", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
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
        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await mockToken.approve(closureMulti.address, (1e17).toString());
        await closureMulti.newBid(mockNft.address, 1, (1e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 1);
        await maPool.connect(user1).adjustTicketInfo(user1.address, 0, mockNft.address, 1, 1);
        await maPool.connect(user2).adjustTicketInfo(user2.address, 0, mockNft.address, 1, 1);
        // await network.provider.send("evm_increaseTime", [86400 * 5]);
        await maPool.sell(
            deployer.address,
            0
        );
        await maPool.connect(user1).sell(
            user1.address,
            0
        );
        await maPool.connect(user2).sell(
            user2.address,
            0
        );
    });

    it("Adjust ticket info - multiple appraisers gain", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
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

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await mockToken.approve(closureMulti.address, (2e17).toString());
        await closureMulti.newBid(mockNft.address, 1, (2e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 1);
        await maPool.connect(user1).adjustTicketInfo(user1.address, 0, mockNft.address, 1, 1);
        await maPool.connect(user2).adjustTicketInfo(user2.address, 0, mockNft.address, 1, 1);
        // await network.provider.send("evm_increaseTime", [86400 * 5]);

        await maPool.sell(
            deployer.address,
            0
        );

        await maPool.connect(user1).sell(
            user1.address,
            0
        );

        await maPool.connect(user2).sell(
            user2.address,
            0
        );
    });

    it("Close single NFT multiple times", async function () {
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
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15, 86400, mockToken.address);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 100 * 3;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [0],
            ['300'],
            0,
            2,
        );

        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await mockToken.approve(closureMulti.address, (5e17).toString());
        await closureMulti.newBid(mockNft.address, 1, (5e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await closureMulti.claimNft(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 1);
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);
        await mockToken.approve(closureMulti.address, (5e17).toString());
        await closureMulti.newBid(mockNft.address, 1, (5e17).toString());
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 2);
        // await network.provider.send("evm_increaseTime", [86400 * 2]);
        await maPool.sell(
            deployer.address,
            0
        );
    });
});