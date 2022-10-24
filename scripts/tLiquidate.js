const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

    provider = ethers.getDefaultProvider();
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach(ADDRESSES[2]);
    console.log("Lender conntecteed.", lend.address);
    await lend.adjustTicketInfo(
        '', //NFT address
        '', //NFT ID
        [''], //List of NFT address of NFTs in auction for price point violation
        [''], //List of NFT ID of NFTs in auction for price point violation
        [''], //List of closure nonce of NFTs in auction for price point violation 
    );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
