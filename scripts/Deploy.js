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
    console.log("Factory:", factory.address);

    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.deploy(controller.address);
    console.log("Lender:", lend.address);

    MockToken = await ethers.getContractFactory("MockToken");
    mockToken = await MockToken.attach('0xa6D60724834Adc7A0D511C459A4Dcb499Aa16520');
    console.log("Token:", mockToken.address);

    VaultHelper = await ethers.getContractFactory("VaultHelper");
    helper = await VaultHelper.deploy();
    console.log("Helper:", helper.address);

    // MockNft = await ethers.getContractFactory("MockNft");
    // mockNft = await MockNft.deploy();
    // console.log("NFT:", mockNft.address);

    // for(let i = 0; i < 6; i++) {
    //   await mockNft.mintNew();
    // }
    // console.log("NFT minted");

    const setBeta = await controller.setBeta(3);
    await setBeta.wait();
    console.log("Beta set to stage 3!");
    const setFactory = await controller.setFactory(factory.address);
    await setFactory.wait();
    console.log("Factory address configured!");
    const setLender = await controller.setLender(lend.address);
    await setLender.wait();
    console.log("Lender address configured!");
    const wlAddress = await controller.addWlUser([deployer.address]);
    await wlAddress.wait();
    const mint = await mockToken.mint();
    await mint.wait();
    const mintAgain = await mockToken.mint(); 
    await mintAgain.wait();
    console.log("Token minted!");
    const transfer = await mockToken.transfer('0xE6dC2c1a17b093F4f236Fe8545aCb9D5Ad94334a', '1000000000000000000000');
    await transfer.wait();

    console.log("DONE");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
