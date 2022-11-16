const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

    provider = ethers.getDefaultProvider();
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach(ADDRESSES[2]);
    // USING DAI ADDRESS AS EXAMPLE REPLACE WITH REAL ONE WHEN USING
    const tokenAddress = "dai.tokens.ethers.eth";
    // USING DAI ABI AS EXAMPLE REPLACE WITH REAL ONE WHEN USING
    const tokenABI = [
      "function name() view returns (string)",
      "function symbol() view returns (string)",
      "function balanceOf(address) view returns (uint)",
      "function transfer(address to, uint amount)",
      "event Transfer(address indexed from, address indexed to, uint amount)"
    ];
    // CONNECT TO DAI CONTRACT OBJECT AS EXAMPLE, REPLACE WITH REAL ONE WHEN USING
    const token = new ethers.Contract(daiAddress, daiAbi, provider);
    console.log("Lender conntecteed.", lend.address);
    await token.approve(vault.address, _________ );
    await lend.repay(
        '', //NFT address
        '', //NFT ID
    );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
