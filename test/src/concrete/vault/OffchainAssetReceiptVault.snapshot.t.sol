// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest, Vm} from "../../../abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

contract SnapshotTest is OffchainAssetReceiptVaultTest {
    event Snapshot(uint256 id);
    event SnapshotWithData(address sender, uint256 id, bytes data);

    /// Test to checks Snapshot events are emitted
    function testSnapshot(uint256 fuzzedKeyAlice, bytes memory data, string memory assetName, string memory assetSymbol)
        external
    {
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.ERC20SNAPSHOTTER(), alice);

        // Expect the Snapshot and SnapshotWithData events
        vm.expectEmit(false, false, false, true);
        emit Snapshot(1);

        vm.expectEmit(false, false, false, true);
        emit SnapshotWithData(alice, 1, data);

        uint256 snapshotId = vault.snapshot(data);

        // Ensure the snapshotId is as expected
        assertEq(snapshotId, 1);

        vm.stopPrank();
    }

    /// Test to checks id increases on multiple Snapshot
    function testMultipleSnapshot(
        uint256 fuzzedKeyAlice,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.ERC20SNAPSHOTTER(), alice);

        // Expect the Snapshot and SnapshotWithData events
        vm.expectEmit(false, false, false, true);
        emit Snapshot(1);

        vm.expectEmit(false, false, false, true);
        emit SnapshotWithData(alice, 1, data);

        uint256 snapshotId = vault.snapshot(data);

        // Ensure the snapshotId is as expected
        assertEq(snapshotId, 1);

        // Expect the Snapshot and SnapshotWithData events
        vm.expectEmit(false, false, false, true);
        emit Snapshot(2);

        vm.expectEmit(false, false, false, true);
        emit SnapshotWithData(alice, 2, data);

        snapshotId = vault.snapshot(data);

        // Ensure the snapshotId is as expected
        assertEq(snapshotId, 2);

        vm.stopPrank();
    }
}
