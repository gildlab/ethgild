// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {IPriceOracleV2} from "../../interface/IPriceOracleV2.sol";
import {IStakedFlr} from "rain.flare/interface/IStakedFlr.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

contract SceptreStakedFlrOracle is IPriceOracleV2 {
    IStakedFlr public immutable iStakedFlr;

    constructor(IStakedFlr stakedFlr) {
        iStakedFlr = stakedFlr;
    }

    /// @inheritdoc IPriceOracleV2
    function price() external payable override returns (uint256) {
        uint256 val = iStakedFlr.getSharesByPooledFlr(1e18);
        Address.sendValue(payable(msg.sender), address(this).balance);
        return val;
    }
}
