const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

    provider = ethers.getDefaultProvider();
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach(ADDRESSES[2]);
    console.log("Lender conntecteed.", lend.address);
    console.log("Interest owed:", await lend.getInterestPayment([0,1], '0x60F0bF9c655572E2E02FdBD262fb919C8E2BAD1A', '2'))
    // await lend.payInterest(
    //     ['1'], //List of epochs to pay interest
    //     '0x60F0bF9c655572E2E02FdBD262fb919C8E2BAD1A', //NFT address
    //     '2', //NFT ID
    //     { value: (await lend.getInterestPayment(['1'], '0x60F0bF9c655572E2E02FdBD262fb919C8E2BAD1A', '2')).toString() }
    // );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
