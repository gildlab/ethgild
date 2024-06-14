// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {IPriceOracleV1} from "../../interface/IPriceOracleV1.sol";
import {LibFtsoCurrentPriceUsd} from "rain.flare/src/lib/price/LibFtsoCurrentPriceUsd.sol";

contract FlareFTSOOracle is IPriceOracleV1 {
    /// @inheritdoc IPriceOracleV1
    function price() external view override returns (uint256) {
        return LibFtsoCurrentPriceUsd.ftsoCurrentPriceUsd("FLR", 300);
    }
}
