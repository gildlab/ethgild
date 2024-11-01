// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import "src/concrete/receipt/Receipt.sol";

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
