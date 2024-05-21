import { artifacts, ethers } from "hardhat";
import * as dotenv from "dotenv";
import { getEventArgs } from "../test/util";
import { Contract } from "ethers";
import type { OffchainAssetReceiptVault } from "../typechain-types";

dotenv.config();

async function main() {
  const { PRIVATE_KEY, ARBITRUM_SEPOLIA_RPC_URL } = process.env;

  if ( !PRIVATE_KEY || !ARBITRUM_SEPOLIA_RPC_URL ) {
    throw new Error("Please set PRIVATE_KEY and ARBITRUM_RPC_URL in your .env file");
  }

  const provider = new ethers.providers.JsonRpcProvider(ARBITRUM_SEPOLIA_RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  const contractFactoryAbi = ( await artifacts.readArtifact("OffchainAssetReceiptVaultFactory") ).abi;
  //factory contract address on arbitrum sepolia
  const contractFactoryAddress = "0xf1A14e96977E8dE295Ba9612691D127B157d1371";

  const contractFactory = new ethers.Contract(contractFactoryAddress, contractFactoryAbi, wallet);

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

    //Grant role
    await contract.connect(wallet).grantRole(await contract.connect(wallet).CERTIFIER(), wallet.address);

    //Call certify function
    const tx = await contract.connect(wallet).certify(_certifiedUntil, blockNum, false, []);
    console.log("Transaction sent:", tx.hash);

    // Wait for the transaction to be mined
    const receipt = await tx.wait();
    console.log("Transaction mined:", receipt);
  } catch ( error ) {
    console.error("Error occurred:", error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});