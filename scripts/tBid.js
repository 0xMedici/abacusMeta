const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

    provider = ethers.getDefaultProvider();
    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Vault = await ethers.getContractFactory("Vault");
    Closure = await ethers.getContractFactory("Closure");
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
    const token = new ethers.Contract(daiAddress, daiAbi, provider)
    let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
    let bidAmount = 1;
    vault = await Vault.attach(vaultAddress);
    let closureAddress = await vault.closePoolContract();
    closure = await Closure.attach(closureAddress);
    await token.approve(closure.address, bidAmount);
    await closure.newBid(
        '', //NFT address
        '', //NFT id
        bidAmount  //Amount to bid
    );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
