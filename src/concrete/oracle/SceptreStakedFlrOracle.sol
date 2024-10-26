// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {IPriceOracleV2} from "../../interface/IPriceOracleV2.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {LibSceptreStakedFlare} from "rain.flare/lib/sflr/LibSceptreStakedFlare.sol";

contract SceptreStakedFlrOracle is IPriceOracleV2 {
    /// @inheritdoc IPriceOracleV2
    function price() external payable override returns (uint256) {
        uint256 val = LibSceptreStakedFlare.getSFLRPerFLR18();
        Address.sendValue(payable(msg.sender), address(this).balance);
        return val;
    }

    /// Need to accept refunds from the oracle.
    fallback() external payable {}

    /// Need to accept refunds from the oracle.
    receive() external payable {}
}
