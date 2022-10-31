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

        //Create a spot pool
        //  1. Pool name
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        //Get the newly created pools address
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        //Include NFTs of choice
        await maPool.includeNft(
            await factory.getEncodedCompressedValue(nftAddresses, nftIds)
        );

        //Begin the pool by inputing:
        //  1. Amount of collateral slots
        //  2. Tranche size
        //  3. Interest rate (on a scale of 0 to 10000)
        //  4. Epoch length
        await maPool.begin(3, 100, 15, 86400);

        //Get cost per token and purchase an appraisal position:
        //  1. Buyer address
        //  2. List of tranches
        //  3. List of amount per tranche
        //  4. Start epoch
        //  5. Unlock epoch
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
            3,
            12,
            { value: totalCost.toString() }
        );
        await mockNft.approve(lend.address, 1);

        //Borrow against the value of the pool (currently valued at 0.2 ETH)
        //  1. Spot pool that you're borrowing against
        //  2. NFT address
        //  3. NFT ID
        //  4. Borrow amount
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
            5,
            12,
            { value: totalCost.toString() }
        );
        await mockNft.approve(lend.address, 2);
        await lend.borrow(
            maPool.address,
            mockNft.address,
            2,
            '270000000000000000'
        );
        await network.provider.send("evm_increaseTime", [86400 * 3]);
        await mockNft.approve(lend.address, 3);
        
        //Pay down outstanding interest (increases based on the amount of missed payments):
        //  1. List of epochs to pay interest for (submitted epoch must have already passed)
        //  2. NFT address
        //  3. NFT ID
        await lend.payInterest(
            [3, 4, 5, 6, 7, 8],
            mockNft.address,
            1,
            { value: await lend.getInterestPayment([3, 4, 5, 6, 7, 8], mockNft.address, 1) }
        );

        //Repay a portion (or the entirety) of an outstanding loan
        //  1. NFT address
        //  2. NFT ID
        await lend.repay(
            mockNft.address,
            1,
            { value: '90000000000000000' }
        );
        await network.provider.send("evm_increaseTime", [86400 + 80000]);
        //Liquidate a borrower
        //  1. NFT address
        //  2. NFT ID
        //  3. List of NFTs in auction
        //  4. List of NFT IDs in auction
        //  5. List of closure nonces corresponding to the above auctions
        await lend.liquidate(
            mockNft.address,
            2,
            [],
            [],
            []
        );

        await network.provider.send("evm_increaseTime", [86400 * 2]);
        let closureMulti = await Closure.attach(await maPool.closePoolContract());

        //Bidding in a closure auction
        //  1. NFT address
        //  2. NFT ID
        await closureMulti.newBid(mockNft.address, 2, { value:(1e17).toString() });
        await network.provider.send("evm_increaseTime", [86400]);

        //End an ongoing auction
        //  1. NFT address
        //  2. NFT ID
        await closureMulti.endAuction(mockNft.address, 2);
        await network.provider.send("evm_increaseTime", [86400 * 2]);

        //Adjust an appraisers position to check for post closure accuracy
        //  1. Position owner
        //  2. Position nonce
        //  3. NFT address
        //  4. NFT ID
        //  5. Closure nonce
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 2, 0);
        await maPool.adjustTicketInfo(deployer.address, 1, mockNft.address, 2, 0);
        await maPool.adjustTicketInfo(deployer.address, 2, mockNft.address, 2, 0);

        //Sell a position
        //  1. Position owner address
        //  2. Position nonce
        await maPool.sell(
            deployer.address,
            0
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