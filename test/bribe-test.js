const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Bribe factory", function () {
    let
        deployer,
        MockNft,
        mockNft,
        user1,
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

      VaultMulti = await ethers.getContractFactory("VaultMulti");

      ClosePoolMulti = await ethers.getContractFactory("ClosePoolMulti");

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

    it("Add to bribe", async function () {
      await mockNft.mintNew();
      await mockNft.mintNew();
      await mockNft.mintNew();
      await mockNft.mintNew();
      await mockNft.mintNew();
      await factoryMulti.initiateMultiAssetVault(
        "HelloWorld",
        [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
        [1,2,3,4,5,6],
        3
      );
      
      let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
      let maPool = await VaultMulti.attach(vaultAddress);

      await bribe.addToBribe(maPool.address, { value: (5e17).toString() });
      expect(await bribe.offeredBribeSize(maPool.address)).to.equal((5e17).toString());
      expect(await bribe.bribePerAccount(deployer.address, maPool.address)).to.equal((5e17).toString());
    });

    it("Withdraw bribe", async function () {
      await mockNft.mintNew();
      await mockNft.mintNew();
      await mockNft.mintNew();
      await mockNft.mintNew();
      await mockNft.mintNew();
      await factoryMulti.initiateMultiAssetVault(
        "HelloWorld",
        [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
        [1,2,3,4,5,6],
        3
      );
      
      let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
      let maPool = await VaultMulti.attach(vaultAddress);

      await bribe.addToBribe(maPool.address, { value: (5e17).toString() });
      await bribe.withdrawBribe(maPool.address, (25e16).toString());
      
      await factoryMulti.signMultiAssetVault(
          0,
          [mockNft.address, mockNft.address, mockNft.address],
          [1,2,3],
          mockNft.address
      );
      await expect(bribe.withdrawBribe(maPool.address, (25e16).toString())).to.reverted;
      await maPool.remove(mockNft.address, 1);
      await bribe.withdrawBribe(maPool.address, (25e16).toString());
      expect(await bribe.offeredBribeSize(maPool.address)).to.equal((0).toString());
      expect(await bribe.bribePerAccount(deployer.address, maPool.address)).to.equal((0).toString());
    });

    it("Claim bribe", async function () {
      await mockNft.mintNew();
      await mockNft.mintNew();
      await mockNft.mintNew();
      await mockNft.mintNew();
      await mockNft.mintNew();
      await factoryMulti.initiateMultiAssetVault(
        "HelloWorld",
        [mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address, mockNft.address],
        [1,2,3,4,5,6],
        3
      );
      
      let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
      let maPool = await VaultMulti.attach(vaultAddress);

      await bribe.addToBribe(maPool.address, { value: (6e17).toString() });
      
      await factoryMulti.signMultiAssetVault(
          0,
          [mockNft.address, mockNft.address, mockNft.address],
          [1,2,3],
          mockNft.address
      );
      await bribe.collectBribe(maPool.address, mockNft.address, 1);
      expect(await bribe.bribesEarned(deployer.address)).to.equal((2e17).toString());

      await bribe.withdrawBribesEarned();
      expect(await bribe.bribesEarned(deployer.address)).to.equal((0).toString());
    });

});