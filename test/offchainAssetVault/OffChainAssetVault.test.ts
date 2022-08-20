import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { OffchainAssetVaultFactory, ReadWriteTier } from "../../typechain";
import {
  getEventArgs,
  expectedName,
  expectedSymbol,
  expectedUri,
  ADDRESS_ZERO,
  assertError,
  fixedPointMul,
  ONE,
  fixedPointDiv,
  deployERC20PriceOracleVault,
} from "../util";

import {
  SetERC20TierEvent,
  OffchainAssetVaultConstructionEvent,
  CertifyEvent,
  SnapshotEvent,
  ConfiscateSharesEvent,
  ConfiscateReceiptEvent,
} from "../../typechain/OffchainAssetVault";
import { deployOffChainAssetVault } from "./deployOffchainAssetVault";
import { DepositWithReceiptEvent } from "../../typechain/ReceiptVault";

chai.use(solidity);
const { assert } = chai;

let TierV2TestContract: ReadWriteTier;

describe("OffChainAssetVault", async function () {
  beforeEach(async () => {
    const TierV2Test = await ethers.getContractFactory("ReadWriteTier");
    TierV2TestContract = (await TierV2Test.deploy()) as ReadWriteTier;
    await TierV2TestContract.deployed();
  });

  it("Constructs well", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const { caller, config } = (await getEventArgs(
      await vault.deployTransaction,
      "OffchainAssetVaultConstruction",
      vault
    )) as OffchainAssetVaultConstructionEvent["args"];

    assert(
      config.receiptVaultConfig.name === expectedName,
      `wrong name expected ${expectedName} got ${config.receiptVaultConfig.name}`
    );
    assert(
      config.receiptVaultConfig.asset === ADDRESS_ZERO,
      `wrong asset expected ${ADDRESS_ZERO} got ${config.receiptVaultConfig.asset}`
    );
    assert(
      config.receiptVaultConfig.uri === expectedUri,
      `wrong uri expected ${expectedUri} got ${config.receiptVaultConfig.uri}`
    );

    assert(
      config.receiptVaultConfig.symbol === expectedSymbol,
      `wrong symbol expected ${expectedSymbol} got ${config.receiptVaultConfig.symbol}`
    );

    assert(
      caller === alice.address,
      `wrong caller expected ${alice.address} got ${caller}`
    );
  });
  it("Checks asset is zero", async function () {
    const [vault] = await deployOffChainAssetVault();

    const { config } = (await getEventArgs(
      await vault.deployTransaction,
      "OffchainAssetVaultConstruction",
      vault
    )) as OffchainAssetVaultConstructionEvent["args"];

    assert(config.receiptVaultConfig.asset === ADDRESS_ZERO, `NONZERO_ASSET`);
  });
  it("Checks SetERC20Tier role", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const minTier = ethers.BigNumber.from(10);

    await assertError(
      async () =>
        await vault.setERC20Tier(TierV2TestContract.address, minTier, []),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault.ERC20TIERER()}`,
      "Failed to set erc20tier"
    );
  });
  it("Checks SetERC20Tier event is emitted", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault.grantRole(await vault.ERC20TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { caller, tier, minimumTier } = (await getEventArgs(
      await vault.setERC20Tier(TierV2TestContract.address, minTier, []),
      "SetERC20Tier",
      vault
    )) as SetERC20TierEvent["args"];

    assert(
      caller === alice.address,
      `wrong caller expected ${alice.address} got ${caller}`
    );
    assert(
      tier === TierV2TestContract.address,
      `wrong tier expected ${TierV2TestContract.address} got ${tier}`
    );
    assert(
      minimumTier.eq(minTier),
      `wrong minimumTier expected ${minTier} got ${minimumTier}`
    );
  });
  it("Checks setERC1155Tier role", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const minTier = ethers.BigNumber.from(10);

    await assertError(
      async () =>
        await vault.setERC1155Tier(TierV2TestContract.address, minTier, []),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault.ERC1155TIERER()}`,
      "Failed to set erc1155tier"
    );
  });
  it("Checks setERC1155Tier event is emitted", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault.grantRole(await vault.ERC1155TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(100);

    const { caller, tier, minimumTier } = (await getEventArgs(
      await vault.setERC1155Tier(TierV2TestContract.address, minTier, []),
      "SetERC1155Tier",
      vault
    )) as SetERC20TierEvent["args"];

    assert(
      caller === alice.address,
      `wrong caller expected ${alice.address} got ${caller}`
    );
    assert(
      tier === TierV2TestContract.address,
      `wrong tier expected ${TierV2TestContract.address} got ${tier}`
    );
    assert(
      minimumTier.eq(minTier),
      `wrong minimumTier expected ${minTier} got ${minimumTier}`
    );
  });
  it("Checks totalAssets", async function () {
    const signers = await ethers.getSigners();
    const [vault] = await deployOffChainAssetVault();

    const [receiptVault, asset, priceOracle] =
      await deployERC20PriceOracleVault();

    const alice = signers[0];
    const bob = signers[1];

    const shareRatio = await priceOracle.price();
    const aliceAssets = ethers.BigNumber.from(1000);

    await asset.transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault.grantRole(await vault.DEPOSITOR(), alice.address);

    await vault["deposit(uint256,address,uint256,bytes)"](
      aliceAssets,
      bob.address,
      shareRatio,
      []
    );

    const totalSupply = await vault.totalSupply();
    const totalAssets = await vault.totalAssets();

    assert(
      totalSupply.eq(totalAssets),
      `Wrong total assets. Expected ${totalSupply} got ${totalAssets}`
    );
  });
  it("PreviewDeposit sets correct shares", async function () {
    const [vault] = await deployOffChainAssetVault();
    const assets = ethers.BigNumber.from(100);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const hasRoleDepositor = await vault.hasRole(
      await vault.DEPOSITOR(),
      alice.address
    );

    //Alice does not have role of depositor, so it should throw an error unless role is granted
    assert(
      !hasRoleDepositor,
      `AccessControl: account ${alice.address.toLowerCase()} is missing role DEPOSITOR`
    );

    //grant depositor role to alice
    await vault.grantRole(await vault.DEPOSITOR(), alice.address);

    const shares = await vault.previewDeposit(assets);

    assert(
      shares.eq(assets),
      `Wrong shares: expected ${assets} got ${shares} `
    );
  });
  it("PreviewMint sets 0 if not DEPOSITOR", async function () {
    const [vault] = await deployOffChainAssetVault();
    const shares = ethers.BigNumber.from(100);

    const assets = await vault.previewMint(shares);
    const expectedAssets = ethers.BigNumber.from(0);

    assert(
      assets.eq(expectedAssets),
      `Wrong assets: expected ${expectedAssets} got ${assets} `
    );
  });
  it("PreviewMint sets correct assets", async function () {
    const [vault] = await deployOffChainAssetVault();
    const shares = ethers.BigNumber.from(100);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    //grant depositor role to alice
    await vault.grantRole(await vault.DEPOSITOR(), alice.address);

    const assets = await vault.previewMint(shares);
    const expectedAssets = fixedPointDiv(shares, ONE).add(1);

    assert(
      assets.eq(expectedAssets),
      `Wrong assets: expected ${expectedAssets} got ${assets} `
    );
  });
  it("PreviewWithdraw sets 0 shares if no withdrawer role", async function () {
    const [vault] = await deployOffChainAssetVault();
    const assets = ethers.BigNumber.from(100);

    const [receiptVault, asset, priceOracle] =
      await deployERC20PriceOracleVault();

    const id = await priceOracle.price();

    const expectedShares = ethers.BigNumber.from(0);

    const shares = await vault["previewWithdraw(uint256,uint256)"](assets, id);

    assert(
      shares.eq(expectedShares),
      `Wrong shares: expected ${expectedShares} got ${shares} `
    );
  });
  it("PreviewWithdraw sets correct shares", async function () {
    const [vault] = await deployOffChainAssetVault();
    const assets = ethers.BigNumber.from(100);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    //assets are always deposited 1:1 with shares
    const id = ONE;

    //grant withdrawer role to alice
    await vault.grantRole(await vault.WITHDRAWER(), alice.address);

    const expectedShares = fixedPointMul(assets, id).add(1);

    const shares = await vault["previewWithdraw(uint256,uint256)"](assets, id);

    assert(
      shares.eq(expectedShares),
      `Wrong shares: expected ${expectedShares} got ${shares} `
    );
  });
  it("PreviewRedeem sets correct assets", async function () {
    const [vault] = await deployOffChainAssetVault();
    const shares = ethers.BigNumber.from(100);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [receiptVault, asset, priceOracle] =
      await deployERC20PriceOracleVault();

    const id = await priceOracle.price();

    const hasRoleDepositor = await vault.hasRole(
      await vault.WITHDRAWER(),
      alice.address
    );

    //Alice does not have role of withdrawer, so it should throw an error unless role is granted
    assert(
      !hasRoleDepositor,
      `AccessControl: account ${alice.address.toLowerCase()} is missing role WITHDRAWER`
    );

    //grant withdrawer role to alice
    await vault.grantRole(await vault.WITHDRAWER(), alice.address);

    const expectedAssets = fixedPointDiv(shares, id);
    const assets = await vault["previewRedeem(uint256,uint256)"](shares, id);

    assert(
      assets.eq(expectedAssets),
      `Wrong assets: expected ${expectedAssets} got ${assets} `
    );
  });
  it("Redeposit - should be receipt holder", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();
    const [receiptVault, asset, priceOracle] =
      await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();

    const aliceReceiptBalance = await vault["balanceOf(address,uint256)"](
      alice.address,
      shareRatio
    );

    assert(aliceReceiptBalance.eq(0), `NOT_RECEIPT_HOLDER`);
  });
  it("Checks role for snapshotter", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    await assertError(
      async () => await vault.snapshot(),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault.ERC20SNAPSHOTTER()}`,
      "failed to snapshot"
    );
  });
  it("Snapshot event is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    await vault.grantRole(await vault.ERC20SNAPSHOTTER(), alice.address);

    const { id } = (await getEventArgs(
      await vault.snapshot(),
      "Snapshot",
      vault
    )) as SnapshotEvent["args"];

    assert(id.eq(ethers.BigNumber.from(1)), `ID not set`);
  });
  it("Sets correct erc20Tier and mintier", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault.grantRole(await vault.ERC20TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { tier, minimumTier } = (await getEventArgs(
      await vault.setERC20Tier(TierV2TestContract.address, minTier, []),
      "SetERC20Tier",
      vault
    )) as SetERC20TierEvent["args"];

    await vault.setERC20Tier(TierV2TestContract.address, minTier, []);

    assert(
      tier === TierV2TestContract.address,
      `wrong tier expected ${TierV2TestContract.address} got ${tier}`
    );
    assert(
      minimumTier.eq(minTier),
      `wrong minimumTier expected ${minTier} got ${minimumTier}`
    );
  });
  it("Sets correct erc11Tier and mintier", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault.grantRole(await vault.ERC1155TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { tier, minimumTier } = (await getEventArgs(
      await vault.setERC1155Tier(TierV2TestContract.address, minTier, []),
      "SetERC1155Tier",
      vault
    )) as SetERC20TierEvent["args"];

    await vault.setERC1155Tier(TierV2TestContract.address, minTier, []);

    assert(
      tier === TierV2TestContract.address,
      `wrong tier expected ${TierV2TestContract.address} got ${tier}`
    );
    assert(
      minimumTier.eq(minTier),
      `wrong minimumTier expected ${minTier} got ${minimumTier}`
    );
  });
  it("Checks Certify event is emitted", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    //get block timestamp and add 100 to get _until
    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;

    await vault.grantRole(await vault.CERTIFIER(), alice.address);

    const { caller, until } = (await getEventArgs(
      await vault.certify(_until, [], false),
      "Certify",
      vault
    )) as CertifyEvent["args"];

    assert(
      caller === alice.address,
      `wrong caller expected ${alice.address} got ${caller}`
    );
    assert(until.eq(_until), `wrong until expected ${_until} got ${until}`);
  });
  it("Checks role for certifier", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;

    await assertError(
      async () => await vault.certify(_until, [], false),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault.CERTIFIER()}`,
      "failed to certify"
    );
  });
  it("Certifies", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const certifiedUntil = block.timestamp + 100;

    await vault.grantRole(await vault.CERTIFIER(), alice.address);

    const { until } = (await getEventArgs(
      await vault.certify(certifiedUntil, [], false),
      "Certify",
      vault
    )) as CertifyEvent["args"];

    assert(
      until.eq(certifiedUntil),
      `wrong until expected ${certifiedUntil} got ${until}`
    );
  });
  it("Confiscate - Checks role CONFISCATOR", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    await assertError(
      async () => await vault["confiscate(address)"](alice.address),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault.CONFISCATOR()}`,
      "failed to confiscate"
    );
  });
  it("Confiscate - Checks ConfiscateShares is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    await vault.grantRole(await vault.CONFISCATOR(), alice.address);

    const { caller, confiscatee } = (await getEventArgs(
      await vault["confiscate(address)"](alice.address),
      "ConfiscateShares",
      vault
    )) as ConfiscateSharesEvent["args"];

    assert(
      caller === alice.address,
      `wrong caller expected ${alice.address} got ${caller}`
    );
    assert(
      confiscatee === alice.address,
      `wrong confiscatee expected ${alice.address} got ${confiscatee}`
    );
  });
  it("Confiscate overloaded - Checks ConfiscateShares is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();
    const [receiptVault, asset, priceOracle] =
      await deployERC20PriceOracleVault();

    const _id = await priceOracle.price();

    await vault.grantRole(await vault.CONFISCATOR(), alice.address);

    const { caller, confiscatee, id } = (await getEventArgs(
      await vault["confiscate(address,uint256)"](alice.address, _id),
      "ConfiscateReceipt",
      vault
    )) as ConfiscateReceiptEvent["args"];

    assert(
      caller === alice.address,
      `wrong caller expected ${alice.address} got ${caller}`
    );
    assert(
      confiscatee === alice.address,
      `wrong confiscatee expected ${alice.address} got ${confiscatee}`
    );
    assert(id.eq(_id), `wrong id expected ${_id} got ${id}`);
  });
  it("Checks confiscated is same as balance", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];
    const [vault] = await deployOffChainAssetVault();
    const [receiptVault, asset, priceOracle] =
      await deployERC20PriceOracleVault();

    await vault.grantRole(await vault.CONFISCATOR(), alice.address);
    await vault.grantRole(await vault.CONFISCATOR(), bob.address);
    await vault.grantRole(await vault.DEPOSITOR(), alice.address);

    const assets = ethers.BigNumber.from(100);

    await asset.transfer(alice.address, assets);

    await asset.connect(alice).increaseAllowance(vault.address, assets);

    const shareRatio = await priceOracle.price();
    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assets,
        bob.address,
        shareRatio,
        []
      );

    const shares = await vault["balanceOf(address)"](bob.address);

    const { confiscated } = (await getEventArgs(
      await vault.connect(alice)["confiscate(address)"](bob.address),
      "ConfiscateShares",
      vault
    )) as ConfiscateSharesEvent["args"];

    assert(
      confiscated.eq(shares),
      `wrong confiscated expected ${shares} got ${confiscated}`
    );
  });
  it("Checks confiscated is transferred", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];
    const [vault] = await deployOffChainAssetVault();
    const [receiptVault, asset, priceOracle] =
      await deployERC20PriceOracleVault();

    await vault.grantRole(await vault.CONFISCATOR(), alice.address);
    await vault.grantRole(await vault.DEPOSITOR(), alice.address);

    const assets = ethers.BigNumber.from(100);

    await asset.transfer(alice.address, assets);

    await asset.connect(alice).increaseAllowance(vault.address, assets);

    const shareRatio = await priceOracle.price();
    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assets,
        bob.address,
        shareRatio,
        []
      );
    const aliceBalanceBef = await vault["balanceOf(address)"](alice.address);

    const { confiscated } = (await getEventArgs(
      await vault.connect(alice)["confiscate(address)"](bob.address),
      "ConfiscateShares",
      vault
    )) as ConfiscateSharesEvent["args"];

    const aliceBalanceAft = await vault["balanceOf(address)"](alice.address);
    assert(
      aliceBalanceAft.eq(aliceBalanceBef.add(confiscated)),
      `Shares has not been confiscated`
    );
  });
  it("Checks confiscated is same as receipt balance", async function () {
    const signers = await ethers.getSigners();
    const [vault] = await deployOffChainAssetVault();

    const [receiptVault, asset, priceOracle] =
      await deployERC20PriceOracleVault();

    const alice = signers[0];
    const bob = signers[1];

    const shareRatio = await priceOracle.price();
    const aliceAssets = ethers.BigNumber.from(1000);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const certifiedUntil = block.timestamp + 100;
    await vault.grantRole(await vault.CERTIFIER(), alice.address);
    await vault.certify(certifiedUntil, [], false);

    await asset.transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault.grantRole(await vault.DEPOSITOR(), alice.address);
    await vault.grantRole(await vault.CONFISCATOR(), alice.address);

    const { id } = (await getEventArgs(
      await vault["deposit(uint256,address,uint256,bytes)"](
        aliceAssets,
        bob.address,
        shareRatio,
        []
      ),
      "DepositWithReceipt",
      vault
    )) as DepositWithReceiptEvent["args"];

    const bobReceiptBalance = await vault["balanceOf(address,uint256)"](
      bob.address,
      id
    );

    const { confiscated } = (await getEventArgs(
      await vault
        .connect(alice)
        ["confiscate(address,uint256)"](bob.address, id),
      "ConfiscateReceipt",
      vault
    )) as ConfiscateSharesEvent["args"];

    assert(
      confiscated.eq(bobReceiptBalance),
      `wrong confiscated expected ${bobReceiptBalance} got ${confiscated}`
    );
  });
  it("Checks confiscated amount is transferred", async function () {
    const signers = await ethers.getSigners();
    const [vault] = await deployOffChainAssetVault();

    const [receiptVault, asset, priceOracle] =
      await deployERC20PriceOracleVault();

    const alice = signers[0];
    const bob = signers[1];

    const shareRatio = await priceOracle.price();
    const aliceAssets = ethers.BigNumber.from(1000);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const certifiedUntil = block.timestamp + 100;
    await vault.grantRole(await vault.CERTIFIER(), alice.address);
    await vault.certify(certifiedUntil, [], false);

    await asset.transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault.grantRole(await vault.DEPOSITOR(), alice.address);
    await vault.grantRole(await vault.CONFISCATOR(), alice.address);

    const { id } = (await getEventArgs(
      await vault["deposit(uint256,address,uint256,bytes)"](
        aliceAssets,
        bob.address,
        shareRatio,
        []
      ),
      "DepositWithReceipt",
      vault
    )) as DepositWithReceiptEvent["args"];

    const aliceBalanceBef = await vault["balanceOf(address,uint256)"](
      alice.address,
      id
    );

    const { confiscated } = (await getEventArgs(
      await vault
        .connect(alice)
        ["confiscate(address,uint256)"](bob.address, id),
      "ConfiscateReceipt",
      vault
    )) as ConfiscateSharesEvent["args"];

    const aliceBalanceAft = await vault["balanceOf(address,uint256)"](
      alice.address,
      id
    );

    assert(
      aliceBalanceAft.eq(aliceBalanceBef.add(confiscated)),
      `Shares has not been confiscated`
    );
  });
  it("should deploy offchainAssetVault using factory", async () => {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const offchainAssetVaultFactoryFactory = await ethers.getContractFactory(
      "OffchainAssetVaultFactory"
    );

    const offchainAssetVaultFactory =
      (await offchainAssetVaultFactoryFactory.deploy()) as OffchainAssetVaultFactory;
    await offchainAssetVaultFactory.deployed();

    const constructionConfig = {
      admin: alice.address,
      receiptVaultConfig: {
        asset: ADDRESS_ZERO,
        name: "EthGild",
        symbol: "ETHg",
        uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
      },
    };
    const offchainAssetVault = await offchainAssetVaultFactory.createChildTyped(
      constructionConfig
    );
  });
});
