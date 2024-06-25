// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {IPriceOracleV1} from "../../interface/IPriceOracleV1.sol";
import {LibFtsoCurrentPriceUsd} from "rain.flare/src/lib/price/LibFtsoCurrentPriceUsd.sol";
import {LibIntOrAString, IntOrAString} from "rain.intorastring/lib/LibIntOrAString.sol";

struct FtsoCurrentPriceUsdOracleConfig {
    string symbol;
    uint256 staleAfter;
}

contract FtsoCurrentPriceUsdOracle is IPriceOracleV1 {
    event Construction(address sender, FtsoCurrentPriceUsdOracleConfig config);

    IntOrAString public immutable iSymbol;
    uint256 public immutable iStaleAfter;

    constructor(FtsoCurrentPriceUsdOracleConfig memory config) {
        iSymbol = LibIntOrAString.fromString2(config.symbol);
        iStaleAfter = config.staleAfter;

        emit Construction(msg.sender, config);
    }

    /// @inheritdoc IPriceOracleV1
    function price() external view override returns (uint256) {
        return LibFtsoCurrentPriceUsd.ftsoCurrentPriceUsd(LibIntOrAString.toString(iSymbol), iStaleAfter);
    }
}
