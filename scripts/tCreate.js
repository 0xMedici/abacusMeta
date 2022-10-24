const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

    provider = ethers.getDefaultProvider();
    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach(ADDRESSES[2]);
    console.log("Lender conntecteed.", lend.address);
    Vault = await ethers.getContractFactory("Vault");
    Closure = await ethers.getContractFactory("Closure");

    await factory.initiateMultiAssetVault(
        ADDRESSES[3] // Pool name
    )
    let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
    let maPool = await Vault.attach(vaultAddress);
    await maPool.includeNft(
        await factory.getEncodedCompressedValue(nftAddresses, nftIds) // Compressed version of addresses and IDs
    );
    await maPool.begin(
        3, // Collateral slots
        100, // Tranche size (base value is 1000 => a value of 100 means 0.1 ETH tranche size)
        15, // Interest rate (on a scale of 10000)
        600 // Epoch length (unit is seconds)
    );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
