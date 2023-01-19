// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../vault/receipt/Receipt.sol";

/// @title TestReceipt
/// @notice TEST contract that inherits `Receipt` and allows anon to set the
/// owner arbitrarily. Entirely insecure.
contract TestReceipt is Receipt {
    /// Anon can set the owner.
    /// @param owner_ The new owner.
    function setOwner(address owner_) external {
        _transferOwnership(owner_);
    }
}
