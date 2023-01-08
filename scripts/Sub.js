const { ethers } = require("hardhat");
const { ADDRESSES, TIMEDIF } = require('./Addresses.js');
const { request, gql } = require('graphql-request');

async function main() {

    const [deployer] = await ethers.getSigners();
    provider = ethers.getDefaultProvider();

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Sub = await ethers.getContractFactory("Sub");
    sub = await Sub.attach(ADDRESSES[5]);
    console.log("Sub connected.", sub.address);
    MockToken = await ethers.getContractFactory("MockToken");
    token = await MockToken.attach('0x3397C0586FA100A9678f3135b8407a584E0899Ac');
    Vault = await ethers.getContractFactory("Vault");
    // let vaultAddress = await factory.getPoolAddress("ICUP");
    // vault = await Vault.attach(vaultAddress);

    // DEPOSIT GAS
    console.log("Depositing gas...");
    const depositGas = await sub.depositGas(
        { value: (1e17).toString() } // amount to deposit
    );
    await depositGas.wait();
    console.log("Done!");

    // WITHDRAW GAS
    // const withdrawGas = await sub.withdrawGas(
    //     ().toString() // amount to withdraw
    // );
    // await withdrawGas.wait();

    // DEPOSIT TOKENS
    console.log("Approving...");
    const approve = await token.approve(sub.address, (1e20).toString());
    await approve.wait();
    console.log("Done!");
    console.log("Depositing...");
    const depositTokens = await sub.depositTokens(
        [token.address], // addresses
        [(1e20).toString()] // amounts
    );
    await depositTokens.wait();
    console.log("Done!");

    // WITHDRAW TOKENS
    // const withdrawTokens = await sub.withdrawTokens(
    //     [], // addresses
    //     [] // amounts
    // );
    // await withdrawTokens.wait();

    // OPEN SUB
    const createOrder = await sub.createOrder(
        '0xaf5ec94c7867691a5b66f1a2f59f4018063835ee', // pool address
        [6], // ticket
        [100], // ticket amount
        300 * 2, // lock time
        (await sub.getCompressedGasValues(
          (1592353126397956 * 10).toString(), 
          (1092353126397956 * 10).toString(),
          (1092353126397956 * 10).toString()
        )).toString(), // gas per call
        300 // delay time
    );
    await createOrder.wait();

    // EXECUTE SUB PURCHASE
    // const executePurchase = await sub.executePurchaseOrder(
    //     deployer.address, // subsidy recipient 
    //     0, // order nonce,
    //     [0], // ticket
    //     [100], // ticket amount
    // );
    // await executePurchase.wait();

    // EXECUTE SUB ADJUSTMENT
    // const executeAdjustment = await sub.executeAdjustmentOrder(
    //     deployer.address, // subsidy recipient 
    //     0, // order nonce
    //     0, // position nonce
    //     1 // auction nonce
    // );
    // await executeAdjustment.wait();

    // EXECUTE SUB SALE
    // const executeSale = await sub.executeSellOrder(
    //     deployer.address, // subsidy recipient 
    //     0, // order nonce
    //     0 // position nonce
    // );
    // await executeSale.wait();

    // CANCEL SUB
    // const cancelOrder = await sub.cancelOrder(
    //   4 // order nonce
    // );
    // cancelOrder.wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
