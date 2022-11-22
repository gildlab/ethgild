import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ReadWriteTier, TestErc20 } from "../../typechain";
import { ethers } from "hardhat";

import {
  getEventArgs,
  expectedName,
  expectedSymbol,
  ADDRESS_ZERO,
  assertError,
  fixedPointMul,
  ONE,
  fixedPointDiv,
  deployERC20PriceOracleVault,
} from "../util";

import {
  SetERC20TierEvent,
  CertifyEvent,
  SnapshotEvent,
  ConfiscateSharesEvent,
  ConfiscateReceiptEvent,
} from "../../typechain/OffchainAssetReceiptVault";
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
    const [vault, receipt, config] = await deployOffChainAssetVault();

    assert(
      config.receiptVaultConfig.vaultConfig.name === expectedName,
      `wrong name expected ${expectedName} got ${config.receiptVaultConfig.vaultConfig.name}`
    );
    assert(
      config.receiptVaultConfig.vaultConfig.asset === ADDRESS_ZERO,
      `wrong asset expected ${ADDRESS_ZERO} got ${config.receiptVaultConfig.vaultConfig.asset}`
    );

    assert(
      config.receiptVaultConfig.vaultConfig.symbol === expectedSymbol,
      `wrong symbol expected ${expectedSymbol} got ${config.receiptVaultConfig.vaultConfig.symbol}`
    );
  });
  it("Checks asset is zero", async function () {
    const [vault, receipt, config] = await deployOffChainAssetVault();

    assert(
      config.receiptVaultConfig.vaultConfig.asset === ADDRESS_ZERO,
      `NONZERO_ASSET`
    );
  });
  it("Checks SetERC20Tier role", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const minTier = ethers.BigNumber.from(10);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .setERC20Tier(TierV2TestContract.address, minTier, []),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
        .connect(alice)
        .ERC20TIERER()}`,
      "Failed to set erc20tier"
    );
  });
  it("Checks SetERC20Tier event is emitted", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC20TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { caller, tier, minimumTier } = (await getEventArgs(
      await vault
        .connect(alice)
        .setERC20Tier(TierV2TestContract.address, minTier, []),
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
        await vault
          .connect(alice)
          .setERC1155Tier(TierV2TestContract.address, minTier, []),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
        .connect(alice)
        .ERC1155TIERER()}`,
      "Failed to set erc1155tier"
    );
  });
  it("Checks setERC1155Tier event is emitted", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC1155TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(100);

    const { caller, tier, minimumTier } = (await getEventArgs(
      await vault
        .connect(alice)
        .setERC1155Tier(TierV2TestContract.address, minTier, []),
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

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];
    const bob = signers[2];

    const shareRatio = ONE;
    const aliceAssets = ethers.BigNumber.from(1000);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        aliceAssets,
        bob.address,
        shareRatio,
        []
      );

    const totalSupply = await vault.connect(alice).totalSupply();
    const totalAssets = await vault.connect(alice).totalAssets();

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

    const hasRoleDepositor = await vault
      .connect(alice)
      .hasRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    //Alice does not have role of depositor, so it should throw an error unless role is granted
    assert(
      !hasRoleDepositor,
      `AccessControl: account ${alice.address.toLowerCase()} is missing role DEPOSITOR`
    );

    //grant depositor role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const shares = await vault.connect(alice).previewDeposit(assets);

    assert(
      shares.eq(assets),
      `Wrong shares: expected ${assets} got ${shares} `
    );
  });
  it("PreviewMint sets 0 if not DEPOSITOR", async function () {
    const [vault] = await deployOffChainAssetVault();
    const shares = ethers.BigNumber.from(100);
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const assets = await vault.connect(alice).previewMint(shares);
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
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assets = await vault.connect(alice).previewMint(shares);
    const expectedAssets = fixedPointDiv(shares, ONE).add(1);

    assert(
      assets.eq(expectedAssets),
      `Wrong assets: expected ${expectedAssets} got ${assets} `
    );
  });
  it("PreviewWithdraw sets 0 shares if no withdrawer role", async function () {
    const [vault] = await deployOffChainAssetVault();
    const assets = ethers.BigNumber.from(100);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const id = ethers.BigNumber.from(1);

    const expectedShares = ethers.BigNumber.from(0);

    const shares = await vault
      .connect(alice)
      ["previewWithdraw(uint256,uint256)"](assets, id);

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
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    const expectedShares = fixedPointMul(assets, id).add(1);

    const shares = await vault
      .connect(alice)
      ["previewWithdraw(uint256,uint256)"](assets, id);

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

    const id = ONE;

    const hasRoleDepositor = await vault
      .connect(alice)
      .hasRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    //Alice does not have role of withdrawer, so it should throw an error unless role is granted
    assert(
      !hasRoleDepositor,
      `AccessControl: account ${alice.address.toLowerCase()} is missing role WITHDRAWER`
    );

    //grant withdrawer role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    const expectedAssets = fixedPointDiv(shares, id);
    const assets = await vault
      .connect(alice)
      ["previewRedeem(uint256,uint256)"](shares, id);

    assert(
      assets.eq(expectedAssets),
      `Wrong assets: expected ${expectedAssets} got ${assets} `
    );
  });
  it("Redeposit - should be receipt holder", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault, receipt] = await deployOffChainAssetVault();

    const aliceReceiptBalance = await receipt
      .connect(alice)
      .balanceOf(alice.address, ONE);

    assert(aliceReceiptBalance.eq(0), `NOT_RECEIPT_HOLDER`);
  });
  it("Checks role for snapshotter", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    await assertError(
      async () => await vault.connect(alice).snapshot(),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
        .connect(alice)
        .ERC20SNAPSHOTTER()}`,
      "failed to snapshot"
    );
  });
  it("Snapshot event is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC20SNAPSHOTTER(), alice.address);

    const { id } = (await getEventArgs(
      await vault.connect(alice).snapshot(),
      "Snapshot",
      vault
    )) as SnapshotEvent["args"];

    assert(id.eq(ethers.BigNumber.from(1)), `ID not set`);
  });
  it("Sets correct erc20Tier and mintier", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC20TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { tier, minimumTier } = (await getEventArgs(
      await vault
        .connect(alice)
        .setERC20Tier(TierV2TestContract.address, minTier, []),
      "SetERC20Tier",
      vault
    )) as SetERC20TierEvent["args"];

    await vault
      .connect(alice)
      .setERC20Tier(TierV2TestContract.address, minTier, []);

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

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC1155TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { tier, minimumTier } = (await getEventArgs(
      await vault
        .connect(alice)
        .setERC1155Tier(TierV2TestContract.address, minTier, []),
      "SetERC1155Tier",
      vault
    )) as SetERC20TierEvent["args"];

    await vault
      .connect(alice)
      .setERC1155Tier(TierV2TestContract.address, minTier, []);

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

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);

    const { caller, until } = (await getEventArgs(
      await vault.connect(alice).certify(_until, [], false),
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
      async () => await vault.connect(alice).certify(_until, [], false),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
        .connect(alice)
        .CERTIFIER()}`,
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

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);

    const { until } = (await getEventArgs(
      await vault.connect(alice).certify(certifiedUntil, [], false),
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
      async () =>
        await vault.connect(alice)["confiscate(address)"](alice.address),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
        .connect(alice)
        .CONFISCATOR()}`,
      "failed to confiscate"
    );
  });
  it("Confiscate - Checks ConfiscateShares is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CONFISCATOR(), alice.address);

    const { caller, confiscatee } = (await getEventArgs(
      await vault.connect(alice)["confiscate(address)"](alice.address),
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

    const _id = ONE;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CONFISCATOR(), alice.address);

    const { caller, confiscatee, id } = (await getEventArgs(
      await vault
        .connect(alice)
        ["confiscate(address,uint256)"](alice.address, _id),
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
    const [vault] = await deployOffChainAssetVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CONFISCATOR(), alice.address);
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assets = ethers.BigNumber.from(100);

    await asset.transfer(alice.address, assets);

    await asset
      .connect(alice)
      .increaseAllowance(vault.connect(alice).address, assets);

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assets,
        alice.address,
        ONE,
        []
      );

    const shares = await vault
      .connect(alice)
      ["balanceOf(address)"](alice.address);

    const { confiscated } = (await getEventArgs(
      await vault.connect(alice)["confiscate(address)"](alice.address),
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

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CONFISCATOR(), alice.address);
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assets = ethers.BigNumber.from(100);

    await asset.transfer(alice.address, assets);

    await asset
      .connect(alice)
      .increaseAllowance(vault.connect(alice).address, assets);

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](assets, bob.address, ONE, []);
    const aliceBalanceBef = await vault
      .connect(alice)
      ["balanceOf(address)"](alice.address);

    const { confiscated } = (await getEventArgs(
      await vault.connect(alice)["confiscate(address)"](bob.address),
      "ConfiscateShares",
      vault
    )) as ConfiscateSharesEvent["args"];

    const aliceBalanceAft = await vault
      .connect(alice)
      ["balanceOf(address)"](alice.address);
    assert(
      aliceBalanceAft.eq(aliceBalanceBef.add(confiscated)),
      `Shares has not been confiscated`
    );
  });
  it("Checks confiscated is same as receipt balance", async function () {
    const signers = await ethers.getSigners();
    const [vault, receipt] = await deployOffChainAssetVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];
    const bob = signers[1];

    const aliceAssets = ethers.BigNumber.from(1000);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const certifiedUntil = block.timestamp + 100;
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);
    await vault.connect(alice).certify(certifiedUntil, [], false);

    await asset.transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CONFISCATOR(), alice.address);

    const { id } = (await getEventArgs(
      await vault
        .connect(alice)
        ["deposit(uint256,address,uint256,bytes)"](
          aliceAssets,
          bob.address,
          ONE,
          []
        ),
      "DepositWithReceipt",
      vault
    )) as DepositWithReceiptEvent["args"];

    const bobReceiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, id);

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
    const [vault, receipt] = await deployOffChainAssetVault();

    const alice = signers[0];
    const bob = signers[1];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const aliceAssets = ethers.BigNumber.from(1000);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const certifiedUntil = block.timestamp + 100;
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);
    await vault.connect(alice).certify(certifiedUntil, [], false);

    await asset.transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CONFISCATOR(), alice.address);

    const { id } = (await getEventArgs(
      await vault
        .connect(alice)
        ["deposit(uint256,address,uint256,bytes)"](
          aliceAssets,
          bob.address,
          ONE,
          []
        ),
      "DepositWithReceipt",
      vault
    )) as DepositWithReceiptEvent["args"];

    const aliceBalanceBef = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](alice.address, id);

    const { confiscated } = (await getEventArgs(
      await vault
        .connect(alice)
        ["confiscate(address,uint256)"](bob.address, id),
      "ConfiscateReceipt",
      vault
    )) as ConfiscateSharesEvent["args"];

    const aliceBalanceAft = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](alice.address, id);

    assert(
      aliceBalanceAft.eq(aliceBalanceBef.add(confiscated)),
      `Shares has not been confiscated`
    );
  });
  it("Should call multicall", async () => {
    this.timeout(0);
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault, receipt] = await deployOffChainAssetVault();
    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(bob.address, assets);
    await testErc20Contract
      .connect(bob)
      .increaseAllowance(vault.address, assets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), bob.address);

    const shares = ethers.BigNumber.from(10);
    const shares2 = ethers.BigNumber.from(20);
    await vault
      .connect(bob)
      ["mint(uint256,address,uint256,bytes)"](shares, bob.address, 1, []);
    await vault
      .connect(bob)
      ["mint(uint256,address,uint256,bytes)"](shares2, bob.address, 2, []);

    let ABI = [
      "function redeem(uint256 shares_, address receiver_, address owner_, uint256 id_)",
    ];
    let iface = new ethers.utils.Interface(ABI);
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), bob.address);

    await vault
      .connect(bob)
      .multicall(
        [
          iface.encodeFunctionData("redeem", [
            ethers.BigNumber.from(10),
            bob.address,
            bob.address,
            1,
          ]),
          iface.encodeFunctionData("redeem", [
            ethers.BigNumber.from(20),
            bob.address,
            bob.address,
            2,
          ]),
        ],
        { from: bob.address }
      );

    let balance1 = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, 1);
    let balance2 = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, 2);

    assert(
      balance1.eq(ethers.BigNumber.from(0)) &&
        balance2.eq(ethers.BigNumber.from(0)),
      `Shares has not been redeemed`
    );
  });
});