import erc1155Metadata from "../erc1155Metadata/ReceiptMetadata.json";
import assert from "assert";

describe("IPFS pull", async function () {
  it("Pulls data from ipfs and checks it", async function () {
    const resp = await fetch(
      "https://ipfs.io/ipfs/bafkreih7cvpjocgrk7mgdel2hvjpquc26j4jo2jkez5y2qdaojfil7vley"
    );
    const ipfsData = await resp.json();

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
