// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../vault/receipt/IReceiptV1.sol";
import "../vault/receipt/IReceiptOwnerV1.sol";

error UnauthorizedTransfer(address from, address to);

contract TestReceiptOwner is IReceiptOwnerV1 {
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

    function setFrom(address from_) external {
        from = from_;
    }

    function setTo(address to_) external {
        to = to_;
    }

    function ownerMint(IReceiptV1 receipt_, address account_, uint256 id_, uint256 amount_, bytes memory data_) external {
        receipt_.ownerMint(account_, id_, amount_, data_);
    }

    function ownerBurn(IReceiptV1 receipt_, address account_, uint256 id_, uint256 amount_) external {
        receipt_.ownerBurn(account_, id_, amount_);
    }

    function ownerTransferFrom(IReceiptV1 receipt_, address from_, address to_, uint256 id_, uint256 amount_, bytes memory data_) external {
        receipt_.ownerTransferFrom(from_, to_, id_, amount_, data_);
    }
}
