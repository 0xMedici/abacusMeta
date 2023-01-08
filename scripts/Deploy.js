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

    Auction = await ethers.getContractFactory("Auction");
    auction = await Auction.deploy(controller.address);
    console.log("Auction:", auction.address);

    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.deploy(controller.address);
    console.log("Lender:", lend.address);

    MockToken = await ethers.getContractFactory("MockToken");
    mockToken = await MockToken.deploy();
    console.log("Token:", mockToken.address);

    VaultHelper = await ethers.getContractFactory("VaultHelper");
    helper = await VaultHelper.deploy();
    console.log("Helper:", helper.address);

    Sub = await ethers.getContractFactory("Sub");
    sub = await Sub.deploy(controller.address);
    console.log("Sub:", sub.address);

    TrancheCalculator = await ethers.getContractFactory("TrancheCalculator");
    trancheCalc = await TrancheCalculator.deploy(controller.address);
    console.log("Tranche calculator:", trancheCalc.address);

    RiskCalculator = await ethers.getContractFactory("RiskPointCalculator");
    riskCalc = await RiskCalculator.deploy(controller.address);
    console.log("Risk calculator:", riskCalc.address);

    const setBeta = await controller.setBeta(3);
    setBeta.wait();
    console.log("Beta set to stage 3!");
    const setFactory = await controller.setFactory(factory.address);
    setFactory.wait();
    console.log("Factory address configured!");
    const setLender = await controller.setLender(lend.address);
    setLender.wait();
    console.log("Lender address configured!");
    const wlAddress = await controller.addWlUser([deployer.address]);
    wlAddress.wait();
    const setCalc = await controller.setCalculator(trancheCalc.address);
    setCalc.wait();
    const setRisk = await controller.setRiskCalculator(riskCalc.address);
    setRisk.wait();
    const setAuction = await controller.setAuction(auction.address);
    setAuction.wait();
    const mint = await mockToken.mint();
    mint.wait();
    const mintAgain = await mockToken.mint(); 
    mintAgain.wait();
    console.log("Token minted!");
    // const transfer = await mockToken.transfer('0xE6dC2c1a17b093F4f236Fe8545aCb9D5Ad94334a', (500000000000000e6).toString());
    // await transfer.wait();

    console.log("DONE");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
