const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

    provider = ethers.getDefaultProvider();
    [deployer] = await ethers.getSigners();
    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Vault = await ethers.getContractFactory("Vault");

    let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
    vault = await Vault.attach(vaultAddress);
    console.log(`Initiating sale from ${vault.address}...`);
    const sell = await vault.sell(
        deployer.address, //User address
        0, //Position nonce
    );
    const txHash = await sell.wait();
    console.log(txHash.logs[0].blockNumber);
    console.log("Sale successful");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
