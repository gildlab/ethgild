// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../vault/receipt/Receipt.sol";

error UnauthorizedTransfer(address from, address to);

contract TestReceipt is Receipt {
    function setOwner(address owner_) external {
        _transferOwnership(owner_);
    }
}
