// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {IPriceOracleV2} from "../../interface/IPriceOracleV2.sol";
import {LibFtsoV2LTS} from "rain.flare/lib/lts/LibFtsoV2LTS.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

struct FtsoV2LTSFeedOracleConfig {
    bytes21 feedId;
    uint256 staleAfter;
}

contract FtsoV2LTSFeedOracle is IPriceOracleV2 {
    event Construction(address sender, FtsoV2LTSFeedOracleConfig config);

    bytes21 public immutable iFeedId;
    uint256 public immutable iStaleAfter;

    constructor(FtsoV2LTSFeedOracleConfig memory config) {
        iFeedId = config.feedId;
        iStaleAfter = config.staleAfter;

        emit Construction(msg.sender, config);
    }

    /// @inheritdoc IPriceOracleV2
    function price() external payable override returns (uint256) {
        uint256 val = LibFtsoV2LTS.ftsoV2LTSGetFeed(iFeedId, iStaleAfter);
        Address.sendValue(payable(msg.sender), address(this).balance);
        return val;
    }
}
