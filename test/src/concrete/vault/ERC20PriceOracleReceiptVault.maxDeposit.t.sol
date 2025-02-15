// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";

contract ERC20PriceOracleReceiptVaultMaxDepositTest is ERC20PriceOracleReceiptVaultTest {
    /// Test vault sets correct max deposit
    function testMaxDeposit(uint256 aliceKey, string memory assetName) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((aliceKey % (SECP256K1_ORDER - 1)) + 1);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        uint256 maxDeposit = vault.maxDeposit(alice);

        assertEqUint(maxDeposit, type(uint256).max);
    }
}
