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

    it("Borrow", async function () {
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
        let balance = await mockToken.balanceOf(deployer.address);
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        let newBalance = parseInt(await mockToken.balanceOf(deployer.address));
        expect(newBalance).to.equal(parseInt(balance) + parseInt('600000000000000000'));
    });

    it("Interest payment", async function () {
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
        console.log((await lend.getInterestPayment([0, 1, 2, 3, 4], mockNft.address, 1)).toString());
        await mockToken.approve(lend.address, (await lend.getInterestPayment([0, 1, 2, 3, 4], mockNft.address, 1)).toString());
        await lend.payInterest(
            [0, 1, 2, 3, 4], 
            mockNft.address, 
            1, 
        );
    });

    it("Repay, repetition", async function () {
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
        await mockToken.approve(lend.address, (await lend.getInterestPayment([0], mockNft.address, 1)).toString());
        await lend.payInterest(
            [0],
            mockNft.address,
            1,
        );
        await mockToken.approve(lend.address, '600000000000000000');
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
        await mockToken.approve(lend.address, (await lend.getInterestPayment([0], mockNft.address, 1)).toString());
        await lend.payInterest(
            [0],
            mockNft.address,
            1,
        );
        await mockToken.approve(lend.address, '600000000000000000');
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
        await mockToken.approve(lend.address, (await lend.getInterestPayment([0], mockNft.address, 1)).toString());
        await lend.payInterest(
            [0],
            mockNft.address,
            1,
        );
        await mockToken.approve(lend.address, '600000000000000000');
        await lend.repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(deployer.address);
    });

    it("Transfer", async function () {
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
        await mockToken.approve(lend.address, (await lend.getInterestPayment([0], mockNft.address, 1)).toString());
        await lend.payInterest(
            [0],
            mockNft.address,
            1,
        );
        await mockToken.connect(user1).approve(lend.address, '600000000000000000');
        await lend.connect(user1).repay(
            mockNft.address,
            1,
            '600000000000000000'
        );
        expect(await mockNft.ownerOf(1)).to.equal(user1.address);
    });

    it("Liquidate - ltv violation straight", async function () {
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
});