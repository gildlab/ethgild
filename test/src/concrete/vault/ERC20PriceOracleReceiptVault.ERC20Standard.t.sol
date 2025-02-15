// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleReceiptVaultConfig
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceiptVaultERC20StandardTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test ERC20 name symbol and decimals
    function testERC20NameSymbolDecimals(uint256 aliceKey, string memory assetName, string memory assetSymbol)
        external
    {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, aliceKey);

        IPriceOracleV2 vaultPriceOracle =
            IPriceOracleV2(payable(address(uint160(uint256(keccak256("twoPriceOracle"))))));
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(vaultPriceOracle, assetName, assetSymbol);

        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));
        assertEq(vault.decimals(), 18);
    }

    /// Test ERC20 totalSupply and balanceOf
    function testERC20TotalSupplyAndBalanceOf(
        uint256 aliceKey,
        string memory assetName,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, aliceKey);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);
        {
            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            assets = bound(assets, 1, type(uint128).max);
            vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
                abi.encode(true)
            );
        }

        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);
        vault.deposit(assets, alice, oraclePrice, bytes(""));
        // Assert that the total supply is equal to expectedShares
        assertEqUint(vault.totalSupply(), expectedShares);
        // Check alice balance
        assertEqUint(vault.balanceOf(alice), expectedShares);
    }

    // Test ERC20 transfer
    function testERC20Transfer(uint256 aliceKey, uint256 bobKey, uint256 amount, uint256 oraclePrice) external {
        address alice = vm.addr((aliceKey % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((bobKey % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        vm.assume(amount.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        setVaultOraclePrice(oraclePrice);

        // Setup vault and deposit initial balance
        vm.startPrank(alice);
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Test Token", "TST");

        // Mock balance and allowance for deposit
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(amount));
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, amount),
            abi.encode(true)
        );
        uint256 bobInitialBalance = vault.balanceOf(bob);

        uint256 expectedShares = amount.fixedPointMul(oraclePrice, Math.Rounding.Down);
        vault.deposit(amount, alice, oraclePrice, bytes(""));

        vault.transfer(bob, expectedShares);

        // Check balances
        assertEqUint(bobInitialBalance, 0);
        assertEqUint(vault.balanceOf(bob), expectedShares);
    }

    // Test ERC20 allowance and approve
    function testERC20AllowanceAndApprove(uint256 aliceKey, uint256 bobKey, uint256 amount) external {
        address alice = vm.addr((aliceKey % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((bobKey % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        amount = bound(amount, 1, type(uint256).max);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Test Token", "TST");

        vm.startPrank(alice);
        // Set an allowance for Bob
        vault.approve(bob, amount);

        // Check allowance
        assertEq(vault.allowance(alice, bob), amount);
    }

    // Test ERC20 transferFrom()
    function testERC20TransferFrom(
        uint256 aliceKey,
        uint256 bobKey,
        uint256 amount,
        uint256 transferFromAmount,
        uint256 oraclePrice
    ) external {
        address alice = vm.addr((aliceKey % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((bobKey % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);
        transferFromAmount = bound(transferFromAmount, 1, type(uint128).max);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Test Token", "TST");

        vm.startPrank(alice);
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(amount));
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, amount),
            abi.encode(true)
        );

        uint256 expectedShares = amount.fixedPointMul(oraclePrice, Math.Rounding.Down);
        vm.assume(transferFromAmount < expectedShares);

        vault.deposit(amount, alice, oraclePrice, bytes(""));

        uint256 aliceBalanceBeforeTransfer = vault.balanceOf(alice);

        vault.approve(bob, expectedShares);

        vm.stopPrank();
        vm.startPrank(bob);

        // Bob transfers from Alice's account to his own
        vault.transferFrom(alice, bob, transferFromAmount);

        assertEqUint(vault.balanceOf(alice), aliceBalanceBeforeTransfer - transferFromAmount);
        assertEqUint(vault.balanceOf(bob), transferFromAmount);
    }

    // Test ERC20 increaseAllowance
    function testERC20IncreaseAllowance(uint256 aliceKey, uint256 bobKey, uint256 amount, uint256 increaseAmount)
        external
    {
        address alice = vm.addr((aliceKey % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((bobKey % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);
        increaseAmount = bound(increaseAmount, 1, type(uint128).max);
        vm.assume(increaseAmount < amount);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Test Token", "TST");

        vm.startPrank(alice);
        vault.approve(bob, amount);

        vault.increaseAllowance(bob, increaseAmount);

        // Check that allowance increased correctly
        assertEq(vault.allowance(alice, bob), amount + increaseAmount);
    }

    // Test ERC20 decreaseAllowance
    function testERC20DecreaseAllowance(uint256 aliceKey, uint256 bobKey, uint256 amount, uint256 decreaseAmount)
        external
    {
        address alice = vm.addr((aliceKey % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((bobKey % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);
        decreaseAmount = bound(decreaseAmount, 1, type(uint128).max);
        vm.assume(decreaseAmount < amount);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Test Token", "TST");

        vm.startPrank(alice);
        vault.approve(bob, amount);

        vault.decreaseAllowance(bob, decreaseAmount);

        // Check that allowance decreased correctly
        assertEq(vault.allowance(alice, bob), amount - decreaseAmount);
    }
}
