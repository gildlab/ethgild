// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Receipt} from "./Receipt.sol";
import {Base64Upgradeable as Base64} from "openzeppelin-contracts-upgradeable/contracts/utils/Base64Upgradeable.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibFixedPointDecimalFormat} from "rain.math.fixedpoint/lib/format/LibFixedPointDecimalFormat.sol";
import {FIXED_POINT_ONE} from "rain.math.fixedpoint/lib/FixedPointDecimalConstants.sol";

/// @dev The SVG of Cyclo logo is pinned on IPFS.
string constant CYCLO_RECEIPT_SVG_URI = "ipfs://bafybeidjgkxfpk7nujlnx7jwvjvmtcbkfg53vnlc2cc6ftqfhapqkmtahq";

/// @dev The prefix for data URIs as base64 encoded JSON.
string constant DATA_URI_BASE64_PREFIX = "data:application/json;base64,";

contract CycloReceipt is Receipt {
    function uri(uint256 id) public view virtual override returns (string memory) {
        bytes memory json = abi.encodePacked(
            "{\"name\":\"Receipt for cyclo lock at ",
            LibFixedPointDecimalFormat.fixedPointToDecimalString(id),
            " USD per sFLR.\",\"description\":\"1 of these receipts can be burned alongside 1 cysFLR to redeem ",
            LibFixedPointDecimalFormat.fixedPointToDecimalString(
                id > 0
                    ? LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(FIXED_POINT_ONE, id, Math.Rounding.Down)
                    : 0
            ),
            " sFLR. Reedem at https://cyclo.finance.\",\"image\":\"",
            CYCLO_RECEIPT_SVG_URI,
            "\"}"
        );

        return string(abi.encodePacked(DATA_URI_BASE64_PREFIX, Base64.encode(json)));
    }
}
