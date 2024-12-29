// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {TestReceiptManager} from "test/concrete/TestReceiptManager.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {Base64} from "solady/utils/Base64.sol";
import {Receipt, DATA_URI_BASE64_PREFIX} from "src/concrete/receipt/Receipt.sol";
import {LibFixedPointDecimalFormat} from "rain.math.fixedpoint/lib/format/LibFixedPointDecimalFormat.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {FIXED_POINT_ONE} from "rain.math.fixedpoint/lib/FixedPointDecimalConstants.sol";

contract ReceiptMetadataTest is ReceiptFactoryTest {
    struct Metadata {
        uint8 decimals;
        string description;
        string name;
    }

    function testReceiptURI(uint256 id) external {
        vm.assume(id != 0);

        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt = createReceipt(address(testManager));

        string memory uri = receipt.uri(id);

        uint256 uriLength = bytes(uri).length;
        assembly ("memory-safe") {
            mstore(uri, 29)
        }
        assertEq(uri, DATA_URI_BASE64_PREFIX);
        assembly ("memory-safe") {
            uri := add(uri, 29)
            mstore(uri, sub(uriLength, 29))
        }

        string memory uriDecoded = string(Base64.decode(uri));
        bytes memory uriJsonData = vm.parseJson(uriDecoded);

        Metadata memory metadataJson = abi.decode(uriJsonData, (Metadata));

        string memory idInvFormatted = LibFixedPointDecimalFormat.fixedPointToDecimalString(
            LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(FIXED_POINT_ONE, id, Math.Rounding.Down)
        );
        assertEq(
            metadataJson.description,
            string.concat(
                "1 of these receipts can be burned alongside 1 TRM to redeem ", idInvFormatted, " of TRMAsset."
            )
        );

        assertEq(metadataJson.decimals, 18);
        assertEq(
            metadataJson.name,
            string.concat(
                "Receipt for lock at ", LibFixedPointDecimalFormat.fixedPointToDecimalString(id), " USD per TRMAsset."
            )
        );
    }

    function testReceiptName() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt = createReceipt(address(testManager));

        assertEq(receipt.name(), "TRM Receipt");
    }

    function testReceiptSymbol() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt = createReceipt(address(testManager));

        assertEq(receipt.symbol(), "TRM RCPT");
    }
}
