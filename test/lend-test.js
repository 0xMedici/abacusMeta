const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Lend", function () {
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
        controller,
        Lend,
        lend
    
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

        Lend = await ethers.getContractFactory("Lend");
        lend = await Lend.deploy(controller.address);

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
        const setLender = await controller.setLender(lend.address);
        await setLender.wait();
        const wlAddress = await controller.addWlUser([deployer.address]);
        await wlAddress.wait();
        await mockToken.mint();
    });

    it("Proper compilation and setting", async function () {
        console.log("Contracts compiled and controller configured!");
    });

    it("borrow() - basic", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.transferFrom(deployer.address, user1.address, 1);
        await mockNft.connect(user1).approve(lend.address, 1);
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        let newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('600000000000000000'));
    });

    it("borrow() - 95%", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.transferFrom(deployer.address, user1.address, 1);
        await mockNft.connect(user1).approve(lend.address, 1);
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '759200000000000000'
        );
        let newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('759200000000000000'));
    });

    it("borrow() - 20% + 30% + 40%", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.transferFrom(deployer.address, user1.address, 1);
        await mockNft.connect(user1).approve(lend.address, 1);
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '160000000000000000'
        );

        let newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('160000000000000000'));
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '240000000000000000'
        );
        newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('400000000000000000'));
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '320000000000000000'
        );
        newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('720000000000000000'));
    });

    it("borrow() - 10% + 84%", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.transferFrom(deployer.address, user1.address, 1);
        await mockNft.connect(user1).approve(lend.address, 1);
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '80000000000000000'
        );
        
        let newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('80000000000000000'));
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '672000000000000000'
        );
        newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('752000000000000000'));
    });

    it("borrow() - 33% + 32% + 30%", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.transferFrom(deployer.address, user1.address, 1);
        await mockNft.connect(user1).approve(lend.address, 1);
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '264000000000000000'
        );

        let newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('264000000000000000'));
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '256000000000000000'
        );
        newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('520000000000000000'));
        await lend.connect(user1).borrow(
            maPool.address,
            mockNft.address,
            1,
            '239000000000000000'
        );
        newBalance = parseInt(await mockToken.balanceOf(user1.address));
        expect(newBalance).to.equal(parseInt('759000000000000000'));
    });

    it("payInterest() - basic", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await network.provider.send("evm_increaseTime", [86401 * 2]);
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86401 * 4]);
        await mockToken.approve(maPool.address, totalCost.toString());
        await mockToken.approve(lend.address, (await lend.getInterestPayment([2, 3, 4], mockNft.address, 1)).toString());
        await lend.payInterest(
            [2, 3, 4], 
            mockNft.address, 
            1, 
        );
    });

    it("payInterest() - multi-epoch, immediate in each", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await network.provider.send("evm_increaseTime", [86401 * 2]);
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await mockToken.approve(lend.address, (await lend.getInterestPayment([2], mockNft.address, 1)).toString());
        expect(lend.payInterest(
            [2], 
            mockNft.address, 
            1, 
        )).to.reverted;
        await network.provider.send("evm_increaseTime", [86401]);
        await mockNft.approve(lend.address, 2);
        await mockToken.approve(lend.address, (await lend.getInterestPayment([2], mockNft.address, 1)).toString());
        await lend.payInterest(
            [2], 
            mockNft.address, 
            1, 
        );
        await network.provider.send("evm_increaseTime", [86401]);
        await mockNft.approve(lend.address, 2);
        await mockToken.approve(lend.address, (await lend.getInterestPayment([3], mockNft.address, 1)).toString());
        await lend.payInterest(
            [3], 
            mockNft.address, 
            1, 
        );
        await network.provider.send("evm_increaseTime", [86401]);
        await mockNft.approve(lend.address, 2);
        await mockToken.approve(lend.address, (await lend.getInterestPayment([4], mockNft.address, 1)).toString());
        await lend.payInterest(
            [4], 
            mockNft.address, 
            1, 
        );
        await network.provider.send("evm_increaseTime", [86401]);
        await mockNft.approve(lend.address, 2);
        await mockToken.approve(lend.address, (await lend.getInterestPayment([5], mockNft.address, 1)).toString());
        await lend.payInterest(
            [5], 
            mockNft.address, 
            1, 
        );
    });

    it("repay() - basic", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86401]);
        await mockNft.approve(lend.address, 2);
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1))).toString());
        await lend.payInterest(
            [0],
            mockNft.address,
            1,
        );
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([1], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        await lend.repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
    });

    it("repay() - immediate", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await mockNft.approve(lend.address, 2);
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1))).toString());
        expect(lend.payInterest(
            [0],
            mockNft.address,
            1,
        )).to.reverted;
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        await lend.repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
    });

    it("repay() - during liquidation window", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            4,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '760000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86400 * 3 + 80000]);
        await mockNft.approve(lend.address, 2);
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([0, 1, 2], mockNft.address, 1))).toString());
        await lend.payInterest(
            [0, 1, 2],
            mockNft.address,
            1,
        );
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([3], mockNft.address, 1)) + parseInt('760000000000000000')).toString());
        await lend.repay(
            mockNft.address,
            1,
            '760000000000000000'
        );
        
    });

    it("repay() - repetition", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        expect(lend.payInterest(
            [0],
            mockNft.address,
            1,
        )).to.reverted;
        await lend.repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(deployer.address);
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        expect(lend.payInterest(
            [0],
            mockNft.address,
            1,
        )).to.reverted;
        await lend.repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(deployer.address);
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        expect(lend.payInterest(
            [0],
            mockNft.address,
            1,
        )).to.reverted;
        await lend.repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(deployer.address);
    });

    it("repay() - repetition --staggered", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        expect(lend.payInterest(
            [0],
            mockNft.address,
            1,
        )).to.reverted;
        await lend.repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(deployer.address);
        await network.provider.send("evm_increaseTime", [86401]);
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([1], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        expect(lend.payInterest(
            [0],
            mockNft.address,
            1,
        )).to.reverted;
        await lend.repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(deployer.address);
        await network.provider.send("evm_increaseTime", [86401]);
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await mockToken.approve(lend.address, (parseInt(await lend.getInterestPayment([2], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        expect(lend.payInterest(
            [0],
            mockNft.address,
            1,
        )).to.reverted;
        await lend.repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(deployer.address);
    });

    it("transferFromLoanOwnership() - basic", async function () {
        await mockToken.connect(user1).mint();
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await lend.transferFromLoanOwnership(
            deployer.address,
            user1.address,
            mockNft.address,
            1
        );
        await mockToken.connect(user1).approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        await lend.connect(user1).repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(user1.address);
    });

    it("transferFromLoanOwnership() - repetition", async function () {
        await mockToken.connect(user1).mint();
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await lend.transferFromLoanOwnership(
            deployer.address,
            user1.address,
            mockNft.address,
            1
        );
        let loan = await lend.loans(mockNft.address, 1);
        expect(loan.borrower).to.equal(user1.address);
        await lend.connect(user1).transferFromLoanOwnership(
            user1.address,
            deployer.address,
            mockNft.address,
            1
        );
        loan = await lend.loans(mockNft.address, 1);
        expect(loan.borrower).to.equal(deployer.address);
        await lend.transferFromLoanOwnership(
            deployer.address,
            user1.address,
            mockNft.address,
            1
        );
        loan = await lend.loans(mockNft.address, 1);
        expect(loan.borrower).to.equal(user1.address);
        await mockToken.connect(user1).approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        await lend.connect(user1).repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(user1.address);
    });

    it("transferFromLoanOwnership() - third party", async function () {
        await mockToken.connect(user1).mint();
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            10,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await lend.allowTransferFrom(
            mockNft.address,
            1,
            user2.address
        );
        await lend.connect(user2).transferFromLoanOwnership(
            deployer.address,
            user1.address,
            mockNft.address,
            1
        );
        await mockToken.connect(user1).approve(lend.address, (parseInt(await lend.getInterestPayment([0], mockNft.address, 1)) + parseInt('600000000000000000')).toString());
        await lend.connect(user1).repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(user1.address);
    });

    it("liquidate() - basic", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            4,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '760000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86400 * 3 + 80000]);
        await lend.liquidate(
            mockNft.address,
            1
        );
    });

    it("liquidate() - late", async function () {
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
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
        await mockToken.approve(maPool.address, totalCost.toString());
        await maPool.purchase(
            deployer.address,
            [
                '0','1','2','3','4','5','6','7'
            ],
            [
                '300', '300', '300','300', '300','300', '300', '300'
            ],
            0,
            4,
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '760000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86401 * 4]);
        await mockToken.connect(user2).approve(lend.address, '760000000000000000');
        await lend.connect(user2).liquidate(
            mockNft.address,
            1
        );
        expect(await mockNft.ownerOf(1)).to.equal(user2.address);
    });
});