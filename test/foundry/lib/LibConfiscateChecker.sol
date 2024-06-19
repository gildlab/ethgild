// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault} from "contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {Receipt as ReceiptContract} from "contracts/concrete/receipt/Receipt.sol";

library LibConfiscateChecker {
    /// Checks that balances don't change.
    function checkConfiscateSharesNoop(OffchainAssetReceiptVault vault, address alice, address bob, bytes memory data)
        internal
        returns (bool)
    {
        uint256 initialBalanceAlice = vault.balanceOf(alice);
        uint256 initialBalanceBob = vault.balanceOf(bob);

        vault.confiscateShares(alice, data);

        return initialBalanceAlice == vault.balanceOf(alice) && initialBalanceBob == vault.balanceOf(bob);
    }

    /// Checks that balances change.
    function checkConfiscateShares(OffchainAssetReceiptVault vault, address alice, address bob, bytes memory data)
        internal
        returns (bool)
    {
        uint256 initialBalanceAlice = vault.balanceOf(alice);
        uint256 initialBalanceBob = vault.balanceOf(bob);

        vault.confiscateShares(alice, data);

        return vault.balanceOf(alice) == 0 && vault.balanceOf(bob) == initialBalanceBob + initialBalanceAlice;
    }

    /// Checks that balances don't change.
    function checkConfiscateReceiptNoop(OffchainAssetReceiptVault vault, ReceiptContract receipt, address alice, address bob, uint256 id, bytes memory data)
        internal
        returns (bool)
    {

        uint256 initialBalanceAlice = receipt.balanceOf(alice, id);
        uint256 initialBalanceBob = receipt.balanceOf(bob, id);

        vault.confiscateReceipt(alice, id, data);

        uint256 balanceAfterAlice = receipt.balanceOf(alice, id);
        uint256 balanceAfterBob = receipt.balanceOf(bob, id);

        return initialBalanceAlice == balanceAfterAlice && initialBalanceBob == balanceAfterBob;
    }

    /// Checks that balances change.
    function checkConfiscateReceipt(OffchainAssetReceiptVault vault, ReceiptContract receipt, address alice, address bob, uint256 id, bytes memory data)
        internal
        returns (bool)
    {
        uint256 initialBalanceAlice = receipt.balanceOf(alice, id);
        uint256 initialBalanceBob = receipt.balanceOf(bob, id);

        vault.confiscateReceipt(alice, id, data);
        uint256 balanceAfterAlice = receipt.balanceOf(alice, id);
        uint256 balanceAfterBob = receipt.balanceOf(bob, id);

        return balanceAfterAlice == 0 && balanceAfterBob == initialBalanceBob + initialBalanceAlice;
    }
}
