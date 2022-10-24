const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { expect } = require("chai");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

  const [deployer] = await ethers.getSigners();

  provider = ethers.getDefaultProvider();
  AbacusController = await ethers.getContractFactory("AbacusController");
  controller = await AbacusController.attach(ADDRESSES[0]);
  console.log("Controller:", controller.address);
  Factory = await ethers.getContractFactory("Factory");
  factory = await Factory.attach(ADDRESSES[1]);
  console.log("Factory:", factory.address);
  Lend = await ethers.getContractFactory("Lend");
  lend = await Lend.attach(ADDRESSES[2]);
  console.log("Lend:", lend.address);
  MockNft = await ethers.getContractFactory("MockNft");
  //localhost
  // mockNft = await MockNft.attach('');
  //goerli
  mockNft = await MockNft.attach('0x64C73A6eB9c184DF3FCA8e2c0B249E8343C43108');
  Vault = await ethers.getContractFactory("Vault");
  Closure = await ethers.getContractFactory("Closure");

  expect(await controller.lender() === lend.address).to.equal(true);
  
  let nftIds = new Array();
  let nftAddresses = new Array();
  for(let i = 0; i < 6; i++) {
    nftIds[i] = i + 1;
    nftAddresses[i] = mockNft.address;
  }
  await factory.initiateMultiAssetVault(
    ADDRESSES[3]
  );
  let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
  let maPool = await Vault.attach(vaultAddress);
  await maPool.includeNft(
    await factory.getEncodedCompressedValue(nftAddresses, nftIds)
  );
  await maPool.begin(3, 100, 15, 600);
  let costPerToken = 1e15;
  let totalCost = costPerToken * 30;
  await maPool.purchase(
      deployer.address,
      [
          '0'
      ],
      [
          '30'
      ],
      0,
      2,
      { value: totalCost.toString() }
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
