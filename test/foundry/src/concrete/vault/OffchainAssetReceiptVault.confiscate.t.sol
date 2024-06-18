// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "../../../../../contracts/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVault} from "../../../../../contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {IReceiptV1} from "../../../../../contracts/interface/IReceiptV1.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/foundry/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/foundry/lib/LibOffchainAssetVaultCreator.sol";
import {LibConfiscateChecker} from "test/foundry/lib/LibConfiscateChecker.sol";

contract Confiscate is OffchainAssetReceiptVaultTest {
    event ConfiscateShares(address sender, address confiscatee, uint256 confiscated, bytes justification);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event ConfiscateReceipt(address sender, address confiscatee, uint256 id, uint256 confiscated, bytes justification);
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /// Test to checks ConfiscateShares does not change balances on zero balance
    function testConfiscateOnZeroBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 balance,
        uint256 minShareRatio
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Bound balance from 1 so depositing does not revert with ZeroAssetsAmount
        balance = bound(balance, 1, type(uint256).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        // vm.stopPrank();

        // // Prank as Bob for tranactions
        vm.startPrank(bob);

        // Deposit to increase bob's balance
        vault.deposit(balance, bob, minShareRatio, data);

        bool noBalanceChange = LibConfiscateChecker.checkConfiscateSharesNoop(vault, alice, bob, data);

        assertTrue(noBalanceChange, "Balances should not change");
        vm.stopPrank();
    }

    /// Test to check ConfiscateShares
    function testConfiscateShares(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        // Assume that assets is less than totalSupply
        assets = bound(assets, 1, type(uint256).max);

        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectEmit(false, false, false, true);
        emit ConfiscateShares(bob, alice, assets, data);

        bool balancesChanged = LibConfiscateChecker.checkConfiscateShares(vault, alice, bob, data);

        assertTrue(balancesChanged, "Balances should change");

        vm.stopPrank();
    }

    /// Test to checks Confiscated amount is transferred
    function testConfiscatedIsTransferred(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        vm.assume(alice != bob);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        // Assume that assets is less than uint256 max
        assets = bound(assets, 1, type(uint256).max);

        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectEmit(false, false, false, true);
        emit Transfer(alice, bob, assets);

        bool balancesChanged = LibConfiscateChecker.checkConfiscateShares(vault, alice, bob, data);

        assertTrue(balancesChanged, "Balances should change");

        vm.stopPrank();
    }

    /// Test to checks ConfiscateReceipt does not change balances on zero balance
    function testConfiscateReceiptOnZeroBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 id
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        id = bound(id, 0, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);

        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        bool noBalanceChange =
            LibConfiscateChecker.checkConfiscateReceiptNoop(vault, getReceipt(), alice, bob, id, data);
        assertTrue(noBalanceChange, "ConfiscateReceipt should not change balances");

        vm.stopPrank();
    }

    /// Test to checks ConfiscateReceipt
    function testConfiscateReceipt(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        bytes memory data,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        // Assume that assets is less than uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);

        vm.assume(alice != bob);
        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectEmit(false, false, false, true);
        emit ConfiscateReceipt(bob, alice, 1, assets, data);

        vault.confiscateReceipt(alice, 1, data);
        vm.stopPrank();
    }

    /// Test to checks ConfiscatedReceipt amount is transferred
    function testConfiscatedReceiptIsTransferred(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        bytes memory data,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);

        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        //set upperBound for assets so it does not overflow
        uint256 upperBound = type(uint256).max / 1e18;
        // Assume that assets is less than totalSupply
        assets = bound(assets, 1, upperBound);

        vault.deposit(assets, alice, minShareRatio, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectEmit(false, false, false, true);
        emit TransferSingle(address(vault), alice, bob, 1, assets);

        vault.confiscateReceipt(alice, 1, data);
        vm.stopPrank();
    }
}
