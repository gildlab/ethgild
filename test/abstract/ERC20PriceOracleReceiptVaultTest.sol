// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    ERC20PriceOracleReceiptVault,
    ReceiptVaultConstructionConfigV2,
    ERC20PriceOracleReceiptVaultConfig
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {LibERC20PriceOracleReceiptVaultCreator} from "../lib/LibERC20PriceOracleReceiptVaultCreator.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";

contract ERC20PriceOracleReceiptVaultTest is Test {
    ICloneableFactoryV2 internal immutable I_FACTORY;
    ERC20PriceOracleReceiptVault internal immutable I_IMPLEMENTATION;
    ReceiptContract internal immutable I_RECEIPT_IMPLEMENTATION;
    IERC20 immutable I_ASSET;
    IPriceOracleV2 immutable I_VAULT_ORACLE;

    constructor() {
        I_FACTORY = new CloneFactory();
        I_RECEIPT_IMPLEMENTATION = new ReceiptContract();
        I_IMPLEMENTATION = new ERC20PriceOracleReceiptVault(
            ReceiptVaultConstructionConfigV2({factory: I_FACTORY, receiptImplementation: I_RECEIPT_IMPLEMENTATION})
        );
        I_ASSET = IERC20(address(uint160(uint256(keccak256("asset.test")))));
        I_VAULT_ORACLE = IPriceOracleV2(payable(address(uint160(uint256(keccak256("vault.oracle"))))));
    }

    function setVaultOraclePrice(uint256 oraclePrice) internal {
        vm.mockCall(
            address(I_VAULT_ORACLE), abi.encodeWithSelector(IPriceOracleV2.price.selector), abi.encode(oraclePrice)
        );
    }

    function createVault(IPriceOracleV2 priceOracle, string memory name, string memory symbol)
        internal
        returns (ERC20PriceOracleReceiptVault)
    {
        ERC20PriceOracleReceiptVault vault = LibERC20PriceOracleReceiptVaultCreator.createVault(
            I_FACTORY, I_IMPLEMENTATION, priceOracle, address(I_ASSET), name, symbol
        );
        return vault;
    }

    /// Get Receipt from event
    function getReceipt() internal view returns (ReceiptContract) {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the ERC20PriceOracleReceiptVaultInitialized event log
        address receiptAddress = address(0);
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ERC20PriceOracleReceiptVault.ERC20PriceOracleReceiptVaultInitialized.selector) {
                // Decode the event data
                (, ERC20PriceOracleReceiptVaultConfig memory config) =
                    abi.decode(logs[i].data, (address, ERC20PriceOracleReceiptVaultConfig));
                receiptAddress = config.receiptVaultConfig.receipt;
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }
        // Assert that the event log was found
        assertTrue(eventFound, "ERC20PriceOracleReceiptVaultInitialized event log not found");
        // Return an receipt contract
        return ReceiptContract(receiptAddress);
    }
}
