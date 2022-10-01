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
        Vault,
        Closure,
        AbacusController,
        controller
    
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

        MockNft = await ethers.getContractFactory("MockNft");
        mockNft = await MockNft.deploy();
        mockNft2 = await MockNft.deploy();

        Vault = await ethers.getContractFactory("Vault");
        Closure = await ethers.getContractFactory("Closure");

        const setBeta = await controller.setBeta(3);
        await setBeta.wait();
        const setFactory = await controller.setFactory(factory.address);
        await setFactory.wait();
        const wlAddress = await controller.addWlUser([deployer.address]);
        await wlAddress.wait();
    });

    it("Proper compilation and setting", async function () {
        console.log("Contracts compiled and controller configured!");
    });

    
});