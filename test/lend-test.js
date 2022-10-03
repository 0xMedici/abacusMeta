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
        await maPool.begin(3, 100, 15);
        await factory.signMultiAssetVault(
            "HelloWorld",
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
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
            { value: totalCost.toString() }
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
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
        await maPool.begin(3, 100, 15);
        await factory.signMultiAssetVault(
            "HelloWorld",
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
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
            { value: totalCost.toString() }
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await lend.payInterest(
            0, 
            mockNft.address, 
            1, 
            { value:(await lend.getInterestPayment(0, mockNft.address, 1))}
        );
    });

    it("Repay", async function () {
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
        await maPool.begin(3, 100, 15);
        await factory.signMultiAssetVault(
            "HelloWorld",
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
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
            { value: totalCost.toString() }
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await lend.payInterest(
            0,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(0, mockNft.address, 1) }
        );
        await lend.repay(
            mockNft.address,
            1,
            { value:'600000000000000000' }
        );
        expect(await mockNft.ownerOf(1)).to.equal(deployer.address);
    });

    it("Transfer", async function () {
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
        await maPool.begin(3, 100, 15);
        await factory.signMultiAssetVault(
            "HelloWorld",
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
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
            { value: totalCost.toString() }
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
        await lend.payInterest(
            0,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(0, mockNft.address, 1) }
        );
        await lend.connect(user1).repay(
            mockNft.address,
            1,
            { value:'600000000000000000' }
        );
        expect(await mockNft.ownerOf(1)).to.equal(user1.address);
    });

    it("Liquidate - interest violation", async function () {
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
        await maPool.begin(3, 100, 15);
        await factory.signMultiAssetVault(
            "HelloWorld",
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
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
            { value: totalCost.toString() }
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '500000000000000000'
        );
        await network.provider.send("evm_increaseTime", [172801 * 4]);
        await lend.liquidate(
            mockNft.address,
            1,
            [],
            [],
            []
        );
    });

    it("Liquidate - ltv violation straight", async function () {
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
        await maPool.begin(3, 100, 15);
        await factory.signMultiAssetVault(
            "HelloWorld",
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
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
            { value: totalCost.toString() }
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86400 * 3 + 56000]);
        await lend.liquidate(
            mockNft.address,
            1,
            [],
            [],
            []
        );
    });

    it("Liquidate - ltv violation auction", async function () {
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
        await maPool.begin(3, 100, 15);
        await factory.signMultiAssetVault(
            "HelloWorld",
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        let costPerToken = 1e15;
        let totalCost = costPerToken * 2400;
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
            { value: totalCost.toString() }
        );
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '600000000000000000'
        );
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 2, { value:(1).toString() });
        await closureMulti.newBid(mockNft.address, 3, { value:(1).toString() });
        await network.provider.send("evm_increaseTime", [40000]);
        await lend.liquidate(
            mockNft.address,
            1,
            [mockNft.address, mockNft.address],
            [2, 3],
            [1, 1]
        );
    });
});