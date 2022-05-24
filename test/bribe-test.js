const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Epoch Vault", function () {
    let
      deployer,
      MockNft,
      mockNft,
      user1,
      user2,
      provider,
      VaultFactory,
      factory,
      Vault,
      vault,
      TestOwner,
      owner,
      Treasury,
      treasury,
      Auction,
      auction,
      OwnerToken,
      ownerToken,
      AbcToken,
      abcToken,
      VeAbcToken,
      veToken,
      ClosePool,
      close,
      AbacusController,
      controller,
      EpochVault,
      eVault
    
    beforeEach(async() => {
      [
        deployer, 
        mockNft,
        mockNft2, 
        user1, 
        user2, 
        user3, 
        user4, 
        user5
      ] = await ethers.getSigners();
  
      provider = ethers.getDefaultProvider();
  
      AbacusController = await ethers.getContractFactory("AbacusController");
      controller = await AbacusController.deploy(deployer.address);

      Treasury = await ethers.getContractFactory("Treasury");
      treasury = await Treasury.deploy(deployer.address);
        
      VaultFactory = await ethers.getContractFactory("VaultFactory");
      factory = await VaultFactory.deploy(controller.address);

      AbcToken = await ethers.getContractFactory("ABCToken");
      abcToken = await AbcToken.deploy(controller.address);

      BribeFactory = await ethers.getContractFactory("BribeFactory");
      bribe = await BribeFactory.deploy(controller.address);

      CreditBonds = await ethers.getContractFactory("CreditBonds");
      bonds = await CreditBonds.deploy(controller.address);

      VeAbcToken = await ethers.getContractFactory("VeABC");
      veToken = await VeAbcToken.deploy(controller.address);

      MockNft = await ethers.getContractFactory("MockNft");
      mockNft = await MockNft.deploy();

      EpochVault = await ethers.getContractFactory("EpochVault");
      eVault = await EpochVault.deploy(controller.address, 1209600);

      TestOwner = await ethers.getContractFactory("TestOwner");
      owner = await TestOwner.deploy();
      
      Vault = await ethers.getContractFactory("Vault");

      ClosePool = await ethers.getContractFactory("ClosePool");

      const setCreditBonds = await controller.setCreditBonds(bonds.address);
      await setCreditBonds.wait()
      const approveCreditBonds = await controller.approveCreditBonds();
      await approveCreditBonds.wait()
      const setBondPremium = await controller.setBondMaxPremiumThreshold((100e18).toString());
      await setBondPremium.wait();
      const approveBondPremium = await controller.approveBondMaxPremiumThreshold();
      await approveBondPremium.wait();
      const proposeFactoryAddition = await controller.proposeFactoryAddition(factory.address);
      await proposeFactoryAddition.wait()
      const approveFactoryAddition = await controller.approveFactoryAddition();
      await approveFactoryAddition.wait()
      const setTreasury = await controller.setTreasury(treasury.address);
      await setTreasury.wait();
      const approveTreasuryChange = await controller.approveTreasuryChange();
      await approveTreasuryChange.wait();
      const setToken = await controller.setToken(abcToken.address);
      await setToken.wait();
      const approveTokenChange = await controller.approveTokenChange();
      await approveTokenChange.wait();
      const setVeToken = await controller.setVeToken(veToken.address);
      await setVeToken.wait();
      const approveVeChange = await controller.approveVeChange();
      await approveVeChange.wait();
      const setEpochVault = await controller.setEpochVault(eVault.address);
      await setEpochVault.wait();
      const approveEvaultChange = await controller.approveEvaultChange();
      await approveEvaultChange.wait();
      const setGas = await controller.setAbcGasFee('10000000000000000000');
      await setGas.wait();
      const approveGasFee = await controller.approveGasFeeChange();
      await approveGasFee.wait();
      const setVaultFactory = await controller.setVaultFactory(factory.address);
      await setVaultFactory.wait();
      const approveFactoryChange = await controller.approveFactoryChange();
      await approveFactoryChange.wait();
      const approveGasFeeChange = await controller.approveGasFeeChange();
      await approveGasFeeChange.wait();
      const changeTreasuryRate = await controller.setTreasuryRate(11);
      await changeTreasuryRate.wait();
      const approveRateChange = await controller.approveRateChange();
      await approveRateChange.wait();
      const wlAddress = await factory.addToEarlyMemberWhitelist(deployer.address);
      await wlAddress.wait();

      await abcToken.transfer(user1.address, '1000000000000000000000000000');
    });
  
    it("Proper compilation and setting", async function () {
      console.log("Contracts compiled and controller configured!");
    });

    it("Add to bribe", async function () {
      await bribe.addToBribe(mockNft.address, '1', { value: (5e17).toString() });
      expect(await bribe.offeredBribeSize(mockNft.address, '1')).to.equal((5e17).toString());
      let index = await bribe.bribePerUserIndex(mockNft.address, '1');
      expect(index).to.equal(0);
      expect(await bribe.bribePerAccount(index, mockNft.address, '1', deployer.address)).to.equal((5e17).toString());
    });

    it("Withdraw bribe", async function () {
      await bribe.addToBribe(mockNft.address, '1', { value: (5e17).toString() });
      await bribe.withdrawBribe(mockNft.address, '1', (25e16).toString());
      expect(await bribe.offeredBribeSize(mockNft.address, '1')).to.equal((25e16).toString());
      let index = await bribe.bribePerUserIndex(mockNft.address, '1');
      expect(index).to.equal(0);
      expect(await bribe.bribePerAccount(index, mockNft.address, '1', deployer.address)).to.equal((25e16).toString());
    });

    it("Accepting bribe", async function () {
      await bribe.addToBribe(mockNft.address, '1', { value: (5e17).toString() });
      const createVaultTx = await factory.createVault(
        "Test",
        "TST",
        mockNft.address,
        '1'
      );

      await createVaultTx.wait();

      let vaultAddress = await factory.nftVault(0, mockNft.address, '1');
      vault = Vault.attach(vaultAddress);

      await mockNft.approve(bribe.address, '1');
      await bribe.acceptBribe(mockNft.address, '1');
      expect(await vault.emissionsStarted()).to.equal(true);
    });

    it("Withdraw bribes earned", async function () {
      await bribe.addToBribe(mockNft.address, '1', { value: (5e17).toString() });
      await bribe.addToBribe(mockNft.address, '1', { value: (5e17).toString() });
      const createVaultTx = await factory.createVault(
        "Test",
        "TST",
        mockNft.address,
        '1'
      );

      await createVaultTx.wait();

      let vaultAddress = await factory.nftVault(0, mockNft.address, '1');
      vault = Vault.attach(vaultAddress);
      
      await mockNft.approve(bribe.address, '1');
      await bribe.acceptBribe(mockNft.address, '1');
      await bribe.withdrawBribesEarned((5e17).toString());
      expect(await bribe.bribesEarned(deployer.address)).to.equal((5e17).toString());
    });

});