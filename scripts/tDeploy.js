const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();

    provider = ethers.getDefaultProvider();

    AbacusController = await ethers.getContractFactory("AbacusController");
    controller = await AbacusController.deploy(deployer.address);
    console.log("Controller:", controller.address);

    Treasury = await ethers.getContractFactory("Treasury");
    treasury = await Treasury.deploy(deployer.address);
    console.log("Treasury:", treasury.address);

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.deploy(controller.address);
    console.log("VaultFactoryMulti:", factory.address);

    AbcToken = await ethers.getContractFactory("ABCToken");
    abcToken = await AbcToken.deploy(controller.address);
    console.log("AbcToken:", abcToken.address);

    // BribeFactory = await ethers.getContractFactory("BribeFactory");
    // bribe = await BribeFactory.deploy(controller.address);
    // console.log("BribeFactory:", bribe.address);

    EpochVault = await ethers.getContractFactory("EpochVault");
    eVault = await EpochVault.deploy(controller.address, 86400);
    console.log("EpochVault:", eVault.address);

    CreditBonds = await ethers.getContractFactory("CreditBonds");
    bonds = await CreditBonds.deploy(controller.address, eVault.address);
    console.log("CreditBonds:", bonds.address);

    Allocator = await ethers.getContractFactory("Allocator");
    alloc = await Allocator.deploy(controller.address, eVault.address);
    console.log("Allocator:", alloc.address);

    NftEth = await ethers.getContractFactory("NftEth");
    nEth = await NftEth.deploy(controller.address);
    console.log("NftEth:", nEth.address);

    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.deploy(controller.address, nEth.address, eVault.address);
    console.log("Lend:", lend.address);

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
    const sendABC1 = await abcToken.transfer('0x15441e298a22BA6d4E95B77a3F511e76dbAde87f', '1000000000000000000000000000');
    await sendABC1.wait();
    console.log("9");
    const sendABC2 = await abcToken.transfer('0xd365Ae104DA3E86EA36f268050D6e5212a42e360', '1000000000000000000000000000');
    await sendABC2.wait();
    console.log("10");
    const begin = await eVault.begin();
    await begin.wait();
    console.log("11");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
