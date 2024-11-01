// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    ERC20PriceOracleReceiptVault,
    ReceiptVaultConstructionConfig,
    ERC20PriceOracleReceiptVaultConfig
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {LibERC20PriceOracleReceiptVaultCreator} from "../lib/LibERC20PriceOracleReceiptVaultCreator.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {TwoPriceOracleV2, TwoPriceOracleConfigV2} from "src/concrete/oracle/TwoPriceOracleV2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";

contract ERC20PriceOracleReceiptVaultTest is Test {
    event ERC20PriceOracleReceiptVaultInitialized(address sender, ERC20PriceOracleReceiptVaultConfig config);

    ICloneableFactoryV2 internal immutable iFactory;
    ERC20PriceOracleReceiptVault internal immutable iImplementation;
    ReceiptContract internal immutable iReceiptImplementation;
    IERC20 immutable iAsset;
    IPriceOracleV2 immutable iVaultOracle;

    constructor() {
        iFactory = new CloneFactory();
        iReceiptImplementation = new ReceiptContract();
        iImplementation = new ERC20PriceOracleReceiptVault(
            ReceiptVaultConstructionConfig({factory: iFactory, receiptImplementation: iReceiptImplementation})
        );
        iAsset = IERC20(address(uint160(uint256(keccak256("asset.test")))));
        iVaultOracle = IPriceOracleV2(payable(address(uint160(uint256(keccak256("vault.oracle"))))));
    }

    function setVaultOraclePrice(uint256 oraclePrice) internal {
        vm.mockCall(
            address(iVaultOracle), abi.encodeWithSelector(IPriceOracleV2.price.selector), abi.encode(oraclePrice)
        );
    }

    function createVault(IPriceOracleV2 priceOracle, string memory name, string memory symbol)
        internal
        returns (ERC20PriceOracleReceiptVault)
    {
        ERC20PriceOracleReceiptVault vault = LibERC20PriceOracleReceiptVaultCreator.createVault(
            iFactory, iImplementation, priceOracle, address(iAsset), name, symbol
        );
        return vault;
    }

    /// Get Receipt from event
    function getReceipt() internal returns (ReceiptContract) {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the ERC20PriceOracleReceiptVaultInitialized event log
        address receiptAddress = address(0);
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ERC20PriceOracleReceiptVaultInitialized.selector) {
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
