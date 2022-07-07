const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();

    provider = ethers.getDefaultProvider();

    AbacusController = await ethers.getContractFactory("AbacusController");
    controller = await AbacusController.attach('0x40f9201c33F1974AAFd2Ad850FD071E2093b55a4');
    console.log("Controller:", controller.address);

    // Treasury = await ethers.getContractFactory("Treasury");
    // treasury = await Treasury.deploy(deployer.address);
    // console.log("Treasury:", treasury.address);

    // VaultFactoryMulti = await ethers.getContractFactory("VaultFactoryMulti");
    // factoryMulti = await VaultFactoryMulti.deploy(controller.address);
    // console.log("VaultFactoryMulti:", factoryMulti.address);

    // AbcToken = await ethers.getContractFactory("ABCToken");
    // abcToken = await AbcToken.deploy(controller.address);
    // console.log("AbcToken:", abcToken.address);

    // BribeFactory = await ethers.getContractFactory("BribeFactory");
    // bribe = await BribeFactory.deploy(controller.address);
    // console.log("BribeFactory:", bribe.address);

    // EpochVault = await ethers.getContractFactory("EpochVault");
    // eVault = await EpochVault.deploy(controller.address, 86400);
    // console.log("EpochVault:", eVault.address);

    // CreditBonds = await ethers.getContractFactory("CreditBonds");
    // bonds = await CreditBonds.deploy(controller.address, eVault.address);
    // console.log("CreditBonds:", bonds.address);

    Allocator = await ethers.getContractFactory("Allocator");
    alloc = await Allocator.attach('0x5b4d72055a8f49C12fe65A62959769f7880D47E8');
    console.log("Allocator:", alloc.address);

    // NftEth = await ethers.getContractFactory("NftEth");
    // nEth = await NftEth.deploy(controller.address);
    // console.log("NftEth:", nEth.address);

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
