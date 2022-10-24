const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

  async function main() {
    
    [deployer] = await ethers.getSigners();
    provider = ethers.getDefaultProvider();
    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach(ADDRESSES[2]);
    console.log("Lender conntecteed.", lend.address);
    Vault = await ethers.getContractFactory("Vault");
    Closure = await ethers.getContractFactory("Closure");

    let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
    vault = await Vault.attach(vaultAddress);
    let costPerToken = 1e15;
    let totalCost = costPerToken * 30;
    await vault.purchase(
        deployer.address, //Buyer address
        ['0'], //Desired appraisal tranches
        ['30'], //Amount per tranche
        '0', //Start epoch
        '2', //Unlock epoch 
        { value: totalCost.toString() }
    );
    console.log("Purchase successful!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
