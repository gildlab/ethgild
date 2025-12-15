// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ZeroReceiptImplementation,
    ZeroVaultImplementation,
    InitializeNonZeroReceipt,
    InitializeReceiptFailed,
    InitializeVaultFailed
} from "../../error/ErrDeployer.sol";
import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Receipt, ICLONEABLE_V2_SUCCESS} from "../receipt/Receipt.sol";
import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleReceiptVaultConfigV2
} from "../vault/ERC20PriceOracleReceiptVault.sol";

//forge-lint: disable-next-line(pascal-case-struct)
struct ERC20PriceOracleReceiptVaultCloneDeployerConfig {
    address receiptImplementation;
    address erc20PriceOracleReceiptVaultImplementation;
}

contract ERC20PriceOracleReceiptVaultCloneDeployer {
    address immutable I_RECEIPT_IMPLEMENTATION;
    address immutable I_ERC20_PRICE_ORACLE_RECEIPT_VAULT_IMPLEMENTATION;

    constructor(ERC20PriceOracleReceiptVaultCloneDeployerConfig memory config) {
        if (config.receiptImplementation == address(0)) revert ZeroReceiptImplementation();
        if (config.erc20PriceOracleReceiptVaultImplementation == address(0)) revert ZeroVaultImplementation();
        I_RECEIPT_IMPLEMENTATION = config.receiptImplementation;
        I_ERC20_PRICE_ORACLE_RECEIPT_VAULT_IMPLEMENTATION = config.erc20PriceOracleReceiptVaultImplementation;
    }

    function newERC20PriceOracleReceiptVault(ERC20PriceOracleReceiptVaultConfigV2 memory config)
        external
        returns (ERC20PriceOracleReceiptVault)
    {
        if (config.receiptVaultConfig.receipt != address(0)) {
            revert InitializeNonZeroReceipt(config.receiptVaultConfig.receipt);
        }

        Receipt receipt = Receipt(Clones.clone(I_RECEIPT_IMPLEMENTATION));
        ERC20PriceOracleReceiptVault erc20PriceOracleReceiptVault =
            ERC20PriceOracleReceiptVault(payable(Clones.clone(I_ERC20_PRICE_ORACLE_RECEIPT_VAULT_IMPLEMENTATION)));

        if (receipt.initialize(abi.encode(erc20PriceOracleReceiptVault)) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeReceiptFailed();
        }

        config.receiptVaultConfig.receipt = address(receipt);
        if (erc20PriceOracleReceiptVault.initialize(abi.encode(config)) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeVaultFailed();
        }

        return erc20PriceOracleReceiptVault;
    }
}
