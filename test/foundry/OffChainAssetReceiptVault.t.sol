pragma solidity 0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";
import "../../contracts/vault/receipt/ReceiptFactory.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

contract OffChainAssetReceiptVaultTest is Test {
    OffchainAssetReceiptVaultFactory factory;
    OffchainAssetVaultConfig offchainAssetVaultConfig;
    VaultConfig vaultConfig;
    OffchainAssetReceiptVault implementation;
    OffchainAssetReceiptVault vault;
    ReceiptFactory receiptFactory;

    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);

    function setUp() public {
        implementation = new OffchainAssetReceiptVault();
        receiptFactory = new ReceiptFactory();

        vaultConfig = VaultConfig(
            address(0),
            "Asset Name",
            "ASSET"
        );

        offchainAssetVaultConfig = OffchainAssetVaultConfig(
            address (msg.sender),
            vaultConfig
        );

        // Set up factory config
        ReceiptVaultFactoryConfig memory factoryConfig = ReceiptVaultFactoryConfig({
            implementation: address(implementation),
            receiptFactory: address(receiptFactory)
        });

        factory = new OffchainAssetReceiptVaultFactory(factoryConfig);
        vault = factory.createChildTyped(offchainAssetVaultConfig);


    }

    function test_Certify() public {

//        vault = factory.createChildTyped(offchainAssetVaultConfig);

//        vault.grantRole(vault.CERTIFIER(), msg.sender);

//        vaultContract.balanceOf(msg.sender);//.grantRole(vaultContract.CERTIFIER(), msg.sender);
//        vm.expectEmit(true, true, true, true);

//        expected emitted event
//        emit Certify(msg.sender, 100, 10, false, abi.encodePacked("Certification data"));
//
//        vaultContract.certify(100, 10, false, abi.encodePacked("Certification data"));

    }
}
