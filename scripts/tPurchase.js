const { ethers } = require("hardhat");
const { ADDRESSES, TIMEDIF } = require('./Addresses.js');

  async function main() {
    
    [deployer] = await ethers.getSigners();
    provider = ethers.getDefaultProvider();
    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach(ADDRESSES[2]);
    console.log("Lender conntecteed.", lend.address);
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
    vault = await Vault.attach(vaultAddress);
    let costPerToken = 1e15;
    let totalCost = costPerToken * 10;
    let tickets = ['1'];
    let amounts = ['10'];
    let currentEpoch = Math.floor((Date.now() / 1000 + parseInt(TIMEDIF) - await vault.startTime()) / await vault.epochLength());
    console.log("Current epoch:", currentEpoch.toString());
    let endEpoch = currentEpoch + 3;
    console.log("End epoch:", endEpoch.toString());
    console.log(`Initiating purchase from ${vault.address}...`);
    let i = tickets.length;
    for(let i = 0; i < tickets.length; i++) {
      console.log(`Current ticket count in ${tickets[i]}: ${amounts[i]}`);
    }
    await token.approve(vault.address, totalCost.toString());
    const txHash = await vault.purchase(
        deployer.address, //Buyer address
        tickets, //Desired appraisal tranches
        amounts, //Amount per tranche
        currentEpoch, //Start epoch
        endEpoch, //Unlock epoch 
    )
    // .then((tx) => {
    //   hash = tx.hash;
    //   console.log(tx.hash);
    // }).catch((error) => {
    //   console.log(error);
    // });

    await txHash.wait()
      .then((result) => {
        console.log(txHash.hash)
      })
      .catch((error) => {
        console.log(error.reason)
      });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
