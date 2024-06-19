// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault} from "contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {Receipt as ReceiptContract} from "contracts/concrete/receipt/Receipt.sol";

library LibConfiscateChecker {
    /// Checks that balances change.
    function checkConfiscateReceipt(
        OffchainAssetReceiptVault vault,
        ReceiptContract receipt,
        address alice,
        address bob,
        uint256 id,
        bytes memory data
    ) internal returns (bool) {
        uint256 initialBalanceAlice = receipt.balanceOf(alice, id);
        uint256 initialBalanceBob = receipt.balanceOf(bob, id);

        vault.confiscateReceipt(alice, id, data);
        uint256 balanceAfterAlice = receipt.balanceOf(alice, id);
        uint256 balanceAfterBob = receipt.balanceOf(bob, id);

        return balanceAfterAlice == 0 && balanceAfterBob == initialBalanceBob + initialBalanceAlice;
    }
}
