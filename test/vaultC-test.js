const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MA Vault", function () {
    let
        deployer,
        MockNft,
        mockNft,
        mockNft2,
        user1,
        user2,
        Factory,
        factory,
        CreditBonds,
        bonds,
        Vault,
        Closure,
        AbcToken,
        abcToken,
        Allocator,
        alloc,
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

    AbcToken = await ethers.getContractFactory("ABCToken");
    abcToken = await AbcToken.deploy(controller.address);

    EpochVault = await ethers.getContractFactory("EpochVault");
    eVault = await EpochVault.deploy(controller.address, 86400 * 4);

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.deploy(controller.address);

    CreditBonds = await ethers.getContractFactory("CreditBonds");
    bonds = await CreditBonds.deploy(controller.address, eVault.address);

    Allocator = await ethers.getContractFactory("Allocator");
    alloc = await Allocator.deploy(controller.address, eVault.address);

    MockNft = await ethers.getContractFactory("MockNft");
    mockNft = await MockNft.deploy();
    mockNft2 = await MockNft.deploy();

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

    // it("Emissions", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 1000);
    //     await controller.setProxy(user1.address);
    //     await factory.connect(user1).signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address],
    //         [1,2]
    //     );
    //     expect(await maPool.emissionStartedCount(0)).to.equal(2);

    //     await controller.clearProxy();
    //     expect(factory.connect(user1).signMultiAssetVault(
    //         0,
    //         [mockNft.address],
    //         [3]
    //     )).to.reverted;

    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address],
    //         [3]
    //     );
    //     expect(await maPool.emissionStartedCount(0)).to.equal(3);
    //     await maPool.remove([mockNft.address, mockNft.address, mockNft.address], [1, 2, 3]);
    //     expect(await maPool.emissionStartedCount(0)).to.equal(0);
    //     expect(await maPool.boostCollection()).to.equal("0x0000000000000000000000000000000000000000");

    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address],
    //         [4]
    //     );
    //     expect(await maPool.emissionStartedCount(0)).to.equal(1);
    // });

    // it("Purchase", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 10000 * 1.5;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [
    //             '0','1','2','3','4','5','6','7','8','9',
    //             '10','11','12','13','14','15','16','17','18','19',
    //             '20','21','22','23','24','25','26','27','28','29',
    //             '30','31','32','33','34','35','36','37','38','39',
    //             '40','41','42','43','44','45','46','47','48','49',
    //             '50','51','52','53','54','55','56','57','58','59',
    //             '60','61','62','63','64','65','66','67','68','69',
    //             '70','71','72','73','74','75','76','77','78','79',
    //             '80','81','82','83','84','85','86','87','88','89',
    //             '90','91','92','93','94','95','96','97','98','99'
    //         ],
    //         [
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150',
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150',
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150',
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150',
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150',
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150',
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150',
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150',
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150',
    //             '150', '150', '150', '150', '150', '150', '150', '150', '150', '150'
    //         ],
    //         0,
    //         10,
    //         { value: totalCost.toString() }
    //     );

    //     expect(await maPool.positionNonce(deployer.address)).to.equal(10);

    //     totalCost = costPerToken * 10000 * 1.2;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [
    //             '0','1','2','3','4','5','6','7','8','9',
    //             '10','11','12','13','14','15','16','17','18','19',
    //             '20','21','22','23','24','25','26','27','28','29',
    //             '30','31','32','33','34','35','36','37','38','39',
    //             '40','41','42','43','44','45','46','47','48','49',
    //             '50','51','52','53','54','55','56','57','58','59',
    //             '60','61','62','63','64','65','66','67','68','69',
    //             '70','71','72','73','74','75','76','77','78','79',
    //             '80','81','82','83','84','85','86','87','88','89',
    //             '90','91','92','93','94','95','96','97','98','99'
    //         ],
    //         [
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120',
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120',
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120',
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120',
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120',
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120',
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120',
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120',
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120',
    //             '120', '120', '120', '120', '120', '120', '120', '120', '120', '120'
    //         ],
    //         0,
    //         10,
    //         { value: totalCost.toString() }
    //     );
    //     expect(await maPool.positionNonce(deployer.address)).to.equal(20);

    //     totalCost = costPerToken * 30;
    //     await expect(maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         ['8'],
    //         ['300'],
    //         0,
    //         10,
    //         { value: totalCost.toString() }
    //     )).to.reverted;

    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         ['8'],
    //         ['30'],
    //         0,
    //         10,
    //         { value: totalCost.toString() }
    //     )

    //     expect(await maPool.getTicketInfo(0, 7)).to.equal(270);
    //     expect(await maPool.getTicketInfo(0, 8)).to.equal(300);

    //     totalCost = costPerToken * 9000 * 1.5;
    //     await expect(maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         ['0', '1', '2','3','4','5','6','7','8','9'],
    //         ['1500', '1500', '1500', '1500', '1500', '1500', '1500', '1500', '1500', '1500'],
    //         0,
    //         10,
    //         { value: totalCost.toString() }
    //     )).to.reverted;

    //     await network.provider.send("evm_increaseTime", [172801 * 10]);
    //     await maPool.sell(
    //         deployer.address,
    //         9,
    //         1000
    //     );
    // });

    // it("Purchase with credit bond funds", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 3 + 1000;
    //     await bonds.bond( {value:totalCost.toString()} );
    //     await network.provider.send("evm_increaseTime", [86401 * 4]);
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0, 1, 2],
    //         ['300', '300', '300'],
    //         4,
    //         6,
    //     );

    //     expect(await bonds.userCredit(1, deployer.address)).to.equal('1000');
    // });

    // it("Transfer", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 5;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         ['0', '1', '2', '3', '4'],
    //         ['300', '300', '300', '300', '300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );
        
    //     await maPool.transferFrom(
    //         deployer.address,
    //         user1.address,
    //         0
    //     );
    // });

    // it("Sale - test non-wl pool", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft2.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft2.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft2.address, mockNft2.address, mockNft2.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0, '1', '2'],
    //         ['300', '300', '300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );
        
    //     await expect(maPool.sell(
    //         deployer.address,
    //         0,
    //         1000
    //     )).to.reverted;

    //     await network.provider.send("evm_increaseTime", [172801]);
    //     await maPool.sell(
    //         deployer.address,
    //         0,
    //         1000
    //     );
    // });

    // it("Sale", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0, '1', '2'],
    //         ['300', '300', '300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );
        
    //     await expect(maPool.sell(
    //         deployer.address,
    //         0,
    //         1000
    //     )).to.reverted;

    //     await network.provider.send("evm_increaseTime", [172801]);
    //     await maPool.sell(
    //         deployer.address,
    //         0,
    //         1000
    //     );
    // });

    // it("Reserve for closure", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0, '1', '2'],
    //         ['300', '300', '300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });

    //     expect(await maPool.reservationMade(1, mockNft.address, 1)).to.equal(true);
    //     expect(await maPool.reservations(1)).to.equal(1);
    // });

    // it("Close nft", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0, '1', '2'],
    //         ['300', '300', '300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);
    // });

    // it("Close nft - multiple collections", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     let nftIds1 = new Array();
    //     let nftAddresses1 = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft2.mintNew();
    //         nftIds1[i] = i + 1;
    //         nftAddresses1[i] = mockNft2.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);
        
    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );
        
    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses1, nftIds1)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );

    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft2.address, mockNft2.address, mockNft2.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0, '1', '2'],
    //         ['300', '300', '300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);

    //     await maPool.reserve(mockNft2.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft2.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft2.address, 1);
    // });

    // it("Close nft - multiple", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0, '1', '2'],
    //         ['300', '300', '300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );
            
    //     expect((await maPool.getCostToReserve(2)).toString()).to.equal('240000000000000');
    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await maPool.reserve(mockNft.address, 2, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await maPool.reserve(mockNft.address, 3, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);
    //     await mockNft.approve(maPool.address, 2);
    //     await maPool.closeNft(mockNft.address, 2);
    //     await mockNft.approve(maPool.address, 3);
    //     await maPool.closeNft(mockNft.address, 3);
    // });

    // it("Close nft - all", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(6, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3,4,5,6]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 6;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0, '1', '2'],
    //         ['600', '600', '600'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );
        
    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await maPool.reserve(mockNft.address, 2, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await maPool.reserve(mockNft.address, 3, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await maPool.reserve(mockNft.address, 4, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await maPool.reserve(mockNft.address, 5, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await maPool.reserve(mockNft.address, 6, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await mockNft.approve(maPool.address, 2);
    //     await mockNft.approve(maPool.address, 3);
    //     await mockNft.approve(maPool.address, 4);
    //     await mockNft.approve(maPool.address, 5);
    //     await mockNft.approve(maPool.address, 6);
    //     await maPool.closeNft(mockNft.address, 1);
    //     await maPool.closeNft(mockNft.address, 2);
    //     await maPool.closeNft(mockNft.address, 3);
    //     await maPool.closeNft(mockNft.address, 4);
    //     await maPool.closeNft(mockNft.address, 5);
    //     await maPool.closeNft(mockNft.address, 6);
    // });

    // it("Close nft - large pool size", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     let signatureIds = new Array();
    //     let signatureAddresses = new Array();
    //     for(let i = 0; i < 1000; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //         if(i < 501) {
    //             signatureIds[i] = i + 1;
    //             signatureAddresses[i] = mockNft.address;
    //         }
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     for(let j = 0; j < 10; j++) {
    //         await maPool.includeNft(
    //             await factory.encodeCompressedValue(
    //                 nftAddresses.slice(100 * j, 100 * (j + 1)), 
    //                 nftIds.slice(100 * j, 100 * (j + 1))
    //             )
    //         );
    //     }

    //     await maPool.begin(501, 100);

    //     for(let k = 0; k < 5; k++) {
    //         await factory.signMultiAssetVault(
    //             0,
    //             signatureAddresses.slice(100 * k, 100 * (k + 1)),
    //             signatureIds.slice(100 * k, 100 * (k + 1))
    //         );
    //     }
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 300 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0, '1', '2'],
    //         ['300', '300', '300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);
    // });

    // it("Adjust ticket info", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 100 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0],
    //         ['300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);

    //     let closureMulti = await Closure.attach(await maPool.closePoolContract());
    //     await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
    //     await network.provider.send("evm_increaseTime", [43201]);
    //     await closureMulti.endAuction(mockNft.address, 1);
    //     await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);
    // });

    // it("Adjust ticket info - loss", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 100 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0],
    //         ['300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);

    //     let closureMulti = await Closure.attach(await maPool.closePoolContract());
    //     await closureMulti.newBid(mockNft.address, 1, { value:(1).toString() });
    //     await network.provider.send("evm_increaseTime", [43201]);
    //     await closureMulti.endAuction(mockNft.address, 1);
    //     await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);
    //     await network.provider.send("evm_increaseTime", [86400 * 5]);

    //     await maPool.sell(
    //         deployer.address,
    //         0,
    //         1000
    //     );
    // });

    // it("Adjust ticket info - multiple appraisers loss", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 100;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0],
    //         ['100'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.connect(user1).purchase(
    //         user1.address,
    //         user1.address,
    //         [0],
    //         ['100'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.connect(user2).purchase(
    //         user2.address,
    //         user2.address,
    //         [0],
    //         ['100'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);

    //     let closureMulti = await Closure.attach(await maPool.closePoolContract());
    //     await closureMulti.newBid(mockNft.address, 1, { value:(1).toString() });
    //     await network.provider.send("evm_increaseTime", [43201]);
    //     await closureMulti.endAuction(mockNft.address, 1);
    //     await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);
    //     await maPool.connect(user1).adjustTicketInfo(user1.address, 0, mockNft.address, 1, 0);
    //     await maPool.connect(user2).adjustTicketInfo(user2.address, 0, mockNft.address, 1, 0);
    //     await network.provider.send("evm_increaseTime", [86400 * 5]);

    //     await maPool.sell(
    //         deployer.address,
    //         0,
    //         1000
    //     );

    //     await maPool.connect(user1).sell(
    //         user1.address,
    //         0,
    //         1000
    //     );

    //     await maPool.connect(user2).sell(
    //         user2.address,
    //         0,
    //         1000
    //     );
    // });

    // it("Adjust ticket info - multiple appraisers neutral", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 100;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0],
    //         ['100'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.connect(user1).purchase(
    //         user1.address,
    //         user1.address,
    //         [0],
    //         ['100'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.connect(user2).purchase(
    //         user2.address,
    //         user2.address,
    //         [0],
    //         ['100'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);

    //     let closureMulti = await Closure.attach(await maPool.closePoolContract());
    //     await closureMulti.newBid(mockNft.address, 1, { value:(1e17).toString() });
    //     await network.provider.send("evm_increaseTime", [43201]);
    //     await closureMulti.endAuction(mockNft.address, 1);
    //     await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);
    //     await maPool.connect(user1).adjustTicketInfo(user1.address, 0, mockNft.address, 1, 0);
    //     await maPool.connect(user2).adjustTicketInfo(user2.address, 0, mockNft.address, 1, 0);
    //     await network.provider.send("evm_increaseTime", [86400 * 5]);

    //     await maPool.sell(
    //         deployer.address,
    //         0,
    //         1000
    //     );

    //     await maPool.connect(user1).sell(
    //         user1.address,
    //         0,
    //         1000
    //     );

    //     await maPool.connect(user2).sell(
    //         user2.address,
    //         0,
    //         1000
    //     );
    // });

    // it("Adjust ticket info - multiple appraisers gain", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 100;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0],
    //         ['100'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.connect(user1).purchase(
    //         user1.address,
    //         user1.address,
    //         [0],
    //         ['100'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.connect(user2).purchase(
    //         user2.address,
    //         user2.address,
    //         [0],
    //         ['100'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);

    //     let closureMulti = await Closure.attach(await maPool.closePoolContract());
    //     await closureMulti.newBid(mockNft.address, 1, { value:(2e17).toString() });
    //     await network.provider.send("evm_increaseTime", [43201]);
    //     await closureMulti.endAuction(mockNft.address, 1);
    //     await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);
    //     await maPool.connect(user1).adjustTicketInfo(user1.address, 0, mockNft.address, 1, 0);
    //     await maPool.connect(user2).adjustTicketInfo(user2.address, 0, mockNft.address, 1, 0);
    //     await network.provider.send("evm_increaseTime", [86400 * 5]);

    //     await maPool.sell(
    //         deployer.address,
    //         0,
    //         1000
    //     );

    //     await maPool.connect(user1).sell(
    //         user1.address,
    //         0,
    //         1000
    //     );

    //     await maPool.connect(user2).sell(
    //         user2.address,
    //         0,
    //         1000
    //     );
    // });

    // it("Close single NFT multiple times", async function () {
    //     let nftIds = new Array();
    //     let nftAddresses = new Array();
    //     for(let i = 0; i < 6; i++) {
    //         await mockNft.mintNew();
    //         nftIds[i] = i + 1;
    //         nftAddresses[i] = mockNft.address;
    //     }

    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(nftAddresses, nftIds)
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
        
    //     let costPerToken = 1e15;
    //     let totalCost = costPerToken * 100 * 3;
    //     await maPool.purchase(
    //         deployer.address,
    //         deployer.address,
    //         [0],
    //         ['300'],
    //         0,
    //         2,
    //         { value: totalCost.toString() }
    //     );

    //     await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);

    //     let closureMulti = await Closure.attach(await maPool.closePoolContract());
    //     await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
    //     await network.provider.send("evm_increaseTime", [43201]);
    //     await closureMulti.endAuction(mockNft.address, 1);
    //     await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);

    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address],
    //         [1]
    //     );

    //     await maPool.reserve(mockNft.address, 1, 4, { value:(await maPool.getCostToReserve(4)).toString() });
    //     await mockNft.approve(maPool.address, 1);
    //     await maPool.closeNft(mockNft.address, 1);

    //     await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
    //     await network.provider.send("evm_increaseTime", [43201]);
    //     await closureMulti.endAuction(mockNft.address, 1);
    //     await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 1);

    //     await network.provider.send("evm_increaseTime", [86400 * 2]);
    //     await maPool.sell(
    //         deployer.address,
    //         0,
    //         1000
    //     );
    // });

    // it("Remove nft", async function () {
    //     await mockNft.mintNew();
    //     await mockNft.mintNew();
    //     await mockNft.mintNew();
    //     await mockNft.mintNew();
    //     await mockNft.mintNew();
    //     await factory.initiateMultiAssetVault(
    //         "HelloWorld"
    //     );

    //     let vaultAddress = await factory.vaultNames("HelloWorld");
    //     let maPool = await Vault.attach(vaultAddress);

    //     await maPool.includeNft(
    //         await factory.encodeCompressedValue(
    //             [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address], 
    //             [1,2,3,4,5,6]
    //         )
    //     );

    //     await maPool.begin(3, 100);
    //     await factory.signMultiAssetVault(
    //         0,
    //         [mockNft.address, mockNft.address, mockNft.address],
    //         [1,2,3]
    //     );
    //     expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(true);
    //     await maPool.remove([mockNft.address], [1]);
    //     expect(await controller.nftVaultSigned(mockNft.address, 1)).to.equal(false);
    // });

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
        
        let vaultAddress = await factory.vaultNames("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        for(let j = 0; j < 10; j++) {
            await maPool.includeNft(
                await factory.encodeCompressedValue(
                    nftAddresses.slice(100 * j, 100 * (j + 1)), 
                    nftIds.slice(100 * j, 100 * (j + 1))
                )
            );
        }

        await maPool.begin(500, 100);

        for(let k = 0; k < 5; k++) {
            await factory.signMultiAssetVault(
                0,
                signatureAddresses.slice(100 * k, 100 * (k + 1)),
                signatureIds.slice(100 * k, 100 * (k + 1))
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

        let vaultAddress = await factory.vaultNames("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(
                [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address], 
                [1,2,3,4,5,6]
            )
        );

        await maPool.begin(3, 100);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['300', '300', '300'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);
        expect((await maPool.payoutPerRes(1)).toString()).to.equal('300000000000000000');
        await network.provider.send("evm_increaseTime", [43201]);
        await maPool.restore();
        expect((await maPool.payoutPerRes(1)).toString()).to.equal('200000000000000000');

        await network.provider.send("evm_increaseTime", [43201 * 5]);

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

        let vaultAddress = await factory.vaultNames("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(
                [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address], 
                [1,2,3,4,5,6]
            )
        );

        await maPool.begin(4, 100);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address, mockNft.address],
            [1,2,3,4]
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['300', '300', '300'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);
        await network.provider.send("evm_increaseTime", [43201]);
        await maPool.restore();
        await network.provider.send("evm_increaseTime", [43201 * 3 + 1]);
        await maPool.sell(
            deployer.address,
            0,
            1000
        );
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['300', '300', '300'],
            2,
            6,
            { value: totalCost.toString() }
        );
        
        await maPool.reserve(mockNft.address, 2, 6, { value:(await maPool.getCostToReserve(6)).toString() });
        await mockNft.approve(maPool.address, 2);
        await maPool.closeNft(mockNft.address, 2);
        await closureMulti.newBid(mockNft.address, 2, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 2);
        await maPool.adjustTicketInfo(deployer.address, 1, mockNft.address, 2, 0);
        await network.provider.send("evm_increaseTime", [43201]);
        await maPool.restore();

        await maPool.reserve(mockNft.address, 3, 6, { value:(await maPool.getCostToReserve(6)).toString() });
        await mockNft.approve(maPool.address, 3);
        await maPool.closeNft(mockNft.address, 3);
        await closureMulti.newBid(mockNft.address, 3, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 3);
        await maPool.adjustTicketInfo(deployer.address, 1, mockNft.address, 3, 0);
        await network.provider.send("evm_increaseTime", [43201]);
        await maPool.restore();
        await network.provider.send("evm_increaseTime", [43201 * 50]);
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
        
        let vaultAddress = await factory.vaultNames("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        for(let j = 0; j < 10; j++) {
            await maPool.includeNft(
                await factory.encodeCompressedValue(
                    nftAddresses.slice(100 * j, 100 * (j + 1)), 
                    nftIds.slice(100 * j, 100 * (j + 1))
                )
            );
        }

        await maPool.begin(500, 100);
        for(let k = 0; k < 5; k++) {
            await factory.signMultiAssetVault(
                0,
                signatureAddresses.slice(100 * k, 100 * (k + 1)),
                signatureIds.slice(100 * k, 100 * (k + 1))
            );
        }
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['300', '300', '300'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);
        await network.provider.send("evm_increaseTime", [43201]);
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

        let vaultAddress = await factory.vaultNames("HelloWorld");
        let maPool = await Vault.attach(vaultAddress);

        await maPool.includeNft(
            await factory.encodeCompressedValue(
                [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address], 
                [1,2,3,4,5,6]
            )
        );

        await maPool.begin(3, 100);
        await factory.signMultiAssetVault(
            0,
            [mockNft.address, mockNft.address, mockNft.address],
            [1,2,3]
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 300 * 3;
        await maPool.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['300', '300', '300'],
            0,
            2,
            { value: totalCost.toString() }
        );

        await maPool.reserve(mockNft.address, 1, 2, { value:(await maPool.getCostToReserve(2)).toString() });
        await mockNft.approve(maPool.address, 1);
        await maPool.closeNft(mockNft.address, 1);

        let closureMulti = await Closure.attach(await maPool.closePoolContract());
        await closureMulti.newBid(mockNft.address, 1, { value:(5e17).toString() });
        await network.provider.send("evm_increaseTime", [43201]);
        await closureMulti.endAuction(mockNft.address, 1);
        await maPool.adjustTicketInfo(deployer.address, 0, mockNft.address, 1, 0);
        await network.provider.send("evm_increaseTime", [43201]);
        await maPool.restore();

        await factory.claimPendingReturns();
        expect(await factory.pendingReturns(deployer.address)).to.equal(0);
    });
});