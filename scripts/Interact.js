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
  mockNft = await MockNft.deploy();
  console.log("NFT:", mockNft.address);
  MockToken = await ethers.getContractFactory("MockToken");
  token = await MockToken.attach(ADDRESSES[4]);
  Vault = await ethers.getContractFactory("Vault");
  Position = await ethers.getContractFactory("Position");  

  // CREATION SCRIPT
  let nftIds = new Array();
  let nftAddresses = new Array();
  let nftList = new Array();
  for(let i = 0; i < 20; i++) {
    const mint = await mockNft.mintNew();
    await mint.wait();
    nftIds[i] = i + 1;
    nftAddresses[i] = mockNft.address;
    nftList.push([mockNft.address, i + 1].join('/'));
    console.log(`Minted ${i + 1}`);
  }
  const createVault = await factory.initiateMultiAssetVault(
    "HelloWorld1"
  );
  createVault.wait();
  let vaultAddress = await factory.getPoolAddress("HelloWorld1");
  let maPool = await Vault.attach(vaultAddress);
  const includeNft = await maPool.includeNft(
      nftAddresses, 
      nftIds
  );
  includeNft.wait();
  const setEquations = await maPool.setEquations(
      [13, 5, 0, 0, 7, 9, 20, 4, 9, 0, 1, 110, 8, 8],
      [22, 3, 0, 12, 4, 0, 9, 10, 1, 10, 8, 3, 19]
  );
  setEquations.wait();
  await maPool.begin(3, 100, 86400, token.address, 100, 10, 86400);
  let manager = await Position.attach((await maPool.positionManager()).toString());

  // GOERLI FORK
  // BASH COMMAND TO FORK: npx hardhat node --fork 'https://goerli.infura.io/v3/b2d15a1424b74f158a3ccf9f78f2e8e0'
  // const impersonatedSigner = await ethers.getImpersonatedSigner("0xE6dC2c1a17b093F4f236Fe8545aCb9D5Ad94334a");
  // let loan = await lend.loans('0x8971718bca2b7fc86649b84601b17b634ecbdf19', '191');
  // console.log("Account of seller:", impersonatedSigner.address);
  // NFT = await ethers.getContractFactory("ERC721");
  // nft = await NFT.attach('0x8971718bca2b7fc86649b84601b17b634ecbdf19');
  // let vaultAddress = await factory.getPoolAddress("TestVault");
  // let vault = await Vault.attach(vaultAddress);

  // MINT SCRIPT
  // console.log("Minting...");
  // let tokenForMinting = await MockToken.attach('0x3397c0586fa100a9678f3135b8407a584e0899ac');
  // await tokenForMinting.mint();
  // await tokenForMinting.mint();
  // await tokenForMinting.mint();
  // await tokenForMinting.mint();
  // console.log("Transfer 1...");
  // const transfer = await tokenForMinting.transfer('0x8B129ad581b4f76885992869e75C2AfA222dA9eF', (500000000000000e6).toString());
  // transfer.wait();
  // console.log("Transfer 2...");
  // const transfer1 = await tokenForMinting.transfer('0x8B129ad581b4f76885992869e75C2AfA222dA9eF', (500000000000000e6).toString());
  // transfer1.wait();
  // console.log("Transfer 3...");
  // const transfer2 = await tokenForMinting.transfer('0x8B129ad581b4f76885992869e75C2AfA222dA9eF', (500000000000000e6).toString());
  // transfer2.wait();
  // console.log("Transfer 4...");
  // const transfer3 = await tokenForMinting.transfer('0x8B129ad581b4f76885992869e75C2AfA222dA9eF', (500000000000000e6).toString());
  // transfer3.wait();
  // console.log("Minted and transferred");

  // WHITELIST USER
  // console.log("Whitelisting...");
  // await controller.addWlUser(
  //   [
  //     '0x27D4E6Fe4F5acA5EcCf4a1C7694AcE7451060BfC',
  //     '0x3491b165B4D38d70D2C66a560248E729066d4cB8',
  //     '0xa4895ca35C391dd427c724cD84D5BC3EB420Bf16',
  //     '0x72fC9b80CF03C71Ecc5637123d73428088bD0f08',
  //     '0x771388495F34d21C5574FeFc04cd1D5811E00aDa',
  //     '0x246fdee8bCd65dB79fC1F4A1104f041fa6C94c84',
  //     '0xeAbed8538923d8B8E0616938F8Dc657F3CDF74c6',
  //     '0xD0ba237c3dEb33DB6df9508975474D3d48C31d3b',
  //     '0x714D7baF5067855EBa892296B6C6D94a09857010',
  //     '0xBE967Fe18A7c8AEe4b858bBA75Ca0DF2D834Ef7D',
  //     '0xcCBF5d0A96ca77da1D21438eB9c06e485e6723C2',
  //     '0x79d899379844D35A1A1F5D51D3185dd821f44Dc1',
  //     '0x4d477F1aabcFc2FC3FC9b802E861C013E0123AD9',
  //     '0x9DB9a11Bd146e8f39DC61246c357aaa10f2f2170',
  //     '0x5EA458DeFEb9DeDAD6F16DD9244D240B44ba9C79',
  //     '0x255Be6D417D25d553414fb9608EF6303af9EB771',
  //     '0x8F0Dc000D3D4cEc7E8233cfEA94c5324126EB5aB'
  //   ]
  // );
  // console.log(await controller.userWhitelist('0x27D4E6Fe4F5acA5EcCf4a1C7694AcE7451060BfC'));
  // console.log(await controller.userWhitelist('0x3491b165B4D38d70D2C66a560248E729066d4cB8'));
  // console.log(await controller.userWhitelist('0xa4895ca35C391dd427c724cD84D5BC3EB420Bf16'));
  // console.log(await controller.userWhitelist('0x72fC9b80CF03C71Ecc5637123d73428088bD0f08'));
  // console.log(await controller.userWhitelist('0x771388495F34d21C5574FeFc04cd1D5811E00aDa'));
  // console.log(await controller.userWhitelist('0x246fdee8bCd65dB79fC1F4A1104f041fa6C94c84'));
  // console.log(await controller.userWhitelist('0xeAbed8538923d8B8E0616938F8Dc657F3CDF74c6'));
  // console.log(await controller.userWhitelist('0xD0ba237c3dEb33DB6df9508975474D3d48C31d3b'));
  // console.log(await controller.userWhitelist('0x714D7baF5067855EBa892296B6C6D94a09857010'));
  // console.log(await controller.userWhitelist('0xBE967Fe18A7c8AEe4b858bBA75Ca0DF2D834Ef7D'));
  // console.log(await controller.userWhitelist('0xcCBF5d0A96ca77da1D21438eB9c06e485e6723C2'));
  // console.log(await controller.userWhitelist('0x79d899379844D35A1A1F5D51D3185dd821f44Dc1'));
  // console.log(await controller.userWhitelist('0x4d477F1aabcFc2FC3FC9b802E861C013E0123AD9'));
  // console.log(await controller.userWhitelist('0x9DB9a11Bd146e8f39DC61246c357aaa10f2f2170'));
  // console.log(await controller.userWhitelist('0x5EA458DeFEb9DeDAD6F16DD9244D240B44ba9C79'));
  // console.log(await controller.userWhitelist('0x255Be6D417D25d553414fb9608EF6303af9EB771'));
  // console.log(await controller.userWhitelist('0x8F0Dc000D3D4cEc7E8233cfEA94c5324126EB5aB'));
  // console.log("Done!");

  // SELL SCRIPT
  // let position0 = await vault.traderProfile(
  //   impersonatedSigner.address,
  //   0
  // );

  // let position1 = await vault.traderProfile(
  //   impersonatedSigner.address,
  //   1
  // );

  // console.log("CURRENT POSITION FOR NONCE 0");
  // console.log(position0);
  // console.log("CURRENT POSITION FOR NONCE 1");
  // console.log(position1);

  // console.log("SELLING NONCE 0...");
  // await vault.connect(impersonatedSigner).sell(
  //   0
  // );
  // console.log("SOLD!");

  // console.log("SELLING NONCE 1...");
  // await vault.connect(impersonatedSigner).sell(
  //   1
  // );
  // console.log("SOLD!");

  // LIQUIDATION SCRIPT
  // console.log("Current owner address:", (await nft.ownerOf(191)).toString());
  // console.log("Liquidating...");
  // const approve = await token.approve(lend.address, parseInt(loan[4]));
  // approve.wait();
  // console.log("Loan amount:", parseInt(loan[4]));
  // console.log("Approved amount:", parseInt(await token.allowance(deployer.address, lend.address)));
  // const liquidate = await lend.liquidate(
  //   '0x8971718bca2b7fc86649b84601b17b634ecbdf19',
  //   '191'
  // );
  // liquidate.wait();
  // console.log("Liquidated!");
  // console.log("Current owner address:", (await nft.ownerOf(191)).toString());
  // let maPool = await Vault.attach((loan.pool).toString());
  // console.log("Closing pool:", maPool.address);
  // console.log("Closure contract:", (await maPool.closePoolContract()).toString());
  // LIQUIDATION TEST DONE HERE 
}

// main();

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

