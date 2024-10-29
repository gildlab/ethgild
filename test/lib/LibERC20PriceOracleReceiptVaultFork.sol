// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {LibFork} from "rain.flare/../test/fork/LibFork.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {Vm} from "forge-std/Vm.sol";
import {SFLR_CONTRACT} from "rain.flare/lib/sflr/LibSceptreStakedFlare.sol";

library LibERC20PriceOracleReceiptVaultFork {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    function setup(Vm vm, uint256 amount) internal returns (ERC20PriceOracleReceiptVault, address) {
        address alice = address(uint160(uint256(keccak256("ALICE"))));

        // Contract address on Flare
        ERC20PriceOracleReceiptVault vault =
            ERC20PriceOracleReceiptVault(payable(0xf0363b922299EA467d1E9c0F9c37d89830d9a4C4));

        uint256 BLOCK_NUMBER = 31725348;

        vm.createSelectFork(LibFork.rpcUrlFlare(vm), BLOCK_NUMBER);

        vm.startPrank(alice);

        IERC20(address(SFLR_CONTRACT)).approve(payable(vault), amount);
        return (vault, alice);
    }
}
