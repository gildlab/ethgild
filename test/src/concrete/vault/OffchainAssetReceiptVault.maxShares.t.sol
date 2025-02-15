// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceiptVaultMaxSharesTest is OffchainAssetReceiptVaultTest {
    /// Test vault sets correct max Mint
    function testMaxShares(uint256 aliceKey, string memory assetName) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddress(vm, SECP256K1_ORDER, aliceKey);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);

        vm.startPrank(alice);
        uint256 maxMint = vault.maxMint(alice);

        assertEqUint(maxMint, type(uint256).max);
    }
}
