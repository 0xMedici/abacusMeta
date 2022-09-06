const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();

    provider = ethers.getDefaultProvider();

    AbacusController = await ethers.getContractFactory("AbacusController");
    controller = await AbacusController.attach('0x04D7F5193cEaC1F99AF84bb5EE4F4eD00CA46F42');
    console.log("Controller:", controller.address);

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach('0x532276cD34fcb5Cfe2C6A5D30E2b0a3Ef3983429');
    console.log("Factory:", factory.address);

    // AbcToken = await ethers.getContractFactory("ABCToken");
    // abcToken = await AbcToken.deploy(controller.address);
    // console.log("AbcToken:", abcToken.address);

    // EpochVault = await ethers.getContractFactory("EpochVault");
    // eVault = await EpochVault.deploy(controller.address, 86400);
    // console.log("EpochVault:", eVault.address);

    // CreditBonds = await ethers.getContractFactory("CreditBonds");
    // bonds = await CreditBonds.deploy(controller.address, eVault.address);
    // console.log("CreditBonds:", bonds.address);

    // Allocator = await ethers.getContractFactory("Allocator");
    // alloc = await Allocator.attach('0x5b4d72055a8f49C12fe65A62959769f7880D47E8');
    // console.log("Allocator:", alloc.address);

    Vault = await ethers.getContractFactory("Vault");
    console.log("Vault connected");

    const create = await factory.initiateMultiAssetVault(
      "test1"
    );
    await create.wait();
    console.log("Vault created for test1");
    let vaultAddress = await factory.vaultNames("test1", 0);
    let maPool = await Vault.attach(vaultAddress);
    const include = await maPool.includeNft(
      await factory.encodeCompressedValue(['0x7a9a5bb50a6191352b9e0667ee25f30346afc532'], [1])
    );
    await include.wait();
    console.log("NFT included");
    const begin = await maPool.begin(1, 100);
    await begin.wait();
    console.log("Pool begun");
    console.log(await maPool.getNonce());
    console.log(await controller.nftVaultSigned('0x7a9a5bb50a6191352b9e0667ee25f30346afc532', 1));
    const sign = await factory.signMultiAssetVault(
      (await maPool.getNonce()).toString(),
      ['0x7a9a5bb50a6191352b9e0667ee25f30346afc532'],
      [1]
    );
    await sign.wait();
    console.log("Pool signed");
    console.log(await controller.nftVaultSigned('0x7a9a5bb50a6191352b9e0667ee25f30346afc532', 1));
    console.log("Emissions started count:", await maPool.emissionStartedCount(0));

    // const wlCollection = await controller.proposeWLAddresses([
    //     '0x61e94ac1fad456810b1b9eb3129c44d338ea18bf'
    // ]);
    // await wlCollection.wait();

    // const approveWl = await controller.approveWLAddresses();
    // await approveWl.wait();
    // console.log("DONE");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
