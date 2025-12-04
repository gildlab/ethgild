// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20PriceOracleReceiptVaultERC20StandardTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using SafeERC20 for IERC20;

    /// Test ERC20 name symbol and decimals
    function testERC20NameSymbolDecimals(uint256 aliceSeed, string memory shareName, string memory shareSymbol)
        external
    {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        IPriceOracleV2 vaultPriceOracle =
            IPriceOracleV2(payable(address(uint160(uint256(keccak256("twoPriceOracle"))))));
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(vaultPriceOracle, shareName, shareSymbol);

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
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(I_VAULT_ORACLE, shareName, shareSymbol);
        {
            assets = bound(assets, 1, type(uint128).max);
            vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

            vm.mockCall(
                address(I_ASSET),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
                abi.encode(true)
            );
            vm.expectCall(address(I_ASSET), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets));
        }

        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Floor);
        vault.deposit(assets, alice, oraclePrice, bytes(""));
        // Assert that the total supply is equal to expectedShares
        assertEqUint(vault.totalSupply(), expectedShares);
        // Check alice balance
        assertEqUint(vault.balanceOf(alice), expectedShares);
    }

    // Test ERC20 transfer
    function testERC20Transfer(uint256 aliceSeed, uint256 bobSeed, uint256 amount, uint256 oraclePrice) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        amount = bound(amount, 1, type(uint128).max);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        vm.assume(amount.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        setVaultOraclePrice(oraclePrice);

        // Setup vault and deposit initial balance
        vm.startPrank(alice);
        ERC20PriceOracleReceiptVault vault = createVault(I_VAULT_ORACLE, "Test Token", "TST");

        vm.mockCall(
            address(I_ASSET),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, amount),
            abi.encode(true)
        );
        vm.expectCall(address(I_ASSET), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, amount));
        uint256 bobInitialBalance = vault.balanceOf(bob);

        uint256 expectedShares = amount.fixedPointMul(oraclePrice, Math.Rounding.Floor);
        vault.deposit(amount, alice, oraclePrice, bytes(""));

        assertTrue(vault.transfer(bob, expectedShares));

        // Check balances
        assertEqUint(bobInitialBalance, 0);
        assertEqUint(vault.balanceOf(bob), expectedShares);
    }

    // Test ERC20 allowance and approve
    function testERC20AllowanceAndApprove(uint256 aliceSeed, uint256 bobSeed, uint256 amount) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        amount = bound(amount, 1, type(uint256).max);

        ERC20PriceOracleReceiptVault vault = createVault(I_VAULT_ORACLE, "Test Token", "TST");

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
        uint256 oraclePrice
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        amount = bound(amount, 1, type(uint128).max);
        transferFromAmount = bound(transferFromAmount, 1, type(uint128).max);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        ERC20PriceOracleReceiptVault vault = createVault(I_VAULT_ORACLE, "Test Token", "TST");

        vm.startPrank(alice);
        vm.mockCall(
            address(I_ASSET),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, amount),
            abi.encode(true)
        );
        vm.expectCall(address(I_ASSET), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, amount));

        uint256 expectedShares = amount.fixedPointMul(oraclePrice, Math.Rounding.Floor);
        vm.assume(transferFromAmount < expectedShares);

        vault.deposit(amount, alice, oraclePrice, bytes(""));

        uint256 aliceBalanceBeforeTransfer = vault.balanceOf(alice);

        vault.approve(bob, expectedShares);

        vm.stopPrank();
        vm.startPrank(bob);

        // Bob transfers from Alice's account to his own
        assertTrue(vault.transferFrom(alice, bob, transferFromAmount));

        assertEqUint(vault.balanceOf(alice), aliceBalanceBeforeTransfer - transferFromAmount);
        assertEqUint(vault.balanceOf(bob), transferFromAmount);
    }

    // Test ERC20 increaseAllowance
    function testERC20IncreaseAllowance(uint256 aliceSeed, uint256 bobSeed, uint256 amount, uint256 increaseAmount)
        external
    {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        amount = bound(amount, 1, type(uint128).max);
        increaseAmount = bound(increaseAmount, 1, type(uint128).max);
        vm.assume(increaseAmount < amount);

        ERC20PriceOracleReceiptVault vault = createVault(I_VAULT_ORACLE, "Test Token", "TST");

        vm.startPrank(alice);
        vault.approve(bob, amount);

        IERC20(address(vault)).safeIncreaseAllowance(bob, increaseAmount);

        // Check that allowance increased correctly
        assertEq(vault.allowance(alice, bob), amount + increaseAmount);
    }

    // Test ERC20 decreaseAllowance
    function testERC20DecreaseAllowance(uint256 aliceSeed, uint256 bobSeed, uint256 amount, uint256 decreaseAmount)
        external
    {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        amount = bound(amount, 1, type(uint128).max);
        decreaseAmount = bound(decreaseAmount, 1, type(uint128).max);
        vm.assume(decreaseAmount < amount);

        ERC20PriceOracleReceiptVault vault = createVault(I_VAULT_ORACLE, "Test Token", "TST");

        vm.startPrank(alice);
        vault.approve(bob, amount);

        vault.decreaseAllowance(bob, decreaseAmount);

        // Check that allowance decreased correctly
        assertEq(vault.allowance(alice, bob), amount - decreaseAmount);
    }
}
