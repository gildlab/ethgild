// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "../../../../../contracts/abstract/ReceiptVault.sol";
import {ERC20PriceOracleReceiptVault} from "../../../../../contracts/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/foundry/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {TwoPriceOracle, TwoPriceOracleConfig} from "../../../../../contracts/oracle/price/TwoPriceOracle.sol";

contract ERC20PriceOracleReceiptVaultDepositTest is ERC20PriceOracleReceiptVaultTest {
    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

    /// Test deposit function with zero assets
    function testDepositWithZeroAssets(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle();

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetSymbol);

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.deposit(0, bob);
    }
}
