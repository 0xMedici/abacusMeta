const { ethers } = require("hardhat");
const { ADDRESSES, TIMEDIF } = require('./Addresses.js');

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
    mockNft = await MockNft.attach('0x388f18fD358e8E581a76A0dA5A468A15c4Ec2c5c');
    let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
    
    let borrowId = 8;
    let borrowAmount = 1e13*95;
    console.log(`Initiating approval for lending custody transfer of ${mockNft.address} ${borrowId}...`);
    const approve = await mockNft.approve(lend.address, borrowId);
    await approve.wait();
    console.log(`Initiating borrow from ${vaultAddress} for amount of ${borrowAmount}...`);
    const borrow = await lend.borrow(
        vaultAddress, //Pool address
        mockNft.address, //NFT address
        borrowId, //NFT ID
        borrowAmount, //Amount to borrow
    );
    const txHash = await borrow.wait();
    console.log(txHash.events[2].eventSignature);
    console.log("Borrow successful!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// NFT / Pool
// 0xa402B0698c52A0C25D20F0ee9E8BB76bD1b0F882 / 0x26c4A24f45A2bB5466A0137BC68982018159191c
// 0x388f18fD358e8E581a76A0dA5A468A15c4Ec2c5c / 0x36a6728806737a8B8fc439afC06de9088D0D8fb3