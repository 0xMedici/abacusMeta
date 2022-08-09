const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();

    provider = ethers.getDefaultProvider();

    AbacusController = await ethers.getContractFactory("AbacusController");
    controller = await AbacusController.deploy(deployer.address);
    console.log("Controller:", controller.address);

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.deploy(controller.address);
    console.log("VaultFactoryMulti:", factory.address);

    AbcToken = await ethers.getContractFactory("ABCToken");
    abcToken = await AbcToken.deploy(controller.address);
    console.log("AbcToken:", abcToken.address);

    EpochVault = await ethers.getContractFactory("EpochVault");
    eVault = await EpochVault.deploy(controller.address, 86400);
    console.log("EpochVault:", eVault.address);

    CreditBonds = await ethers.getContractFactory("CreditBonds");
    bonds = await CreditBonds.deploy(controller.address, eVault.address);
    console.log("CreditBonds:", bonds.address);

    Allocator = await ethers.getContractFactory("Allocator");
    alloc = await Allocator.deploy(controller.address, eVault.address);
    console.log("Allocator:", alloc.address);

    const setAdmin = await controller.setAdmin(deployer.address);
    await setAdmin.wait();
    console.log("1");
    const setBeta = await controller.setBeta(3);
    await setBeta.wait();
    console.log("2");
    const setCreditBonds = await controller.setCreditBonds(bonds.address);
    await setCreditBonds.wait();
    console.log("3");
    const proposeFactoryAddition1 = await controller.proposeFactoryAddition(factory.address);
    await proposeFactoryAddition1.wait();
    console.log("4");
    const approveFactoryAddition1 = await controller.approveFactoryAddition();
    await approveFactoryAddition1.wait();
    console.log("5");
    const setToken = await controller.setToken(abcToken.address);
    await setToken.wait();
    console.log("6");
    const setAllocator = await controller.setAllocator(alloc.address);
    await setAllocator.wait();
    console.log("7");
    const setEpochVault = await controller.setEpochVault(eVault.address);
    await setEpochVault.wait();
    console.log("8");
    const begin = await eVault.begin();
    await begin.wait();
    console.log("9");

    const wlCollection = await controller.proposeWLAddresses([
      '0x16baf0de678e52367adc69fd067e5edd1d33e3bf',
      '0x24b5a675a7684cdbb12fa5215b7b775e291ed355',
      '0x1935899bfb630aed1fa54f2a943f0b0841724007',
      '0xb74bf94049d2c01f8805b8b15db0909168cabf46'
    ]);
    await wlCollection.wait();

    const approveWl = await controller.approveWLAddresses();
    await approveWl.wait();
    console.log("DONE");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
