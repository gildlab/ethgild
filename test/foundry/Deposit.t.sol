// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {
    VaultConfig, MinShareRatio, ZeroAssetsAmount, ZeroReceiver
} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig,
    OffchainAssetReceiptVaultConfig,
    ZeroAdmin,
    NonZeroAsset,
    CertificationExpired
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {IReceiptV1} from "../../contracts/vault/receipt/IReceiptV1.sol";
import {TestErc20} from "../../contracts/test/TestErc20.sol";
import {TestErc20} from "../../contracts/test/TestErc20.sol";
import {LibFixedPointMath, Math} from "@rainprotocol/rain-protocol/contracts/math/LibFixedPointMath.sol";

uint256 constant TOTAL_SUPPLY = 1e27;

struct DepositWithReceiptEvent {
    address sender;
    address owner;
    uint256 assets;
    uint256 shares;
    uint256 id;
    bytes receiptInformation;
}

contract DepositTest is Test, CreateOffchainAssetReceiptVaultFactory {
    using LibFixedPointMath for uint256;

    OffchainAssetReceiptVault vault;
    address alice;
    uint256 shareRatio = 1e18;

    function setUp() public {
        alice = vm.addr(1);
        address asset = address(0);
        string memory assetName = "Asset Name";
        string memory assetSymbol = "ASSET";

        VaultConfig memory vaultConfig = VaultConfig({asset: asset, name: assetName, symbol: assetSymbol});
        vault = factory.createChildTyped(OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig}));
    }

    function testDeposit(uint256 aliceAssets, bytes memory fuzzedReceiptInformation) external {
        // Assume that aliceAssets is less than TOTAL_SUPPLY
        aliceAssets = bound(aliceAssets, 1, TOTAL_SUPPLY - 1);
        uint256 expectedShares = aliceAssets.fixedPointMul(shareRatio, Math.Rounding.Up);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        vault.grantRole(vault.DEPOSITOR(), alice);

        // Log event
        // Start recording logs
        vm.recordLogs();

        vault.deposit(aliceAssets, alice, shareRatio, fuzzedReceiptInformation);

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        DepositWithReceiptEvent memory eventData;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("DepositWithReceipt(address,address,uint256,uint256,uint256,bytes)")) {
                // Decode the event data
                (
                    address sender,
                    address owner,
                    uint256 assets,
                    uint256 shares,
                    uint256 id,
                    bytes memory receiptInformation
                ) = abi.decode(logs[i].data, (address, address, uint256, uint256, uint256, bytes));
                eventData = DepositWithReceiptEvent({
                    sender: sender,
                    owner: owner,
                    assets: assets,
                    shares: shares,
                    id: id,
                    receiptInformation: receiptInformation
                });
                break;
            }
        }

        assertEqUint(vault.totalSupply(), vault.totalAssets());
        assertEq(eventData.sender, alice);
        assertEq(eventData.owner, alice);
        assertEq(eventData.assets, aliceAssets);
        assertEq(eventData.shares, expectedShares);
        assertEq(eventData.id, 1);
        assertEq(eventData.receiptInformation, fuzzedReceiptInformation);

        vm.stopPrank();
    }

    function testTotalAssets(
        uint256 aliceAssets,
        bytes memory receiptInformation,
        uint256 certifyUntil,
        bytes memory data
    ) external {
        // Assume that aliceAssets is less than TOTAL_SUPPLY
        aliceAssets = bound(aliceAssets, 1, TOTAL_SUPPLY - 1);
        // Assume that certifyUntil is not zero and is in future
        certifyUntil = bound(certifyUntil, 1, block.number + 1);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Get the second signer address
        address bob = vm.addr(2);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        // Grant CERTIFIER role to Alice
        vault.grantRole(vault.CERTIFIER(), alice);

        // Set up expected parameters
        bool forceUntil = false;

        // Call the certify function
        vault.certify(certifyUntil, block.number, forceUntil, data);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);

        assertEqUint(vault.totalSupply(), vault.totalAssets());

        vm.stopPrank();
    }

    function testMinShareRatio(uint256 aliceAssets, bytes memory receiptInformation) external {
        // Assume that aliceAssets is less than TOTAL_SUPPLY
        aliceAssets = bound(aliceAssets, 1, TOTAL_SUPPLY - 1);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, shareRatio + 1, shareRatio));
        vault.deposit(aliceAssets, alice, shareRatio + 1, receiptInformation);

        vm.stopPrank();
    }

    function testZeroAssetsAmount(bytes memory receiptInformation) external {
        // Assume that aliceAssets is less than TOTAL_SUPPLY
        uint256 aliceAssets = 0;

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.deposit(aliceAssets, alice, shareRatio, receiptInformation);

        vm.stopPrank();
    }

    function testZeroReceiver(uint256 aliceAssets, bytes memory receiptInformation) external {
        // Assume that aliceAssets is less than TOTAL_SUPPLY
        aliceAssets = bound(aliceAssets, 1, TOTAL_SUPPLY - 1);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiver.selector));
        vault.deposit(aliceAssets, address(0), shareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test deposit to someone else reverts if system not certified
    function testDepositToSomeoneElseExpiredCertification(
        uint256 fuzzedKeyBob,
        uint256 aliceAssets,
        bytes memory receiptInformation
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);

        // Assume that aliceAssets is less than TOTAL_SUPPLY
        aliceAssets = bound(aliceAssets, 1, TOTAL_SUPPLY - 1);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), bob, 0, 1));

        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);

        vm.stopPrank();
    }

    function testPreviewDepositReturnedShares(uint256 aliceAssets) external {
        // Assume that aliceAssets is less than TOTAL_SUPPLY
        aliceAssets = bound(aliceAssets, 1, TOTAL_SUPPLY - 1);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), alice);
        uint256 shares = vault.previewDeposit(aliceAssets);

        assertEqUint(shares, aliceAssets);

        vm.stopPrank();
    }

    function testPreviewMintReturnedAssets(uint256 shares) external {
        shares = bound(shares, 1, TOTAL_SUPPLY - 1);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        uint256 expectedAssets = shares.fixedPointDiv(shareRatio, Math.Rounding.Up);

        vault.grantRole(vault.DEPOSITOR(), alice);
        uint256 assets = vault.previewMint(shares);

        assertEqUint(assets, expectedAssets);

        vm.stopPrank();
    }

    function testMintWithData(
        uint256 aliceAssets,
        bytes memory receiptInformation,
        uint256 certifyUntil,
        bytes memory data
    ) external {
        // Assume that aliceAssets is less than TOTAL_SUPPLY
        aliceAssets = bound(aliceAssets, 1, TOTAL_SUPPLY - 1);
        // Assume that certifyUntil is not zero and is in future
        certifyUntil = bound(certifyUntil, 1, block.number + 1);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        // Start recording logs
        vm.recordLogs();

        // todo refactor with function
        VaultConfig memory vaultConfig = VaultConfig({asset: address(0), name: "Asset Name", symbol: "ASSET"});
        vault = factory.createChildTyped(OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig}));
        //

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        address receiptAddress = address(0);
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "OffchainAssetReceiptVaultInitialized(address,(address,(address,(address,string,string))))"
                    )
            ) {
                // Decode the event data
                (, OffchainAssetReceiptVaultConfig memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfig));
                receiptAddress = config.receiptVaultConfig.receipt;
                break;
            }
        }
        // Create an instance of the Receipt contract
        IReceiptV1 receipt = IReceiptV1(receiptAddress);
        // Grant CERTIFIER role to Alice
        vault.grantRole(vault.CERTIFIER(), alice);

        // Call the certify function
        vault.certify(certifyUntil, block.number, false, data);

        vault.grantRole(vault.DEPOSITOR(), alice);

        uint256 shares = aliceAssets.fixedPointMul(shareRatio, Math.Rounding.Up);

        vault.mint(shares, alice, shareRatio, receiptInformation);
        uint256 expectedAssets = shares.fixedPointDiv(shareRatio, Math.Rounding.Up);
        uint256 balanceAfter = receipt.balanceOf(alice, 1);

        assertEqUint(balanceAfter, expectedAssets);

        vm.stopPrank();
    }
}
