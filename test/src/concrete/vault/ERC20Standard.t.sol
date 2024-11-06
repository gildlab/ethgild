// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
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
import "forge-std/console.sol";

contract ERC20StandardTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test ERC20 name symbol and decimals
    function testERC20NameSymbolDecimals(uint256 fuzzedKeyAlice, string memory assetName, string memory assetSymbol)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

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
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

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
    function testERC20Transfer(uint256 fuzzedKeyAlice, uint256 fuzzedKeyBob, uint256 amount, uint256 oraclePrice)
        external
    {
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
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
    function testERC20AllowanceAndApprove(uint256 fuzzedKeyAlice, uint256 fuzzedKeyBob, uint256 amount) external {
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        amount = bound(amount, 1, type(uint256).max);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Test Token", "TST");

        vm.startPrank(alice);
        // Set an allowance for Bob
        vault.approve(bob, amount);

        // Check allowance
        assertEq(vault.allowance(alice, bob), amount);
    }
}
