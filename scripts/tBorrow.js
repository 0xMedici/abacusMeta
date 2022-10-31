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
    mockNft = await MockNft.attach('0x6F56FaB249A38BbB871E8A4411B0bAd340b7127C');
    let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
    
    const approve = await mockNft.approve(lend.address, '3');
    await approve.wait();
    const borrow = await lend.borrow(
        vaultAddress, //Pool address
        mockNft.address, //NFT address
        '3', //NFT ID
        '5000000000000000', //Amount to borrow
    );
    await borrow.wait();
    console.log("Borrow successful!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
