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

contract ERC20PriceOracleReceiptVaultRedeemTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Checks that balance owner balance changes after wirthdraw
    function checkBalanceChange(
        ERC20PriceOracleReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 shares,
        ReceiptContract receipt,
        bytes memory data
    ) internal {
        uint256 initialBalanceOwner = receipt.balanceOf(owner, id);
        uint256 assets = shares.fixedPointDiv(id, Math.Rounding.Down);

        // Set up the event expectation for WithdrawWithReceipt
        vm.expectEmit(true, true, true, true);
        emit IReceiptVaultV1.Withdraw(owner, receiver, owner, assets, shares, id, data);

        // Call redeem function
        vault.redeem(shares, receiver, owner, id, data);

        uint256 balanceAfterOwner = receipt.balanceOf(owner, id);
        assertEq(balanceAfterOwner, initialBalanceOwner - shares);
    }

    /// Checks that balance owner balance does not change after redeem revert
    function checkNoBalanceChange(
        ERC20PriceOracleReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 shares,
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
        // Call redeem function
        vault.redeem(shares, receiver, owner, id, data);

        if (owner != address(0)) {
            balanceAfterOwner = receipt.balanceOf(owner, id);
        }
        assertEq(balanceAfterOwner, initialBalanceOwner);
    }

    /// Test Redeem function
    function testRedeemBasic(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 assets,
        uint256 shares,
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

        // Bound shares with max avalilable receipt balance
        shares = bound(shares, 1, receipt.balanceOf(alice, oraclePrice));
        vm.assume(shares.fixedPointDiv(oraclePrice, Math.Rounding.Down) > 0);
        checkBalanceChange(vault, alice, alice, oraclePrice, shares, receipt, bytes(""));
    }

    /// Test Redeem function reverts on zero shares
    function testRedeemRevertsOnZeroShares(
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

    /// Test Redeem function reverts on zero receiver
    function testRedeemRevertsOnZeroReceiver(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 assets,
        uint256 shares,
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

        uint256 totalSupply = iAsset.totalSupply();

        assets = bound(assets, 1, totalSupply);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        // Ensure Alice has enough balance and allowance
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );

        vault.deposit(assets, alice, oraclePrice, bytes(""));

        shares = bound(shares, 1, receipt.balanceOf(alice, oraclePrice));
        vm.assume(shares.fixedPointDiv(oraclePrice, Math.Rounding.Down) > 0);

        checkNoBalanceChange(
            vault,
            address(0),
            alice,
            oraclePrice,
            shares,
            receipt,
            bytes(""),
            abi.encodeWithSelector(ZeroReceiver.selector)
        );
    }

    /// Test Redeem function reverts on zero owner
    function testRedeemRevertsOnZeroOwner(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 assets,
        uint256 shares,
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

        shares = bound(shares, 1, receipt.balanceOf(alice, oraclePrice));
        vm.assume(shares.fixedPointDiv(oraclePrice, Math.Rounding.Down) > 0);

        checkNoBalanceChange(
            vault,
            alice,
            address(0),
            oraclePrice,
            shares,
            receipt,
            bytes(""),
            abi.encodeWithSelector(ZeroOwner.selector)
        );
    }

    /// Test PreviewRedeem returns correct assets
    function testPreviewRedeem(uint256 fuzzedKeyAlice, string memory assetName, uint256 shares, uint256 oraclePrice)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        shares = bound(shares, 1, type(uint64).max);
        vm.assume(shares.fixedPointDiv(oraclePrice, Math.Rounding.Down) > 0);

        // Prank as Alice to grant role
        vm.startPrank(alice);
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        uint256 assets = shares.fixedPointDiv(oraclePrice, Math.Rounding.Down);

        uint256 ResultAssets = vault.previewRedeem(shares, oraclePrice);
        assertEq(assets, ResultAssets);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test Redeem function with more than balance
    function testRedeemMoreThanBalance(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 assets,
        uint256 sharesToRedeem,
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

        // Make sure sharesToRedeem is more than available balance
        sharesToRedeem = bound(sharesToRedeem, availableReceiptBalance + 1, type(uint256).max);
        checkNoBalanceChange(vault, alice, alice, oraclePrice, sharesToRedeem, receipt, bytes(""), bytes(""));
    }
}
