pragma solidity 0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";

import "forge-std/Test.sol";

import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

contract OffChainAssetReceiptVaultTest is Test {
    OffchainAssetReceiptVaultFactory factory;
    OffchainAssetVaultConfig offchainAssetVaultConfig;
    VaultConfig vaultConfig;
    OffchainAssetReceiptVault implementation;
    ReceiptVault receiptVault;
    OffchainAssetReceiptVault vault;

    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);

    function setUp() public {
        implementation = new OffchainAssetReceiptVault();
        receiptVault = new ReceiptVault();

        vaultConfig = VaultConfig(
            address(0),
            "Asset Name",
            "ASSET"
        );

        offchainAssetVaultConfig = OffchainAssetVaultConfig(
            msg.sender,
            vaultConfig
        );

        factory = new OffchainAssetReceiptVaultFactory(ReceiptVaultFactoryConfig(address(implementation), address(receiptVault)));
        vault = factory.createChildTyped(offchainAssetVaultConfig);

    }

    function test_Certify() public {


//        vault.grantRole(vault.CERTIFIER(), msg.sender);

//        vaultContract.balanceOf(msg.sender);//.grantRole(vaultContract.CERTIFIER(), msg.sender);
//        vm.expectEmit(true, true, true, true);

//        expected emitted event
//        emit Certify(msg.sender, 100, 10, false, abi.encodePacked("Certification data"));
//
//        vaultContract.certify(100, 10, false, abi.encodePacked("Certification data"));

    }
}
