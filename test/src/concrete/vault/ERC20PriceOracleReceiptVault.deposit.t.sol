// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "src/abstract/ReceiptVault.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {TwoPriceOracleV2} from "src/concrete/oracle/TwoPriceOracleV2.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {IReceiptVaultV2, IReceiptVaultV1} from "src/interface/IReceiptVaultV2.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {LibERC20PriceOracleReceiptVaultFork} from "../../../lib/LibERC20PriceOracleReceiptVaultFork.sol";
import {SFLR_CONTRACT} from "rain.flare/lib/sflr/LibSceptreStakedFlare.sol";
import "forge-std/StdCheats.sol";

contract ERC20PriceOracleReceiptVaultDepositTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test deposit function
    function testDepositBasic(uint256 fuzzedKeyAlice, string memory assetName, uint256 assets, uint256 oraclePrice)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);

        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault;
        {
            vault = createVault(iVaultOracle, assetName, assetName);

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

        ReceiptContract receipt = getReceipt();
        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);
        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(alice, alice, assets, expectedShares, oraclePrice, bytes(""));

        vault.deposit(assets, alice, oraclePrice, bytes(""));

        // Assert that the total supply is equal to expectedShares
        assertEqUint(vault.totalSupply(), expectedShares);
        // Check alice balance
        assertEqUint(vault.balanceOf(alice), expectedShares);
        // Check bob's receipt balance
        assertEqUint(receipt.balanceOf(alice, oraclePrice), expectedShares);
    }

    /// Test deposit to someone else
    function testDepositSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);

        // Start recording logs to get receipt from ERC20PriceOracleReceiptVaultInitialized event
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault;
        {
            vault = createVault(iVaultOracle, assetName, assetName);

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
        ReceiptContract receipt = getReceipt();

        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        uint256 aliceReceiptBalance = receipt.balanceOf(alice, oraclePrice);
        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(alice, bob, assets, expectedShares, oraclePrice, bytes(""));

        vault.deposit(assets, bob, oraclePrice, bytes(""));
        // Assert that the total supply is equal to expectedShares
        assertEqUint(vault.totalSupply(), expectedShares);
        // Check balance
        assertEqUint(vault.balanceOf(bob), expectedShares);

        // Check bob's receipt balance
        assertEqUint(receipt.balanceOf(bob, oraclePrice), expectedShares);

        // Check alice's receipt balance does not change
        assertEqUint(receipt.balanceOf(alice, oraclePrice), aliceReceiptBalance);
    }

    /// Test deposit function with zero assets
    function testDepositWithZeroAssets(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 oraclePrice
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.deposit(0, alice, oraclePrice, data);
    }

    /// Test deposit reverts with incorret price
    function testDepositWithIncorrectPrice(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, oraclePrice + 1, oraclePrice));
        vault.deposit(assets, alice, oraclePrice + 1, data);
    }

    /// Test deposit reverts with zero receiver
    function testDepositWithZeroReceiver(
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        vm.expectRevert();
        vault.deposit(assets, address(0), oraclePrice, data);
    }

    /// Test PreviewDeposit returns correct shares
    function testPreviewDepositReturnedShares(
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        uint256 shares = vault.previewDeposit(assets, 0);

        assertEqUint(shares, expectedShares);

        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 1
    function testDepositFlareFork(uint256 deposit) public {
        deposit = bound(deposit, 1, type(uint128).max);

        (ERC20PriceOracleReceiptVault vault, address alice) = LibERC20PriceOracleReceiptVaultFork.setup(vm, deposit);

        deal(address(SFLR_CONTRACT), alice, deposit);

        vm.startPrank(alice);
        vm.assume(vault.previewDeposit(deposit, 0) > 0);

        vault.deposit(deposit, alice, 0, hex"00");
        vm.stopPrank();

        uint256 shareBalance = vault.balanceOf(alice);
        uint256 rate = LibERC20PriceOracleReceiptVaultFork.getRate();

        assertEqUint(deposit.fixedPointMul(rate, Math.Rounding.Down), shareBalance);
    }

    fallback() external {}
}
