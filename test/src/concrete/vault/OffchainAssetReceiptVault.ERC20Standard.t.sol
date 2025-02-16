// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2,
    DEPOSIT,
    CERTIFY
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizorV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

contract OffchainAssetReceiptVaultERC20StandardTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test ERC20 name symbol and decimals
    function testERC20NameSymbolDecimals(uint256 aliceSeed, string memory shareName, string memory shareSymbol)
        external
    {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        vm.startPrank(alice);

        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(shareName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(shareSymbol)));
        assertEq(vault.decimals(), 18);
    }

    /// Test ERC20 totalSupply and balanceOf
    function testERC20TotalSupplyAndBalanceOf(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 minShareRatio,
        uint256 timestamp,
        bytes memory receiptInformation
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        assets = bound(assets, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFY, alice);

        timestamp = bound(timestamp, 1, type(uint32).max);
        vm.warp(timestamp);
        vault.certify(timestamp, false, receiptInformation);

        uint256 expectedShares = assets;
        vault.deposit(assets, alice, minShareRatio, bytes(""));
        // Assert that the total supply is equal to expectedShares
        assertEqUint(vault.totalSupply(), expectedShares);
        // Check alice balance
        assertEqUint(vault.balanceOf(alice), expectedShares);
    }

    // Test ERC20 transfer
    function testERC20Transfer(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 amount,
        uint256 minShareRatio,
        uint256 timestamp,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);

        // Setup vault and deposit initial balance
        OffchainAssetReceiptVault vault = createVault(alice, "Test Token", "TST");

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFY, alice);

        timestamp = bound(timestamp, 1, type(uint32).max);
        vm.warp(timestamp);
        vault.certify(timestamp, false, receiptInformation);

        // Mock balance and allowance for deposit
        uint256 bobInitialBalance = vault.balanceOf(bob);

        uint256 expectedShares = amount;
        vault.deposit(amount, alice, minShareRatio, bytes(""));

        vault.transfer(bob, expectedShares);

        // Check balances
        assertEqUint(bobInitialBalance, 0);
        assertEqUint(vault.balanceOf(bob), expectedShares);
    }

    // Test ERC20 allowance and approve
    function testERC20AllowanceAndApprove(uint256 aliceSeed, uint256 bobSeed, uint256 amount) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.assume(alice != bob);

        amount = bound(amount, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, "Test Token", "TST");

        vm.startPrank(alice);
        // Set an allowance for Bob
        vault.approve(bob, amount);

        // Check allowance
        assertEq(vault.allowance(alice, bob), amount);
    }

    // Test ERC20 transferFrom()
    function testERC20TransferFrom(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 amount,
        uint256 transferFromAmount,
        uint256 minSharesRatio,
        uint256 timestamp,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minSharesRatio = bound(minSharesRatio, 0, 1e18);
        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);
        transferFromAmount = bound(transferFromAmount, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, "Test Token", "TST");

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFY, alice);

        timestamp = bound(timestamp, 1, type(uint32).max);
        vm.warp(timestamp);
        vault.certify(timestamp, false, receiptInformation);

        uint256 expectedShares = amount;
        vm.assume(transferFromAmount < expectedShares);

        vault.deposit(amount, alice, minSharesRatio, bytes(""));

        uint256 aliceBalanceBeforeTransfer = vault.balanceOf(alice);

        vault.approve(bob, expectedShares);

        vm.stopPrank();
        vm.startPrank(bob);

        // Bob transfers from Alice's account to his own
        vault.transferFrom(alice, bob, transferFromAmount);

        assertEqUint(vault.balanceOf(alice), aliceBalanceBeforeTransfer - transferFromAmount);
        assertEqUint(vault.balanceOf(bob), transferFromAmount);
        vm.stopPrank();
    }

    // Test ERC20 increaseAllowance
    function testERC20IncreaseAllowance(uint256 aliceSeed, uint256 bobSeed, uint256 amount, uint256 increaseAmount)
        external
    {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);
        increaseAmount = bound(increaseAmount, 1, type(uint128).max);
        vm.assume(increaseAmount < amount);

        OffchainAssetReceiptVault vault = createVault(alice, "Test Token", "TST");

        vm.startPrank(alice);
        vault.approve(bob, amount);

        vault.increaseAllowance(bob, increaseAmount);

        // Check that allowance increased correctly
        assertEq(vault.allowance(alice, bob), amount + increaseAmount);
    }

    // Test ERC20 decreaseAllowance
    function testERC20DecreaseAllowance(uint256 aliceSeed, uint256 bobSeed, uint256 amount, uint256 decreaseAmount)
        external
    {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);
        decreaseAmount = bound(decreaseAmount, 1, type(uint128).max);
        vm.assume(decreaseAmount < amount);

        OffchainAssetReceiptVault vault = createVault(alice, "Test Token", "TST");

        vm.startPrank(alice);
        vault.approve(bob, amount);

        vault.decreaseAllowance(bob, decreaseAmount);

        // Check that allowance decreased correctly
        assertEq(vault.allowance(alice, bob), amount - decreaseAmount);
    }
}
