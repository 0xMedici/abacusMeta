const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

    provider = ethers.getDefaultProvider();
    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Vault = await ethers.getContractFactory("Vault");
    Auction = await ethers.getContractFactory("Auction");
    auction = await Auction.attach(ADDRESSES[6]);
    MockToken = await ethers.getContractFactory("MockToken");
    token = await MockToken.attach(ADDRESSES[4]);
    let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
    let bidAmount = (1e18).toString();
    vault = await Vault.attach(vaultAddress);
    await token.approve(auction.address, bidAmount);
    await auction.newBid(
        1, //NFT id
        (1e18).toString()  //Amount to bid
    );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
