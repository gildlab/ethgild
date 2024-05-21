import { artifacts, ethers } from "hardhat";
import * as dotenv from "dotenv";
import { getEventArgs } from "../test/util";
import { Contract } from "ethers";
import type { OffchainAssetReceiptVault } from "../typechain-types";

dotenv.config();

async function main() {
  const { PRIVATE_KEY, CONTRACT_FACTORY_ADDRESS } = process.env;

  if ( !PRIVATE_KEY ) {
    throw new Error("Please set PRIVATE_KEY and ARBITRUM_RPC_URL in your .env file");
  }

  // const provider = new ethers.providers.JsonRpcProvider(ETHEREUM_SEPOLIA_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, ethers.provider);

  const contractFactoryAbi = ( await artifacts.readArtifact("OffchainAssetReceiptVaultFactory") ).abi;

  const contractFactory = new ethers.Contract(CONTRACT_FACTORY_ADDRESS, contractFactoryAbi, wallet);

  const constructionConfig = {
    admin: wallet.address,
    vaultConfig: {
      asset: ethers.constants.AddressZero,
      name: `OffchainAssetVaul-${ new Date().getTime() }`,
      symbol: "OAV"
    }
  };

  let tx = await contractFactory.connect(wallet).createChildTyped(
    constructionConfig
  );

  const { child } = await getEventArgs(
    tx,
    "NewChild",
    contractFactory
  );

  let contract = new Contract(
    child,
    ( await artifacts.readArtifact("OffchainAssetReceiptVault") ).abi
  ) as OffchainAssetReceiptVault;

  try {
    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _certifiedUntil = block.timestamp + 100;

    // Grant role and wait for the transaction to be mined
    const grantRoleTx = await contract.connect(wallet).grantRole(await contract.connect(wallet).CERTIFIER(), wallet.address);
    await grantRoleTx.wait();

    // Call certify function
    const certifyTx = await contract.connect(wallet).certify(_certifiedUntil, blockNum, false, []);
    console.log("Transaction sent:", certifyTx.hash);

    // Wait for the transaction to be mined
    const receipt = await certifyTx.wait();
    console.log("Transaction mined:", receipt);
  } catch (error) {
    console.error("Error occurred:", error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});