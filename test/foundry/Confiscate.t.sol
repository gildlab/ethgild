// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {OffchainAssetReceiptVault} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";

contract Confiscate is Test, CreateOffchainAssetReceiptVaultFactory {
    event ConfiscateShares(address sender, address confiscatee, uint256 confiscated, bytes justification);

    /// Test to checks ConfiscateShares is NOT emitted on zero balance
    function testConfiscateOnZeroBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory justification
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.CONFISCATOR(), alice);

        // Stop recording logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vault.confiscateShares(bob, justification);

        // Check the logs to ensure event is not present
        bool eventFound = false;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ConfiscateShares.selector) {
                eventFound = true;
                break;
            }
        }

        assertFalse(eventFound, "ConfiscateShares event should not be emitted");
        vm.stopPrank();
    }
}
