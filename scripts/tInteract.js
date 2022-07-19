const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();

    provider = ethers.getDefaultProvider();

    AbacusController = await ethers.getContractFactory("AbacusController");
    controller = await AbacusController.attach('0x75a74d728553327eA71AC5de8Df8B15f4026afE1');
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

    // Allocator = await ethers.getContractFactory("Allocator");
    // alloc = await Allocator.attach('0x5b4d72055a8f49C12fe65A62959769f7880D47E8');
    // console.log("Allocator:", alloc.address);

    // NftEth = await ethers.getContractFactory("NftEth");
    // nEth = await NftEth.deploy(controller.address);
    // console.log("NftEth:", nEth.address);

    const wlCollection = await controller.proposeWLAddresses([
        '0x61e94ac1fad456810b1b9eb3129c44d338ea18bf'
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
