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
    const token = new ethers.Contract(daiAddress, daiAbi, provider)
    console.log("Lender conntecteed.", lend.address);
    console.log("Interest owed:", await lend.getInterestPayment([0,1], '0x60F0bF9c655572E2E02FdBD262fb919C8E2BAD1A', '2'))
    await token.approve(lend.address, (await lend.getInterestPayment([0,1], '0x60F0bF9c655572E2E02FdBD262fb919C8E2BAD1A', '2')).toString());
    await lend.payInterest(
        ['1'], //List of epochs to pay interest
        '0x60F0bF9c655572E2E02FdBD262fb919C8E2BAD1A', //NFT address
        '2', //NFT ID
    );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
