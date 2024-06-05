// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {InvalidId} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfig,
    CertificationExpired
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {IReceiptV1} from "../../contracts/vault/receipt/IReceiptV1.sol";
import {TestErc20} from "../../contracts/test/TestErc20.sol";
import {LibFixedPointMath, Math} from "@rainprotocol/rain-protocol/contracts/math/LibFixedPointMath.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";

contract RedepositTest is Test, CreateOffchainAssetReceiptVaultFactory {
    using LibFixedPointMath for uint256;

    function testReDeposit(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();

        // Assume that aliceAssets is less than totalSupply
        aliceAssets = bound(aliceAssets, 1, testErc20Contract.totalSupply());

        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        vault.grantRole(vault.DEPOSITOR(), alice);

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

        // Divide alice assets to 3 to have enough assets for redeposit
        uint256 assetsToDeposit = aliceAssets.fixedPointDiv(3, Math.Rounding.Up);

        vault.deposit(assetsToDeposit, alice, 1e18, fuzzedReceiptInformation);

        uint256 expectedShares = assetsToDeposit.fixedPointMul(1e18, Math.Rounding.Up);
        assertEqUint(receipt.balanceOf(alice, 1), expectedShares);

        // Redeposit same amount
        vault.redeposit(assetsToDeposit, alice, 1, fuzzedReceiptInformation);

        //shares should be doubled
        assertEqUint(receipt.balanceOf(alice, 1), expectedShares * 2);

        vm.stopPrank();
    }

    /// Test redeposit to someone else reverts with certification expired
    function testReDepositToSomeoneElseReverts(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 fuzzedKeyBob,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();

        // Assume that aliceAssets is less than totalSupply
        aliceAssets = bound(aliceAssets, 1, testErc20Contract.totalSupply());

        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.deposit(aliceAssets, alice, 1e18, fuzzedReceiptInformation);

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), bob, 0, 1));
        vault.redeposit(aliceAssets, bob, 1, fuzzedReceiptInformation);

        vm.stopPrank();
    }

    /// Test redeposit to someone else with Depositor role
    function testReDepositToSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 fuzzedKeyBob,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        {
            //New testErc20 contract
            TestErc20 testErc20Contract = new TestErc20();

            // Assume that aliceAssets is less than totalSupply
            aliceAssets = bound(aliceAssets, 1, testErc20Contract.totalSupply());

            testErc20Contract.transfer(alice, aliceAssets);
            testErc20Contract.increaseAllowance(address(vault), aliceAssets);

            vault.grantRole(vault.DEPOSITOR(), alice);
            vault.grantRole(vault.DEPOSITOR(), bob);
        }
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

        // Divide alice assets to 3 to have enough assets for redeposit
        uint256 assetsToDeposit = aliceAssets.fixedPointDiv(3, Math.Rounding.Down);

        vault.deposit(assetsToDeposit, bob, 1e18, fuzzedReceiptInformation);

        uint256 expectedShares = assetsToDeposit.fixedPointMul(1e18, Math.Rounding.Up);
        assertEqUint(receipt.balanceOf(bob, 1), expectedShares);

        // Redeposit same amount
        vault.redeposit(assetsToDeposit, bob, 1, fuzzedReceiptInformation);

        //shares should be doubled
        assertEqUint(receipt.balanceOf(bob, 1), expectedShares * 2);

        vm.stopPrank();
    }

    /// Test redeposit reverts on nonexistent receipt id
    function testReDepositToNonExistentReceipt(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        //New testErc20 contract
        TestErc20 testErc20Contract = new TestErc20();

        // Assume that aliceAssets is less than totalSupply
        aliceAssets = bound(aliceAssets, 1, testErc20Contract.totalSupply());

        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.deposit(aliceAssets, alice, 1e18, fuzzedReceiptInformation);

        vm.expectRevert(abi.encodeWithSelector(InvalidId.selector, 0));
        vault.redeposit(aliceAssets, alice, 0, fuzzedReceiptInformation);

        vm.stopPrank();
    }
}
