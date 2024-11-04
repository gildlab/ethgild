// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {Base64} from "solady/utils/Base64.sol";
import {CycloReceipt, DATA_URI_BASE64_PREFIX, CYCLO_RECEIPT_SVG_URI} from "src/concrete/receipt/CycloReceipt.sol";

contract CycloReceiptMetadataTest is Test {
    struct URIJson {
        string description;
        string image;
        string name;
    }

    function testCycloReceiptURI() external {
        CycloReceipt receipt = new CycloReceipt();

        string memory uri = receipt.uri(0.01544e18);
        uint256 uriLength = bytes(uri).length;
        assembly ("memory-safe") {
            mstore(uri, 29)
        }
        assertEq(uri, DATA_URI_BASE64_PREFIX);
        assembly ("memory-safe") {
            uri := add(uri, 29)
            mstore(uri, sub(uriLength, 29))
        }

        bytes memory uriDecoded = Base64.decode(uri);
        bytes memory uriJsonData = vm.parseJson(string(uriDecoded));

        URIJson memory uriJson = abi.decode(uriJsonData, (URIJson));
        assertEq(
            uriJson.description,
            "1 of these receipts can be burned alongside 1 cysFLR to redeem 64.766839378238341968 sFLR. Reedem at https://cyclo.finance."
        );
        assertEq(uriJson.image, CYCLO_RECEIPT_SVG_URI);
        assertEq(uriJson.name, "Receipt for cyclo lock at 0.01544 USD per sFLR.");
    }
}
