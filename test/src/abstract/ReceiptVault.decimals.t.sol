// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ConcreteReceiptVault} from "test/concrete/ConcreteReceiptVault.sol";
import {TestErc20} from "test/concrete/TestErc20.sol";
import {ReceiptVaultConfigV2} from "src/abstract/ReceiptVault.sol";

import {Test} from "forge-std/Test.sol";

contract ReceiptVaultDecimalsTest is Test {
    function testDecimalsWithZeroAsset() external {
        ConcreteReceiptVault receiptVault = new ConcreteReceiptVault();
        uint8 decimals = receiptVault.decimals();
        assertEq(decimals, 18);
    }

    function testDecimalsWithNonZeroAsset(uint8 assetDecimals) external {
        ConcreteReceiptVault receiptVaultImplementation = new ConcreteReceiptVault();
        TestErc20 asset = new TestErc20();

        ConcreteReceiptVault receiptVault = ConcreteReceiptVault(
            payable(
                receiptVaultImplementation.factory().clone(
                    address(receiptVaultImplementation),
                    abi.encode(ReceiptVaultConfigV2({asset: address(asset), name: "Test Vault", symbol: "TVLT"}))
                )
            )
        );
        asset.setDecimals(assetDecimals);

        assertEq(receiptVault.asset(), address(asset));

        uint8 decimals = receiptVault.decimals();
        assertEq(decimals, assetDecimals);
    }
}
