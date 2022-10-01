const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Life cycle", function () {
    let
        deployer,
        MockNft,
        mockNft,
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
        console.log(
            `
        This life cycle goes as follows:
            1. Purchase an appraisal position for epoch 0-10
            2. NFT owner 1 borrows funds in epoch 3 
            3. New appraiser purchases an appraisal posiiton for epoch 4-12
            4. NFT owner 2 borrows funds in epoch 5
            6. NFT owner 1 pays back loan in epoch 8
            7. NFT owner 2 defaults in epoch 9
            8. NFT owner 1 borrows funds in epoch 9
            9. Appraiser 1 sells position
            10. NFT owner 1 pays back loan
            11. Appraiser 2 sells position
            `
        );
    });

    it("Life cycle", async function () {
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
        let vaultAddress = await factory.vaultNames("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );
        await maPool.begin(3, 100, 15);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300;
        await maPool.purchase(
            deployer.address,
            ['0'],
            ['300'],
            0,
            10,
            { value: totalCost.toString() }
        );
        await network.provider.send("evm_increaseTime", [86400 * 3]);
        await maPool.purchase(
            deployer.address,
            ['1'],
            ['300'],
            4,
            12,
            { value: totalCost.toString() }
        );
        await maPool.reserve(mockNft.address, 1, 10, { value:(await maPool.getCostToReserve(10)).toString() });
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '90000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86400 * 2]);
        await maPool.purchase(
            deployer.address,
            ['2'],
            ['300'],
            6,
            12,
            { value: totalCost.toString() }
        );
        await maPool.reserve(mockNft.address, 2, 10, { value:(await maPool.getCostToReserve(10)).toString() });
        await mockNft.approve(lend.address, 2);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            2,
            '90000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86400 * 3]);
        await lend.payInterest(
            3,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(3, mockNft.address, 1) }
        );
        await lend.payInterest(
            4,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(4, mockNft.address, 1) }
        );
        await lend.payInterest(
            5,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(5, mockNft.address, 1) }
        );
        await lend.payInterest(
            6,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(6, mockNft.address, 1) }
        );
        await lend.payInterest(
            7,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(7, mockNft.address, 1) }
        );
        await lend.payInterest(
            8,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(8, mockNft.address, 1) }
        );
        await lend.repay(
            mockNft.address,
            1,
            { value: '90000000000000000' }
        );
        await network.provider.send("evm_increaseTime", [86400]);
        await lend.liquidate(
            mockNft.address,
            2,
            [],
            [],
            []
        );
        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 2, { value:(1e17).toString() });
        await network.provider.send("evm_increaseTime", [86400]);
        await closureMulti.endAuction(mockNft.address, 2);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address],
            [2]
        );
        await maPool.reserve(mockNft.address, 1, 15, { value:(await maPool.getCostToReserve(15)).toString() });
        await mockNft.approve(lend.address, 1);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            1,
            '90000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86400 * 2]);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 2, 0);
        await maPool.adjustTicketInfo(deployer.address, 1, mockNft.address, 2, 0);
        await maPool.adjustTicketInfo(deployer.address, 2, mockNft.address, 2, 0);
        await maPool.sell(
            deployer.address,
            0
        );
        await lend.payInterest(
            10,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(10, mockNft.address, 1) }
        );
        await lend.payInterest(
            11,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(11, mockNft.address, 1) }
        );
        await lend.payInterest(
            12,
            mockNft.address,
            1,
            { value: await lend.getInterestPayment(12, mockNft.address, 1) }
        );
        await lend.repay(
            mockNft.address,
            1,
            { value: '90000000000000000' }
        );
        await maPool.sell(
            deployer.address,
            1
        );
        await maPool.sell(
            deployer.address,
            2
        );
    });
});