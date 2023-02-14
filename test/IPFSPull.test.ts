import erc1155Metadata from "../erc1155Metadata/ReceiptMetadata.json";
import assert from "assert";
import { artifacts, ethers } from "hardhat";
import { Receipt, ReceiptFactory } from "../typechain-types";
import { expectedUri, getEventArgs } from "./util";
import { Contract } from "ethers";

describe("IPFS pull", async function () {
  it("Pulls data from ipfs and checks it", async function () {
    this.timeout(0);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const receiptFactoryFactory = await ethers.getContractFactory(
      "ReceiptFactory"
    );
    const receiptFactoryContract =
      (await receiptFactoryFactory.deploy()) as ReceiptFactory;
    await receiptFactoryContract.deployed();

    let tx = await receiptFactoryContract.createChild([]);

    const { child } = await getEventArgs(
      tx,
      "NewChild",
      receiptFactoryContract
    );

    let childContract = new Contract(
      child,
      (await artifacts.readArtifact("Receipt")).abi
    ) as Receipt;

    let uri = await childContract.connect(alice).uri(1);

    const resp = await fetch(`https://ipfs.io/ipfs/${uri.slice(7)}`);

    const ipfsData = await resp.json().catch(console.error);

    assert(
      ipfsData.name === erc1155Metadata.name,
      `Wrong name. Expected ${erc1155Metadata.name}, got ${ipfsData.name}`
    );
    assert(
      ipfsData.decimals === erc1155Metadata.decimals,
      `Wrong decimals. Expected ${erc1155Metadata.decimals}, got ${ipfsData.decimals}`
    );
    assert(
      ipfsData.description === erc1155Metadata.description,
      `Wrong description. Expected ${erc1155Metadata.description}, got ${ipfsData.description}`
    );
  });
});
