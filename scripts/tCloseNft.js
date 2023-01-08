const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

    provider = ethers.getDefaultProvider();
    Controller = await ethers.getContractFactory("AbacusController");
    controller = await Controller.attach(ADDRESSES[0]);
    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Vault = await ethers.getContractFactory("Vault");
    MockNft = await ethers.getContractFactory("MockNft");
    mockNft = await MockNft.attach('0x70e0bA845a1A0F2DA3359C97E0285013525FFC49');
    Auction = await ethers.getContractFactory("Auction");
    auction = await Auction.attach(ADDRESSES[6]);
    MockToken = await ethers.getContractFactory("MockToken");
    token = await MockToken.attach(ADDRESSES[4]);

    let vaultAddress = await factory.getPoolAddress('ICUP');
    console.log(vaultAddress);
    vault = await Vault.attach(vaultAddress);
    console.log(await controller.accreditedAddresses(vaultAddress));
    console.log(await vault.getHeldTokenExistence('0x70e0bA845a1A0F2DA3359C97E0285013525FFC49', 1));
    console.log(await vault.getTotalAvailableFunds(1));
    console.log(await vault.getPayoutPerReservation(1));
    await mockNft.approve(vault.address, 1);
    console.log(await controller.auction());
    console.log(await auction.nonce());
    console.log(await token.balanceOf(vault.address));
    await vault.closeNft(
        '0x70e0bA845a1A0F2DA3359C97E0285013525FFC49', //NFT address
        1, //NFT ID
    );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
