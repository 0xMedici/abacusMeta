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
    MockNft = await ethers.getContractFactory("MockNft");
    mockNft = await MockNft.attach('0x60F0bF9c655572E2E02FdBD262fb919C8E2BAD1A');
    let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
    
    await mockNft.approve(lend.address, '3');
    await lend.borrow(
        vaultAddress, //Pool address
        '0x60F0bF9c655572E2E02FdBD262fb919C8E2BAD1A', //NFT address
        '1', //NFT ID
        '5000000000000000', //Amount to borrow
    );

    console.log("Borrow successful!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
