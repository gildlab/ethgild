// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {OffchainAssetReceiptVault} from "contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibOffchainAssetVaultCreator} from "../lib/LibOffchainAssetVaultCreator.sol";

contract OffchainAssetReceiptVaultTest is Test {
    ICloneableFactoryV2 internal immutable iFactory;
    OffchainAssetReceiptVault internal immutable iImplementation;

    constructor() {
        iFactory = new CloneFactory();
        iImplementation = new OffchainAssetReceiptVault();
    }

    function createVault(address admin, string memory name, string memory symbol)
        internal
        returns (OffchainAssetReceiptVault)
    {
        LibOffchainAssetVaultCreator.createVault(iFactory, iImplementation, admin, name, symbol);
    }
}
