const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();

    provider = ethers.getDefaultProvider();

    AbacusController = await ethers.getContractFactory("AbacusController");
    controller = await AbacusController.attach('0x00351749C1470dcd0CB9fcF9518c7900A69C1129');
    console.log("Controller:", controller.address);

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach('0xDe670cF2c63B7976C94555828005dd6486D25da9');
    console.log("Factory:", factory.address);

    Vault = await ethers.getContractFactory("Vault");
    console.log("Vault connected");

    const deployPool = await factory.initiateMultiAssetVault(
      "HelloWorld"
    );
    await deployPool.wait();
    console.log("Pool deployed");

    let poolAddress = await factory.getPoolAddress("HelloWorld");
    console.log("Spot pool address is", poolAddress);
    let spotPool = await Vault.attach(poolAddress);
    console.log("Pool attached at", poolAddress);
    let compressedNFT = await factory.getEncodedCompressedValue(
      ['0xe0abdb390ce6bead04c5f1bf82ccfd6026fbbb7d'],
      [40]
    );
    console.log("NFT compressed");
    await spotPool.includeNft(compressedNFT);
    console.log("NFT included");
    await spotPool.begin(1, 10, 10, 86400);
    console.log("Pool begun");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
