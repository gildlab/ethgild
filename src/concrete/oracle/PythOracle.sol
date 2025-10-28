// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {PriceOracleV2} from "../../abstract/PriceOracleV2.sol";
import {IPyth} from "pyth-sdk/IPyth.sol";
import {PythStructs} from "pyth-sdk/PythStructs.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

error NonPositivePrice(int256 price);

contract PythOracle is PriceOracleV2 {
    bytes32 public immutable I_PRICE_FEED_ID;
    uint256 public immutable I_STALE_AFTER;
    IPyth public immutable I_PYTH_CONTRACT;

    function _price() internal virtual override returns (uint256) {
        PythStructs.Price memory price = I_PYTH_CONTRACT.getPriceNoOlderThan(I_PRICE_FEED_ID, I_STALE_AFTER);
        int256 conservativePrice = int256(price.price) - int256(uint256(price.conf));
        if (conservativePrice <= 0) {
            revert NonPositivePrice(price.price);
        }
        // It is safe to pack lossless here because the price data uses only
        // 64 bits while we have 224 bits for a packed signed coefficient, and
        // the exponent bit size is the same for both.
        Float conservativePriceFloat = LibDecimalFloat.packLossless(conservativePrice, price.expo);
        // We ignore precision loss here, truncating towards zero.
        (uint256 price18,) = LibDecimalFloat.toFixedDecimalLossy(conservativePriceFloat, 18);
        return price18;
    }
}
