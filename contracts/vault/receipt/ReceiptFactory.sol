// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Factory} from "@rainprotocol/rain-protocol/contracts/factory/Factory.sol";
import {ClonesUpgradeable as Clones} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {Receipt} from "./Receipt.sol";

contract ReceiptFactory is Factory {
    address public immutable implementation;

    constructor() {
        address implementation_ = address(new Receipt());
        emit Implementation(msg.sender, implementation_);
        implementation = implementation_;
    }

    /// @inheritdoc Factory
    function _createChild(
        bytes memory
    ) internal virtual override returns (address) {
        address clone_ = Clones.clone(implementation);
        Receipt(clone_).initialize();
        Receipt(clone_).transferOwnership(msg.sender);
        return clone_;
    }
}
