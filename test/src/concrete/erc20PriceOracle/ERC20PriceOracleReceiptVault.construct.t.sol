// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {ReceiptVaultConfig, VaultConfig} from "src/abstract/ReceiptVault.sol";
import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleReceiptVaultConfig
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {TwoPriceOracle} from "src/concrete/oracle/TwoPriceOracle.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceiptVaultConstructionTest is ERC20PriceOracleReceiptVaultTest {
    /// Test ERC20PriceOracleReceiptVault is constracted
    function testCheckConstructionEvent(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        // Start recording logs
        vm.recordLogs();

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetSymbol);
        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Note: To use vm.expectEmit receipt address is needed to be known.
        // Find the OffchainAssetReceiptVaultInitialized event log
        address msgSender = address(0);
        address priceOracle = address(0);
        address assetAddress = address(0);
        string memory name = "";
        string memory symbol = "";
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ERC20PriceOracleReceiptVaultInitialized(address,(address,(address,(address,string,string))))"
                    )
            ) {
                // Decode the event data
                (address sender, ERC20PriceOracleReceiptVaultConfig memory config) =
                    abi.decode(logs[i].data, (address, ERC20PriceOracleReceiptVaultConfig));
                msgSender = sender;
                priceOracle = config.priceOracle;
                name = config.receiptVaultConfig.vaultConfig.name;
                symbol = config.receiptVaultConfig.vaultConfig.symbol;
                assetAddress = address(config.receiptVaultConfig.vaultConfig.asset);
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }
        // Assert that the event log was found
        assertTrue(eventFound, "ERC20PriceOracleReceiptVaultInitialized event log not found");

        assertEq(msgSender, address(iFactory));
        assertEq(priceOracle, address(twoPriceOracle));
        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(name)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(symbol)));
    }

    /// Test creating several different vaults
    function testCreatingSeveralVaults(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 timestamp,
        string memory assetName,
        string memory assetSymbol,
        string memory assetNameTwo,
        string memory assetSymbolTwo,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));
        timestamp = bound(timestamp, 0, type(uint32).max);

        // Simulate transaction from alice
        vm.prank(alice);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetSymbol);

        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));

        // Simulate transaction from alice
        vm.prank(bob);

        ERC20PriceOracleReceiptVault vaultTwo = createVault(address(twoPriceOracle), assetNameTwo, assetSymbolTwo);

        assert(address(vaultTwo) != address(0));
        assertEq(keccak256(bytes(vaultTwo.name())), keccak256(bytes(assetNameTwo)));
        assertEq(keccak256(bytes(vaultTwo.symbol())), keccak256(bytes(assetSymbolTwo)));
    }
}
