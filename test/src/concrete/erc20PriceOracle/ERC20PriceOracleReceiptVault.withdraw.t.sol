// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {TwoPriceOracle} from "src/concrete/oracle/TwoPriceOracle.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {ZeroAssetsAmount, ZeroReceiver, ZeroOwner} from "src/abstract/ReceiptVault.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV1.sol";

contract ERC20PriceOracleReceiptVaultWithdrawTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Checks that balance owner balance changes after wirthdraw
    function checkBalanceChange(
        ERC20PriceOracleReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 assets,
        ReceiptContract receipt,
        bytes memory data
    ) internal {
        uint256 initialBalanceOwner = receipt.balanceOf(owner, id);
        uint256 shares = assets.fixedPointMul(id, Math.Rounding.Up);

        vm.expectEmit(true, true, true, true);
        emit IReceiptVaultV1.Withdraw(owner, receiver, owner, assets, shares, id, data);

        // Call withdraw function
        vault.withdraw(assets, receiver, owner, id, data);

        uint256 balanceAfterOwner = receipt.balanceOf(owner, id);
        assertEq(balanceAfterOwner, initialBalanceOwner - shares);
    }

    /// Checks that balance owner balance does not change after wirthdraw revert
    function checkNoBalanceChange(
        ERC20PriceOracleReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 assets,
        ReceiptContract receipt,
        bytes memory data,
        bytes memory expectedRevertData
    ) internal {
        uint256 initialBalanceOwner;
        uint256 balanceAfterOwner;

        if (owner != address(0)) {
            initialBalanceOwner = receipt.balanceOf(owner, id);
        }

        // Check if expectedRevertData is provided
        if (expectedRevertData.length > 0) {
            vm.expectRevert(expectedRevertData);
        } else {
            vm.expectRevert();
        }
        // Call withdraw function
        vault.withdraw(assets, receiver, owner, id, data);

        if (owner != address(0)) {
            balanceAfterOwner = receipt.balanceOf(owner, id);
        }
        assertEq(balanceAfterOwner, initialBalanceOwner);
    }

    /// Test Withdraw function
    function testWithdrawBasic(uint256 fuzzedKeyAlice, string memory assetName, uint256 assets, uint256 oraclePrice)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);
        ReceiptContract receipt = getReceipt();

        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1e18));
        // Ensure Alice has enough balance and allowance
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

        uint256 totalSupply = iAsset.totalSupply();
        // Getting ZeroSharesAmount if bounded from 1
        assets = bound(assets, 2, totalSupply);
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );

        oraclePrice = bound(oraclePrice, 0.5e18, 2e18);
        setVaultOraclePrice(oraclePrice);

        vault.deposit(assets, alice, oraclePrice, bytes(""));
        uint256 withdrawAssets =
            assets.fixedPointMul(oraclePrice, Math.Rounding.Down).fixedPointDiv(oraclePrice, Math.Rounding.Down);
        checkBalanceChange(vault, alice, alice, oraclePrice, withdrawAssets, receipt, bytes(""));
    }

    /// Test Withdraw function reverts on zero assets
    function testWithdrawRevertsOnZeroAssets(
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
        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);
        ReceiptContract receipt = getReceipt();

        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1e18));
        // Ensure Alice has enough balance and allowance
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

        uint256 totalSupply = iAsset.totalSupply();

        assets = bound(assets, 1, totalSupply);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );

        vault.deposit(assets, alice, oraclePrice, bytes(""));

        checkNoBalanceChange(
            vault, alice, alice, oraclePrice, 0, receipt, bytes(""), abi.encodeWithSelector(ZeroAssetsAmount.selector)
        );
    }

    /// Test Withdraw function reverts on zero receiver
    function testWithdrawRevertsOnZeroReceiver(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);
        ReceiptContract receipt = getReceipt();

        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1e18));
        uint256 totalSupply = iAsset.totalSupply();
        // Getting ZeroSharesAmount if bounded from 1
        assets = bound(assets, 2, totalSupply);

        oraclePrice = bound(oraclePrice, 1e18, 2e18);
        setVaultOraclePrice(oraclePrice);

        // Ensure Alice has enough balance and allowance
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );

        vault.deposit(assets, alice, oraclePrice, bytes(""));
        uint256 availableReceiptBalance = receipt.balanceOf(alice, oraclePrice);

        checkNoBalanceChange(
            vault,
            address(0),
            alice,
            oraclePrice,
            availableReceiptBalance,
            receipt,
            bytes(""),
            abi.encodeWithSelector(ZeroReceiver.selector)
        );
    }

    /// Test Withdraw function reverts on zero owner
    function testWithdrawRevertsOnZeroOwner(
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
        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);
        ReceiptContract receipt = getReceipt();

        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1e18));
        // Ensure Alice has enough balance and allowance
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

        uint256 totalSupply = iAsset.totalSupply();

        assets = bound(assets, 1, totalSupply);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );

        vault.deposit(assets, alice, oraclePrice, bytes(""));
        uint256 availableReceiptBalance = receipt.balanceOf(alice, oraclePrice);

        checkNoBalanceChange(
            vault,
            alice,
            address(0),
            oraclePrice,
            availableReceiptBalance,
            receipt,
            bytes(""),
            abi.encodeWithSelector(ZeroOwner.selector)
        );
    }

    /// Test PreviewWithdraw returns correct shares
    function testPreviewWithdraw(uint256 fuzzedKeyAlice, string memory assetName, uint256 assets, uint256 oraclePrice)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        assets = bound(assets, 1, type(uint64).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        // Prank as Alice to grant role
        vm.startPrank(alice);
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        // Call withdraw function
        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Up);
        uint256 shares = vault.previewWithdraw(assets, oraclePrice);

        assertEq(shares, expectedShares);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test Withdraw function with more than assets deposied
    function testWithdrawMoreThanAssets(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 assets,
        uint256 assetsToWithdraw,
        uint256 oraclePrice
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);
        ReceiptContract receipt = getReceipt();

        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1e18));
        // Ensure Alice has enough balance and allowance
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

        uint256 totalSupply = iAsset.totalSupply();

        assets = bound(assets, 1, totalSupply);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );

        vault.deposit(assets, alice, oraclePrice, bytes(""));

        // Make sure assetsToWithdraw is more than assets
        assetsToWithdraw = bound(assetsToWithdraw, assets + 1, type(uint64).max);
        checkNoBalanceChange(vault, alice, alice, oraclePrice, assetsToWithdraw, receipt, bytes(""), bytes(""));
    }
}
