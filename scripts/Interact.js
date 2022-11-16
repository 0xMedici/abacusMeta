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
  // mockNft = await MockNft.deploy();
  //goerli
  mockNft = await MockNft.deploy();
  console.log("NFT:", mockNft.address);
  Vault = await ethers.getContractFactory("Vault");
  Closure = await ethers.getContractFactory("Closure");
  
  // MISC TASKS


  // CREATION SCRIPT
  // let nftIds = new Array();
  // let nftAddresses = new Array();
  // let nftList = new Array();
  // for(let i = 0; i < 20; i++) {
  //   const mint = await mockNft.mintNew();
  //   await mint.wait();
  //   nftIds[i] = i + 1;
  //   nftAddresses[i] = mockNft.address;
  //   nftList.push([mockNft.address, i + 1].join('/'));
  // }
  // console.log("NFTs minted");
  const initiateMultiAssetVault = await factory.initiateMultiAssetVault(
    ADDRESSES[3]
  );
  await initiateMultiAssetVault.wait();
  console.log("Pool started");
  let vaultAddress = await factory.getPoolAddress(ADDRESSES[3]);
  let maPool = await Vault.attach(vaultAddress);
  console.log("Attached to pool at", vaultAddress);
  const includeNft = await maPool.includeNft(
    await factory.getEncodedCompressedValue(nftAddresses, nftIds)
  );
  await includeNft.wait();
  nftList.forEach(async item => {
    let itemInfo = item.split('/');
    expect(await maPool.getHeldTokenExistence(itemInfo[0], itemInfo[1])).to.equal(true);
  })
  console.log("NFTs included");
  const begin = await maPool.begin(10, 100, 15, 360);
  await begin.wait();
  console.log("Start time:", (await maPool.startTime()).toString());
  console.log("Pool started");
  console.log("TIMEDIF:", Date.now() / 1000 - await maPool.startTime());
}

// main();

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

