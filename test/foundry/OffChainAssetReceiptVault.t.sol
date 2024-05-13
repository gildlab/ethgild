pragma solidity 0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";

import "forge-std/Test.sol";

import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

contract OffChainAssetReceiptVaultTest is Test {
    OffchainAssetReceiptVaultFactory factory;
    OffchainAssetVaultConfig offchainAssetVaultConfig;
    ReceiptVaultConfig receiptVaultConfig;
    VaultConfig vaultConfig;
    OffchainAssetReceiptVault implementation;
    ReceiptVault receiptVault;

    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);

    function setUp() public {
        implementation = new OffchainAssetReceiptVault();
        receiptVault = new ReceiptVault();

        vaultConfig = VaultConfig(
            address(0),
            "Asset Name",
            "ASSET"
        );

        receiptVaultConfig = ReceiptVaultConfig(
            address(receiptVault),
            vaultConfig
        );

        offchainAssetVaultConfig = OffchainAssetVaultConfig(
            address(0xc0D477556c25C9d67E1f57245C7453DA776B51cf),
            vaultConfig
        );

        factory = new OffchainAssetReceiptVaultFactory(ReceiptVaultFactoryConfig(address(implementation), address(receiptVault)));
    }

    function test_Certify() public {


        OffchainAssetReceiptVault child = factory.createChildTyped(offchainAssetVaultConfig);
        child.grantRole(child.CERTIFIER(), msg.sender);

//        vaultContract.balanceOf(msg.sender);//.grantRole(vaultContract.CERTIFIER(), msg.sender);
//        vm.expectEmit(true, true, true, true);

//        expected emitted event
//        emit Certify(msg.sender, 100, 10, false, abi.encodePacked("Certification data"));
//
//        vaultContract.certify(100, 10, false, abi.encodePacked("Certification data"));

    }
}
