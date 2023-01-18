// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../vault/receipt/Receipt.sol";

error UnauthorizedTransfer(address from, address to);

contract TestReceipt is Receipt, IReceiptOwnerV1 {
    address internal from;
    address internal to;

    function authorizeReceiptTransfer(
        address from_,
        address to_
    ) external view {
        if (from_ != from) {
            revert UnauthorizedTransfer(from_, to_);
        }
        if (to_ != to) {
            revert UnauthorizedTransfer(from_, to_);
        }
    }

    function setOwner(address owner_) external {
        _transferOwnership(owner_);
    }

    function setFrom(address from_) external {
        from = from_;
    }

    function setTo(address to_) external {
        to = to_;
    }
}
