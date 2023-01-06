// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Factory} from "@rainprotocol/rain-protocol/contracts/factory/Factory.sol";
import {ClonesUpgradeable as Clones} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {Receipt, ReceiptConfig} from "./Receipt.sol";

contract ReceiptFactory is Factory {
    address public immutable implementation;

    constructor() {
        address implementation_ = address(new Receipt());
        emit Implementation(msg.sender, implementation_);
        implementation = implementation_;
    }

    /// @inheritdoc Factory
    function _createChild(
        bytes memory data_
    ) internal virtual override returns (address) {
        ReceiptConfig memory config_ = abi.decode(data_, (ReceiptConfig));
        address clone_ = Clones.clone(implementation);
        Receipt(clone_).initialize(config_);
        Receipt(clone_).transferOwnership(msg.sender);
        return clone_;
    }

    /// Typed wrapper for `createChild` with Source.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ construction config for the `Receipt`.
    /// @return New `Receipt` child contract address.
    function createChildTyped(
        ReceiptConfig memory config_
    ) external returns (Receipt) {
        return Receipt(createChild(abi.encode(config_)));
    }
}
