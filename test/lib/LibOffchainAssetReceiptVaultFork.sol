// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibFork} from "rain.flare/../test/fork/LibFork.sol";
import {Math} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {Vm} from "forge-std/Vm.sol";

library LibOffchainAssetReceiptVaultFork {
    function setup(Vm vm) internal returns (OffchainAssetReceiptVault, address) {
        address alice = address(0xc0D477556c25C9d67E1f57245C7453DA776B51cf);

        // Contract address on Arbitrum Sepolia
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(payable(0xb012B4DE7b960A537ed485771278Ba222c56Aff3));

        // Use an environment variable for the RPC URL
        string memory rpcURL = vm.envString("RPC_URL_ARBITRUM_SEPOLIA_FORK");
        uint256 BLOCK_NUMBER = 96365164;

        vm.createSelectFork(rpcURL, BLOCK_NUMBER);

        return (vault, alice);
    }
}
