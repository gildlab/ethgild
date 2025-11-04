// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ReceiptVault,
    VaultConfig,
    ReceiptVaultConstructionConfigV2,
    ICloneableFactoryV2
} from "../../src/abstract/ReceiptVault.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {Receipt} from "../../src/concrete/receipt/Receipt.sol";
import {ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";

contract ConcreteReceiptVault is ReceiptVault {
    constructor()
        ReceiptVault(ReceiptVaultConstructionConfigV2({factory: new CloneFactory(), receiptImplementation: new Receipt()}))
    {}

    function initialize(bytes calldata data) external virtual override initializer returns (bytes32) {
        VaultConfig memory config = abi.decode(data, (VaultConfig));
        __ReceiptVault_init(config);
        return ICLONEABLE_V2_SUCCESS;
    }

    function factory() external view returns (ICloneableFactoryV2) {
        return I_FACTORY;
    }
}
