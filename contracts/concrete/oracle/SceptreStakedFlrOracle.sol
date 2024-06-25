// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {IPriceOracleV1} from "../../interface/IPriceOracleV1.sol";
import {IStakedFlr} from "../../interface/sceptre/IStakedFlr.sol";

contract SceptreStakedFlrOracle is IPriceOracleV1 {
    IStakedFlr public immutable iStakedFlr;

    constructor(IStakedFlr stakedFlr) {
        iStakedFlr = stakedFlr;
    }

    /// @inheritdoc IPriceOracleV1
    function price() external view override returns (uint256) {
        return iStakedFlr.getSharesByPooledFlr(1e18);
    }
}
