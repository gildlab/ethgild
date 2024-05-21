import { artifacts, ethers } from "hardhat";
import * as dotenv from 'dotenv';

dotenv.config();

async function main() {
  const { PRIVATE_KEY, ARBITRUM_SEPOLIA_RPC_URL } = process.env;
  // const { PRIVATE_KEY, ETHEREUM_SEPOLIA_URL } = process.env;

  if (!PRIVATE_KEY || !ARBITRUM_SEPOLIA_RPC_URL) {
  // if (!PRIVATE_KEY || !ETHEREUM_SEPOLIA_URL) {
    throw new Error("Please set PRIVATE_KEY and ARBITRUM_RPC_URL in your .env file");
  }

  const provider = new ethers.providers.JsonRpcProvider(ARBITRUM_SEPOLIA_RPC_URL);
  // const provider = new ethers.providers.JsonRpcProvider(ETHEREUM_SEPOLIA_URL);
  // const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  const contractAbi = (await artifacts.readArtifact("OffchainAssetReceiptVault")).abi
  const contractAddress = '0xfc34d331cc7a4b461b7ded2f6835a837411d8684'; // arbitrum sepolia
  // const contractAddress = '0xAFD4239F28297F61AB8f6bE03CeD343E2389739F'; //ethereum-sepolia

  const contract = new ethers.Contract(contractAddress, contractAbi, wallet);

  try {
    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _certifiedUntil = block.timestamp + 100;

    //Grant role
    // contract.grantRole(await contract.CERTIFIER(), alice.address);

    // Replace with the function you want to test and its parameters
    const tx = await contract.certify(_certifiedUntil, blockNum, false, []);
    console.log('Transaction sent:', tx.hash);

    // Wait for the transaction to be mined
    const receipt = await tx.wait();
    console.log('Transaction mined:', receipt);
  } catch (error) {
    console.error('Error occurred:', error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});