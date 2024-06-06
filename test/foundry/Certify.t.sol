// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {OffchainAssetReceiptVault} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultFactory} from
    "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";

contract CertifyTest is Test, CreateOffchainAssetReceiptVaultFactory {
    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);

    function testCertify(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        uint256 fuzzedBlockNumber,
        bytes memory data
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        fuzzedBlockNumber = bound(fuzzedBlockNumber, 1, 1e6);
        certifyUntil = bound(certifyUntil, 1, fuzzedBlockNumber);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Grant CERTIFIER role to Alice
        vault.grantRole(vault.CERTIFIER(), alice);

        // Expect the Certify event
        vm.expectEmit(true, true, true, true);
        emit Certify(alice, certifyUntil, block.number, false, data);

        // Call the certify function
        vault.certify(certifyUntil, block.number, false, data);

        vm.stopPrank();
    }
}
