const { TransactionDescription } = require("@ethersproject/abi");
const { SupportedAlgorithm } = require("@ethersproject/sha2");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Nft Eth", function () {
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

      Treasury = await ethers.getContractFactory("Treasury");
      treasury = await Treasury.deploy(deployer.address);

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

      NftEth = await ethers.getContractFactory("NftEth");
      nEth = await NftEth.deploy(controller.address);

      VaultMulti = await ethers.getContractFactory("VaultMulti");

      ClosePoolMulti = await ethers.getContractFactory("ClosePoolMulti");

      const setReservationFee = await controller.proposeReservationFee(1);
      await setReservationFee.wait();
      const approveReservationFee = await controller.approveReservationFee();
      await approveReservationFee.wait();
      const setNftEth = await controller.setNftEth(nEth.address);
      await setNftEth.wait();
      const setBeta = await controller.setBeta(3);
      await setBeta.wait();
      const approveBeta = await controller.approveBeta();
      await approveBeta.wait();
      const setCreditBonds = await controller.setCreditBonds(bonds.address);
      await setCreditBonds.wait()
      const setBondPremium = await controller.setBondMaxPremiumThreshold((100e18).toString());
      await setBondPremium.wait();
      const approveBondPremium = await controller.approveBondMaxPremiumThreshold();
      await approveBondPremium.wait();
      const proposeFactoryAddition1 = await controller.proposeFactoryAddition(factoryMulti.address);
      await proposeFactoryAddition1.wait()
      const approveFactoryAddition1 = await controller.approveFactoryAddition();
      await approveFactoryAddition1.wait()
      const setTreasury = await controller.setTreasury(treasury.address);
      await setTreasury.wait();
      const approveTreasuryChange = await controller.approveTreasuryChange();
      await approveTreasuryChange.wait();
      const setToken = await controller.setToken(abcToken.address);
      await setToken.wait();
      const setAllocator = await controller.setAllocator(alloc.address);
      await setAllocator.wait();
      const setEpochVault = await controller.setEpochVault(eVault.address);
      await setEpochVault.wait();
      const changeTreasuryRate = await controller.setTreasuryRate(10);
      await changeTreasuryRate.wait();
      const approveRateChange = await controller.approveRateChange();
      await approveRateChange.wait();
      const wlAddress = await controller.proposeWLUser([deployer.address]);
      await wlAddress.wait();
      const confirmWlAddress = await controller.approveWLUser();
      await confirmWlAddress.wait();
      const wlCollection = await controller.proposeWLAddresses([mockNft.address]);
      await wlCollection.wait();
      const confirmWlCollection = await controller.approveWLAddresses();
      await confirmWlCollection.wait();
      const setPoolSizeLimit = await controller.proposePoolSizeLimit(50);
      await setPoolSizeLimit.wait();
      const approvePoolSizeLimit = await controller.approvePoolSizeLimit();
      await approvePoolSizeLimit.wait();

      await abcToken.transfer(user1.address, '1000000000000000000000000000');
      await eVault.begin();

    });

    it("Proper compilation and setting", async function () {
        console.log("Contracts compiled and controller configured!");
    });

    it("Exchange", async function () {
        await nEth.exchangeEtoN(
            { value:(10e18).toString() }
        );

        expect(await nEth.balanceOf(deployer.address)).to.equal((10e18).toString());

        await nEth.exchangeNtoE(
            (10e18).toString()
        );

        expect(await nEth.balanceOf(deployer.address)).to.equal((0).toString());
    });

    it("Stake", async function () {
        await nEth.exchangeEtoN(
            { value:(10e18).toString() }
        );

        await nEth.stakeN(
            (10e18).toString(),
            86400 * 2
        );

        expect(await nEth.nLocked(deployer.address)).to.equal((10e18).toString());
    });

    it("Unstake", async function () {
        await nEth.exchangeEtoN(
            { value:(10e18).toString() }
        );

        await nEth.stakeN(
            (10e18).toString(),
            86400 * 2
        );

        await mockNft.mintNew();
        await factoryMulti.initiateMultiAssetVault(
            [mockNft.address],
            [1],
            1
        );
        
        let vaultAddress = await factoryMulti.recentlyCreatedPool(mockNft.address, 1);
        let vault = await VaultMulti.attach(vaultAddress);
        await factoryMulti.signMultiAssetVault(
            0,
            [mockNft.address],
            [1],
            mockNft.address
        );
        
        let costPerToken = 1e15;
        let totalCost = costPerToken * 3000;
        await vault.purchase(
            deployer.address,
            deployer.address,
            [0, '1', '2'],
            ['1000', '1000', '1000'],
            0,
            2,
            0,
            { value: totalCost.toString() }
        );

        await network.provider.send("evm_increaseTime", [86401 * 2]);
        
        expect(await nEth.balanceOf(deployer.address)).to.equal((0).toString());
        await nEth.unstakeN();
        expect(await nEth.nLocked(deployer.address)).to.equal((0).toString());
        expect(await nEth.balanceOf(deployer.address)).to.equal((10e18).toString());
    });
});