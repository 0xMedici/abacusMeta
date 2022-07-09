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

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.deploy(controller.address);

    AbcToken = await ethers.getContractFactory("ABCToken");
    abcToken = await AbcToken.deploy(controller.address);

    // BribeFactory = await ethers.getContractFactory("BribeFactory");
    // bribe = await BribeFactory.deploy(controller.address);

    EpochVault = await ethers.getContractFactory("EpochVault");
    eVault = await EpochVault.deploy(controller.address, 86400 * 4);

    CreditBonds = await ethers.getContractFactory("CreditBonds");
    bonds = await CreditBonds.deploy(controller.address, eVault.address);

    Allocator = await ethers.getContractFactory("Allocator");
    alloc = await Allocator.deploy(controller.address, eVault.address);

    MockNft = await ethers.getContractFactory("MockNft");
    mockNft = await MockNft.deploy();

    Vault = await ethers.getContractFactory("Vault");

    Closure = await ethers.getContractFactory("Closure");

    const setAdmin = await controller.setAdmin(deployer.address);
    await setAdmin.wait();
    const setBeta = await controller.setBeta(3);
    await setBeta.wait();
    const setCreditBonds = await controller.setCreditBonds(bonds.address);
    await setCreditBonds.wait();
    const proposeFactoryAddition1 = await controller.proposeFactoryAddition(factory.address);
    await proposeFactoryAddition1.wait();
    const approveFactoryAddition1 = await controller.approveFactoryAddition();
    await approveFactoryAddition1.wait();
    const setToken = await controller.setToken(abcToken.address);
    await setToken.wait();
    const setAllocator = await controller.setAllocator(alloc.address);
    await setAllocator.wait();
    const setEpochVault = await controller.setEpochVault(eVault.address);
    await setEpochVault.wait();
    const wlAddress = await controller.proposeWLUser([deployer.address]);
    await wlAddress.wait();
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

    it("Start emission", async function () {
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address],
            [1,2],
            mockNft.address
        );

        expect(await maPool.emissionsStarted()).to.equal(false);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address],
            [3],
            mockNft.address
        );
        expect(await maPool.emissionsStarted()).to.equal(true);
    });

    it("End emissions", async function () {
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address],
            [1,2],
            mockNft.address
        );
        expect(await maPool.emissionsStarted()).to.equal(false);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address],
            [3],
            mockNft.address
        );
        expect(await maPool.emissionsStarted()).to.equal(true);

        await maPool.remove([mockNft.address], [1]);
        expect(await maPool.emissionsStarted()).to.equal(false);

        await factory.signMultiAssetVault(
            0,
            [mockNft.address],
            [4],
            mockNft.address
        );
        expect(await maPool.emissionsStarted()).to.equal(true);
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3],
            mockNft.address
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 5000 * 1.5;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            ['0', '1', '2','3','4'],
            ['1500', '1500', '1500', '1500', '1500'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool.getDecodedLPInfo(deployer.address, 0);
    });

    it("Purchase with credit bond funds", async function () {
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3],
            mockNft.address
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 3000 * 3 + 1000;
        await bonds.bond( {value:totalCost.toString()} );
        await network.provider.send("evm_increaseTime", [86401 * 4]);
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, 1, 2],
            ['3000', '3000', '3000'],
            4,
            6,
        );

        expect(await bonds.userCredit(1, deployer.address)).to.equal('1000');
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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
    });

    it("General bribe", async function () {
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });

        expect(await maPool.reservationMade(1, mockNft.address, 1)).to.equal(true);
        expect(await maPool.reservations(1)).to.equal(1);
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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
            { value: totalCost.toString() }
        );

        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(true);
        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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
            { value: totalCost.toString() }
        );
            
        expect((await maPool.getCostToReserve(2)).toString()).to.equal('6000000000000000');
        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await maPool.reserve(mockNft.address, 2, 2, { value:(await maPool.getCostToReserve(2)).toString() });
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(6);
        await factory.signMultiAssetVault(
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
            { value: totalCost.toString() }
        )).to.reverted;
    });

    it("Close nft - large pool size", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        let signatureIds = new Array();
        let signatureAddresses = new Array();
        for(let i = 0; i < 1000; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
            if(i < 501) {
                signatureIds[i] = i + 1;
                signatureAddresses[i] = mockNft.address;
            }
        }

        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        for(let j = 0; j < 10; j++) {
            await maPool.includeNft(
                await factory.encodeCompressedValue(
                    nftAddresses.slice(100 * j, 100 * (j + 1)), 
                    nftIds.slice(100 * j, 100 * (j + 1))
                )
            );
        }

        await maPool.begin(501);

        for(let k = 0; k < 5; k++) {
            await factory.signMultiAssetVault(
                0,
                signatureAddresses.slice(100 * k, 100 * (k + 1)),
                signatureIds.slice(100 * k, 100 * (k + 1)),
                mockNft.address
            );
        }
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['3000', '3000', '3000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(true);
        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
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

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(nftAddresses, nftIds)
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1);
    });

    it("Remove nft", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(
                [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address], 
                [1,2,3,4,5,6]
            )
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3],
            mockNft.address
        );
        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(true);
        await maPool.remove([mockNft.address], [1]);
        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
    });

    it("Remove nft - large amount", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        let signatureIds = new Array();
        let signatureAddresses = new Array();
        for(let i = 0; i < 1000; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
            if(i < 501) {
                signatureIds[i] = i + 1;
                signatureAddresses[i] = mockNft.address;
            }
        }

        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        
        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        for(let j = 0; j < 10; j++) {
            await maPool.includeNft(
                await factory.encodeCompressedValue(
                    nftAddresses.slice(100 * j, 100 * (j + 1)), 
                    nftIds.slice(100 * j, 100 * (j + 1))
                )
            );
        }

        await maPool.begin(500);

        for(let k = 0; k < 5; k++) {
            await factory.signMultiAssetVault(
                0,
                signatureAddresses.slice(100 * k, 100 * (k + 1)),
                signatureIds.slice(100 * k, 100 * (k + 1)),
                mockNft.address
            );
        }
        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(true);
        await maPool.remove([mockNft.address], [1]);
        expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
    });

    it("Restore pool", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(
                [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address], 
                [1,2,3,4,5,6]
            )
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1);
        expect((await maPool.payoutPerRes(1)).toString()).to.equal('3000000000000000000');
        await maPool.restore();
        expect((await maPool.payoutPerRes(1)).toString()).to.equal('2000000000000000000');

        await network.provider.send("evm_increaseTime", [43200 * 5]);

        await maPool.sell(
            deployer.address,
            0,
            1000
        );
    });

    it("Restore pool - multi", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(
                [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address], 
                [1,2,3,4,5,6]
            )
        );

        await maPool.begin(4);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4],
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
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1);
        await maPool.restore();

        await network.provider.send("evm_increaseTime", [43200 * 3 + 1]);
        await maPool.sell(
            deployer.address,
            0,
            1000
        );
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['3000', '3000', '3000'],
            2,
            6,
            { value: totalCost.toString() }
        );
        
        await maPool.reserve(mockNft.address, 2, 6, { value:(await maPool.getCostToReserve(6)).toString() });
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await closureMulti.newBid(mockNft.address, 2, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 2);
        await maPool.adjustTicketInfo(deployer.address, 1, mockNft.address, 2);
        await maPool.restore();

        await maPool.reserve(mockNft.address, 3, 6, { value:(await maPool.getCostToReserve(6)).toString() });
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await closureMulti.newBid(mockNft.address, 3, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 3);
        await maPool.adjustTicketInfo(deployer.address, 1, mockNft.address, 3);
        await maPool.restore();

        await network.provider.send("evm_increaseTime", [43200 * 50]);
        await maPool.sell(
            deployer.address,
            1,
            1000
        );
    });

    it("Restore pool - large amount", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        let signatureIds = new Array();
        let signatureAddresses = new Array();
        for(let i = 0; i < 1000; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
            if(i < 501) {
                signatureIds[i] = i + 1;
                signatureAddresses[i] = mockNft.address;
            }
        }

        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        
        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        for(let j = 0; j < 10; j++) {
            await maPool.includeNft(
                await factory.encodeCompressedValue(
                    nftAddresses.slice(100 * j, 100 * (j + 1)), 
                    nftIds.slice(100 * j, 100 * (j + 1))
                )
            );
        }

        await maPool.begin(500);
        for(let k = 0; k < 5; k++) {
            await factory.signMultiAssetVault(
                0,
                signatureAddresses.slice(100 * k, 100 * (k + 1)),
                signatureIds.slice(100 * k, 100 * (k + 1)),
                mockNft.address
            );
        }
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 3000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['3000', '3000', '3000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1);
        await maPool.restore();
    });

    it("Reclaim pending returns", async function () {
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await mockNft.mintNew();
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );

        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(
                [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address], 
                [1,2,3,4,5,6]
            )
        );

        await maPool.begin(3);
        await factory.signMultiAssetVault(
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
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43200]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1);
        await maPool.restore();

        await factory.claimPendingReturns();
        expect(await factory.pendingReturns(deployer.address)).to.equal(0);
    });

    it("Base movement - absolute", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        let signatureIds = new Array();
        let signatureAddresses = new Array();
        for(let i = 0; i < 1000; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
            signatureIds[i] = i + 1;
            signatureAddresses[i] = mockNft.address;
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(0, 100), 
                nftIds.slice(0, 100)
            )
        );
        await factory.signMultiAssetVault(
            0,
            signatureAddresses.slice(0, 100), 
            signatureIds.slice(0, 100),
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld1"
        );
        vaultAddress = await factory.vaultNames("HelloWorld1", 0);
        let maPool1 = await Vault.attach(vaultAddress);
        await maPool1.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(100, 200), 
                nftIds.slice(100, 200)
            )
        );
        await factory.signMultiAssetVault(
            1,
            signatureAddresses.slice(100, 200), 
            signatureIds.slice(100, 200), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld2"
        );
        vaultAddress = await factory.vaultNames("HelloWorld2", 0);
        let maPool2 = await Vault.attach(vaultAddress);
        await maPool2.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(200, 300), 
                nftIds.slice(200, 300)
            )
        );
        await factory.signMultiAssetVault(
            2,
            signatureAddresses.slice(200, 300), 
            signatureIds.slice(200, 300), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld3"
        );
        vaultAddress = await factory.vaultNames("HelloWorld3", 0);
        let maPool3 = await Vault.attach(vaultAddress);
        await maPool3.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(300, 400), 
                nftIds.slice(300, 400)
            )
        );
        await factory.signMultiAssetVault(
            3,
            signatureAddresses.slice(300, 400), 
            signatureIds.slice(300, 400), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld4"
        );
        vaultAddress = await factory.vaultNames("HelloWorld4", 0);
        let maPool4 = await Vault.attach(vaultAddress);
        await maPool4.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(400, 500), 
                nftIds.slice(400, 500)
            )
        );
        await factory.signMultiAssetVault(
            4,
            signatureAddresses.slice(400, 500), 
            signatureIds.slice(400, 500), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld5"
        );
        vaultAddress = await factory.vaultNames("HelloWorld5", 0);
        let maPool5 = await Vault.attach(vaultAddress);
        await maPool5.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(500, 600), 
                nftIds.slice(500, 600)
            )
        );
        await factory.signMultiAssetVault(
            5,
            signatureAddresses.slice(500, 600), 
            signatureIds.slice(500, 600), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld6"
        );
        vaultAddress = await factory.vaultNames("HelloWorld6", 0);
        let maPool6 = await Vault.attach(vaultAddress);
        await maPool6.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(600, 700), 
                nftIds.slice(600, 700)
            )
        );
        await factory.signMultiAssetVault(
            6,
            signatureAddresses.slice(600, 700), 
            signatureIds.slice(600, 700), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld7"
        );
        vaultAddress = await factory.vaultNames("HelloWorld7", 0);
        let maPool7 = await Vault.attach(vaultAddress);
        await maPool7.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(700, 800), 
                nftIds.slice(700, 800)
            )
        );
        await factory.signMultiAssetVault(
            7,
            signatureAddresses.slice(700, 800), 
            signatureIds.slice(700, 800), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld8"
        );
        vaultAddress = await factory.vaultNames("HelloWorld8", 0);
        let maPool8 = await Vault.attach(vaultAddress);
        await maPool8.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(800, 900), 
                nftIds.slice(800, 900)
            )
        );
        await factory.signMultiAssetVault(
            8,
            signatureAddresses.slice(800, 900), 
            signatureIds.slice(800, 900), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld9"
        );
        vaultAddress = await factory.vaultNames("HelloWorld9", 0);
        let maPool9 = await Vault.attach(vaultAddress);
        await maPool9.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(900, 1000), 
                nftIds.slice(900, 1000)
            )
        );
        await factory.signMultiAssetVault(
            9,
            signatureAddresses.slice(900, 1000),
            signatureIds.slice(900, 1000),
            mockNft.address
        );
        
        await maPool.begin(51);
        await maPool1.begin(51);
        await maPool2.begin(51);
        await maPool3.begin(51);
        await maPool4.begin(51);
        await maPool5.begin(51);
        await maPool6.begin(51);
        await maPool7.begin(51);
        await maPool8.begin(51);
        await maPool9.begin(51);

        await maPool.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        await maPool1.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        await maPool2.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        await maPool3.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        await maPool4.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        await maPool5.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        await maPool7.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        await maPool8.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        await maPool6.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 50000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() } 
        );
        await maPool.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool1.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool1.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool1.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        
        await maPool2.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool2.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool2.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool3.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool3.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool3.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool4.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool4.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool4.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool5.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool5.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool5.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool6.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool6.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool6.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool7.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool7.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool7.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool8.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool8.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool8.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool9.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool9.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool9.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await network.provider.send("evm_increaseTime", [86400 * 2]);
        
        await maPool.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool1.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool1.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool1.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool2.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool2.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool2.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool3.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool3.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool3.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool4.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool4.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool4.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool5.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool5.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool5.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool6.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool6.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool6.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool7.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool7.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool7.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool8.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool8.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool8.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool9.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool9.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool9.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            3,
            4,
            { value: totalCost.toString() }
        );

        await network.provider.send("evm_increaseTime", [86401 * 2]);
        await maPool.sell(
            deployer.address,
            3,
            1_000
        );

        expect((await eVault.getBase()).toString()).to.equal('1125000000000000000000');
        expect((await eVault.getBasePercentage()).toString()).to.equal('125');
    });

    it("Base movement - partial", async function () {
        let nftIds = new Array();
        let nftAddresses = new Array();
        let signatureIds = new Array();
        let signatureAddresses = new Array();
        for(let i = 0; i < 1000; i++) {
            await mockNft.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = mockNft.address;
            signatureIds[i] = i + 1;
            signatureAddresses[i] = mockNft.address;
        }

        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.vaultNames("HelloWorld", 0);
        let maPool = await Vault.attach(vaultAddress);
        await maPool.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(0, 100), 
                nftIds.slice(0, 100)
            )
        );
        await factory.signMultiAssetVault(
            0,
            signatureAddresses.slice(0, 100), 
            signatureIds.slice(0, 100),
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld1"
        );
        vaultAddress = await factory.vaultNames("HelloWorld1", 0);
        let maPool1 = await Vault.attach(vaultAddress);
        await maPool1.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(100, 200), 
                nftIds.slice(100, 200)
            )
        );
        await factory.signMultiAssetVault(
            1,
            signatureAddresses.slice(100, 200), 
            signatureIds.slice(100, 200), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld2"
        );
        vaultAddress = await factory.vaultNames("HelloWorld2", 0);
        let maPool2 = await Vault.attach(vaultAddress);
        await maPool2.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(200, 300), 
                nftIds.slice(200, 300)
            )
        );
        await factory.signMultiAssetVault(
            2,
            signatureAddresses.slice(200, 300), 
            signatureIds.slice(200, 300), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld3"
        );
        vaultAddress = await factory.vaultNames("HelloWorld3", 0);
        let maPool3 = await Vault.attach(vaultAddress);
        await maPool3.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(300, 400), 
                nftIds.slice(300, 400)
            )
        );
        await factory.signMultiAssetVault(
            3,
            signatureAddresses.slice(300, 400), 
            signatureIds.slice(300, 400), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld4"
        );
        vaultAddress = await factory.vaultNames("HelloWorld4", 0);
        let maPool4 = await Vault.attach(vaultAddress);
        await maPool4.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(400, 500), 
                nftIds.slice(400, 500)
            )
        );
        await factory.signMultiAssetVault(
            4,
            signatureAddresses.slice(400, 500), 
            signatureIds.slice(400, 500), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld5"
        );
        vaultAddress = await factory.vaultNames("HelloWorld5", 0);
        let maPool5 = await Vault.attach(vaultAddress);
        await maPool5.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(500, 600), 
                nftIds.slice(500, 600)
            )
        );
        await factory.signMultiAssetVault(
            5,
            signatureAddresses.slice(500, 600), 
            signatureIds.slice(500, 600), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld6"
        );
        vaultAddress = await factory.vaultNames("HelloWorld6", 0);
        let maPool6 = await Vault.attach(vaultAddress);
        await maPool6.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(600, 700), 
                nftIds.slice(600, 700)
            )
        );
        await factory.signMultiAssetVault(
            6,
            signatureAddresses.slice(600, 700), 
            signatureIds.slice(600, 700), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld7"
        );
        vaultAddress = await factory.vaultNames("HelloWorld7", 0);
        let maPool7 = await Vault.attach(vaultAddress);
        await maPool7.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(700, 800), 
                nftIds.slice(700, 800)
            )
        );
        await factory.signMultiAssetVault(
            7,
            signatureAddresses.slice(700, 800), 
            signatureIds.slice(700, 800), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld8"
        );
        vaultAddress = await factory.vaultNames("HelloWorld8", 0);
        let maPool8 = await Vault.attach(vaultAddress);
        await maPool8.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(800, 900), 
                nftIds.slice(800, 900)
            )
        );
        await factory.signMultiAssetVault(
            8,
            signatureAddresses.slice(800, 900), 
            signatureIds.slice(800, 900), 
            mockNft.address
        );

        await factory.initiateMultiAssetVault(
            "HelloWorld9"
        );
        vaultAddress = await factory.vaultNames("HelloWorld9", 0);
        let maPool9 = await Vault.attach(vaultAddress);
        await maPool9.includeNft(
            await factory.encodeCompressedValue(
                nftAddresses.slice(900, 1000), 
                nftIds.slice(900, 1000)
            )
        );
        await factory.signMultiAssetVault(
            9,
            signatureAddresses.slice(900, 1000),
            signatureIds.slice(900, 1000),
            mockNft.address
        );
        
        await maPool.begin(51);
        await maPool1.begin(51);
        await maPool2.begin(51);
        await maPool3.begin(51);
        await maPool4.begin(51);
        await maPool5.begin(51);
        await maPool6.begin(51);
        await maPool7.begin(51);
        await maPool8.begin(51);
        await maPool9.begin(51);

        await maPool.offerGeneralBribe(
            (1e18).toString(), 
            1, 
            4, 
            { value: (3e18).toString() }
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 50000 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() } 
        );
        await maPool.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool1.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool1.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool1.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        
        await maPool2.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool2.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool2.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool3.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool3.purchase(
            deployer.address,
            deployer.address,
            ['3', '4', '5'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );
        await maPool3.purchase(
            deployer.address,
            deployer.address,
            ['6', '7', '8'],
            ['50000', '50000', '50000'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await network.provider.send("evm_increaseTime", [86400 * 2]);
        
        await maPool.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool1.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool1.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool1.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool2.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool2.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool2.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool3.sell(
            deployer.address,
            0,
            1_000
        );
        await maPool3.sell(
            deployer.address,
            1,
            1_000
        );
        await maPool3.sell(
            deployer.address,
            2,
            1_000
        );

        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            3,
            4,
            { value: totalCost.toString() }
        );

        await network.provider.send("evm_increaseTime", [86401 * 2]);
        await maPool.sell(
            deployer.address,
            3,
            1_000
        );

        expect((await eVault.getBase()).toString()).to.equal('1092700000000000000000');
        expect((await eVault.getBasePercentage()).toString()).to.equal('116');

        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['50000', '50000', '50000'],
            5,
            6,
            { value: totalCost.toString() }
        );
        await network.provider.send("evm_increaseTime", [86401 * 10]);
        await maPool.sell(
            deployer.address,
            4,
            1_000
        );
        
        expect((await eVault.getBase()).toString()).to.equal('1000000000000000000000');
        expect((await eVault.getBasePercentage()).toString()).to.equal('87');
    });
});