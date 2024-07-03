// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "../../../../../contracts/abstract/ReceiptVault.sol";
import {ERC20PriceOracleReceiptVault} from "../../../../../contracts/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/foundry/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {TwoPriceOracle, TwoPriceOracleConfig} from "../../../../../contracts/oracle/price/TwoPriceOracle.sol";
import "forge-std/console.sol";

contract ERC20PriceOracleReceiptVaultDepositTest is ERC20PriceOracleReceiptVaultTest {
    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

    /// Test deposit function with zero assets
    function testDepositWithZeroAssets(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle();

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetSymbol);

        uint256 oraclePrice = twoPriceOracle.price();

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.deposit(0, alice, oraclePrice, data);
    }

    /// Test deposit reverts with incorret price
    function testDepositWithIncorrectPrice(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 assets
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle();
        assets = bound(assets, 1, type(uint256).max);
        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetSymbol);

        uint256 oraclePrice = twoPriceOracle.price();

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, oraclePrice + 1, oraclePrice));
        vault.deposit(assets, alice, oraclePrice + 1, data);
    }
}
