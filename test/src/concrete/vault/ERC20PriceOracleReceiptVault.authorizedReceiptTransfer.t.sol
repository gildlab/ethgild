// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {UnmanagedReceiptTransfer} from "src/interface/IReceiptManagerV2.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceipetVaultAuthorizedReceiptTransferTest is ERC20PriceOracleReceiptVaultTest {
    /// Test AuthorizeReceiptTransfer reverts if the caller is not the managed
    /// receipt.
    function testAuthorizeReceiptTransferRevert(
        uint256 aliceKey,
        uint256 bobKey,
        uint256 warpTimestamp,
        string memory assetName,
        string memory assetSymbol,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        // Generate unique addresses.
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, aliceKey, bobKey);

        // Bound warpTimestamp from 1 to avoid potential issues with timestamp 0.
        warpTimestamp = bound(warpTimestamp, 1, type(uint32).max);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        // Warp the block timestamp to a non-zero value.
        vm.warp(warpTimestamp);

        // Prank as receipt for the authorization.
        vm.startPrank(address(vault.receipt()));

        // Attempt to authorize receipt transfer, should NOT revert.
        vault.authorizeReceiptTransfer3(bob, alice, ids, amounts);

        vm.stopPrank();

        vm.startPrank(alice);
        // Attempt to authorize receipt transfer, should revert.
        vm.expectRevert(abi.encodeWithSelector(UnmanagedReceiptTransfer.selector));
        vault.authorizeReceiptTransfer3(bob, alice, ids, amounts);

        vm.stopPrank();
    }
}
