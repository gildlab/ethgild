// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
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
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {LibFork} from "rain.flare/../test/fork/LibFork.sol";
import {SFLR_CONTRACT} from "rain.flare/lib/sflr/LibSceptreStakedFlare.sol";
import {LibFtsoV2LTS, FLR_USD_FEED_ID} from "rain.flare/lib/lts/LibFtsoV2LTS.sol";
import {LibSceptreStakedFlare} from "rain.flare/lib/sflr/LibSceptreStakedFlare.sol";

contract ERC20PriceOracleReceiptVaultDepositTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test mint function
    function testMintBasic(uint256 fuzzedKeyAlice, string memory assetName, uint256 assets, uint256 oraclePrice)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);
        ERC20PriceOracleReceiptVault vault;
        {
            vault = createVault(iVaultOracle, assetName, assetName);

            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            assets = bound(assets, 1, type(uint128).max);
            vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
                abi.encode(true)
            );
        }
        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vault.mint(shares, alice, oraclePrice, bytes(""));

        // Check balance
        assertEqUint(vault.balanceOf(alice), shares);
    }

    /// Test mint to someone else
    function testMintSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        vm.startPrank(alice);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        {
            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            assets = bound(assets, 1, type(uint128).max);
            vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
                abi.encode(true)
            );
        }
        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vault.mint(shares, bob, oraclePrice, bytes(""));

        // Check balance
        assertEqUint(vault.balanceOf(bob), shares);
    }

    /// Test mint function with zero shares
    function testMintWithZeroShares(uint256 fuzzedKeyAlice, string memory assetName, uint256 oraclePrice) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.mint(0, alice, oraclePrice, bytes(""));
    }

    /// Test mint reverts with min price
    function testMintWithMinPrice(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        uint256 minPrice,
        uint256 oraclePrice
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        vm.assume(minPrice > oraclePrice);
        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, minPrice, oraclePrice));
        vault.mint(shares, alice, minPrice, bytes(""));
    }

    /// Test PreviewMint returns correct assets
    function testPreviewMintReturnedAssets(
        string memory assetName,
        string memory assetSymbol,
        uint256 shares,
        uint256 oraclePrice
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        shares = bound(shares, 1, type(uint64).max);
        vm.assume(shares.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        uint256 assets = shares.fixedPointDiv(oraclePrice, Math.Rounding.Up);

        uint256 resultAssets = vault.previewMint(shares, 0);

        assertEqUint(assets, resultAssets);

        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 1
    function testMintFlareFork(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);
        // Contract address on Flare
        ERC20PriceOracleReceiptVault vault =
            ERC20PriceOracleReceiptVault(payable(0xf0363b922299EA467d1E9c0F9c37d89830d9a4C4));
        // Sender address
        address alice = address(uint160(uint256(keccak256("ALICE"))));
        uint256 BLOCK_NUMBER = 31725348;
        vm.createSelectFork(LibFork.rpcUrlFlare(vm), BLOCK_NUMBER);
        // Fund Alice with `amount`
        deal(address(SFLR_CONTRACT), alice, amount);
        vm.startPrank(alice);
        // Approve an amount slightly larger than `amount` to avoid allowance issues
        IERC20(address(SFLR_CONTRACT)).approve(address(vault), amount + 1000);
        // Expected calculations based on rate (keeping previous calculations for consistency)
        uint256 usdPerFlr = LibFtsoV2LTS.ftsoV2LTSGetFeed(FLR_USD_FEED_ID, 60);
        uint256 sflrPerFlr = LibSceptreStakedFlare.getSFLRPerFLR18();
        uint256 rate = usdPerFlr.fixedPointDiv(sflrPerFlr, Math.Rounding.Up);
        uint256 shares = amount.fixedPointMul(rate, Math.Rounding.Down);
        // Execute mint
        vault.mint(shares, alice, 0, hex"00");
        vm.stopPrank();
        // Verify the balance of shares minted to Alice
        uint256 shareBalance = vault.balanceOf(alice);
        // Assert the calculated share balance
        assertEqUint(amount.fixedPointMul(rate, Math.Rounding.Down), shareBalance);
    }

    fallback() external {}
}
