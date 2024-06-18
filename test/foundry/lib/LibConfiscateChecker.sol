// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault} from "contracts/concrete/vault/OffchainAssetReceiptVault.sol";

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
}
