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
      await eVault.begin();

  });

  it("Proper compilation and setting", async function () {
    console.log("Contracts compiled and controller configured!");
  });

  it("Test update epoch - non boosted", async function () {
    await abcToken.transfer(user1.address, '1000000000000000000000000');
    await mockNft.approve(factory.address, '1');
    const createVaultTx = await factory.createVault(
      "Test", 
      "TST", 
      mockNft.address, 
      '1'
    );

    await createVaultTx.wait();

    let vaultAddress = await factory.nftVault(0, mockNft.address, '1');
    vault = Vault.attach(vaultAddress);

    await vault.startEmissions();
    let costPerToken = 1e15;
    let totalCost = 1.0125 * (3000 * costPerToken);
    await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 604800, { value: totalCost.toString() });
    await network.provider.send("evm_increaseTime", [604800]);
    await vault.sell(deployer.address);
    expect(await eVault.getUserCredits(0, deployer.address)).to.equal((3e18).toString());
  });

  it("Test update epoch - boosted", async function () {
    await abcToken.transfer(user1.address, '1000000000000000000000000');
    await veToken.lockTokens('6000000000000000000', 1814400);
    await veToken.allocateToCollection(mockNft.address, '600000000000000000');
    await network.provider.send("evm_increaseTime", [1209600]);

    await mockNft.approve(factory.address, '1');
    const createVaultTx = await factory.createVault(
      "Test", 
      "TST", 
      mockNft.address, 
      '1'
    );

    await createVaultTx.wait();

    let vaultAddress = await factory.nftVault(0, mockNft.address, '1');
    vault = Vault.attach(vaultAddress);

    await vault.startEmissions();
    await vault.adjustPayoutRatio(100);
    let costPerToken = 1e15;
    let totalCost = 1.0125 * (3000 * costPerToken);
    await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
    await network.provider.send("evm_increaseTime", [604800]);
    totalCost = 1.0125 * (3000 * costPerToken);
    await vault.purchase(deployer.address, deployer.address, ['3000000000000000000', '4000000000000000000', '5000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 1814400, { value: totalCost.toString() });
  });

  it("Claim emissions rewards", async function () {
    await abcToken.transfer(user1.address, '1000000000000000000000000');
    await mockNft.approve(factory.address, '1');
    const createVaultTx = await factory.createVault(
      "Test", 
      "TST", 
      mockNft.address, 
      '1'
    );

    await createVaultTx.wait();

    let vaultAddress = await factory.nftVault(0, mockNft.address, '1');
    vault = Vault.attach(vaultAddress);

    await vault.startEmissions();
    let costPerToken = 1e15;
    let totalCost = 1.0125 * (3000 * costPerToken);
    await vault.purchase(deployer.address, deployer.address, [0, '1000000000000000000', '2000000000000000000'], ['1000000000000000000000', '1000000000000000000000', '1000000000000000000000'], 604800, { value: totalCost.toString() });
    await network.provider.send("evm_increaseTime", [604800]);
    await vault.sell(deployer.address);

    await network.provider.send("evm_increaseTime", [604800]);
    await eVault.claimAbcReward(deployer.address, 0);
  });
});