const { ethers } = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();

    provider = ethers.getDefaultProvider();

    AbacusController = await ethers.getContractFactory("AbacusController");
    controller = await AbacusController.deploy(deployer.address);
    console.log("Controller:", controller.address);

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.deploy(controller.address);
    console.log("Factory:", factory.address);

    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.deploy(controller.address);
    console.log("Lender:", lend.address);

    const setFactory = await controller.setFactory(factory.address);
    await setFactory.wait();
    console.log("Factory address configured!");
    const setLender = await controller.setLender(lend.address);
    await setLender.wait();
    console.log("Lender address configured!");
    const wlAddress = await controller.addWlUser([deployer.address]);
    await wlAddress.wait();
    console.log("User added");
    const setMultisig = await controller.setMultisig('0x879427487C8849848D442333961381b5cd7dd0Aa');
    await setMultisig.wait();
    console.log("Off to the races! Enjoy the ride :)");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
