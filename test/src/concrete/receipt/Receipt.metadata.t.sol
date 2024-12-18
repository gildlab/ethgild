// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {TestReceiptManager} from "test/concrete/TestReceiptManager.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {Base64} from "solady/utils/Base64.sol";
import {
    Receipt,
    RECEIPT_METADATA_DATA_URI,
    DATA_URI_BASE64_PREFIX,
    RECEIPT_NAME,
    RECEIPT_SYMBOL
} from "src/concrete/receipt/Receipt.sol";

contract ReceiptMetadataTest is ReceiptFactoryTest {
    struct Metadata {
        uint8 decimals;
        string description;
        string name;
    }

    function testReceiptURI(uint256 id) external {
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
        assertEq(uri, RECEIPT_METADATA_DATA_URI);

        string memory uriDecoded = string(Base64.decode(uri));
        bytes memory uriJsonData = vm.parseJson(uriDecoded);

        Metadata memory metadataJson = abi.decode(uriJsonData, (Metadata));
        assertEq(metadataJson.description, "A receipt for a ReceiptVault.");
        assertEq(metadataJson.decimals, 18);
        assertEq(metadataJson.name, RECEIPT_NAME);
    }

    function testReceiptName() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt = createReceipt(address(testManager));

        assertEq(receipt.name(), RECEIPT_NAME);
    }

    function testReceiptSymbol() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt = createReceipt(address(testManager));

        assertEq(receipt.symbol(), RECEIPT_SYMBOL);
    }
}
