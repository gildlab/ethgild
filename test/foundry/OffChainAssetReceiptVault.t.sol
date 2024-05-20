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

        // Set up factory config
        ReceiptVaultFactoryConfig memory factoryConfig = ReceiptVaultFactoryConfig({
            implementation: address(implementation),
            receiptFactory: address(receiptFactory)
        });

        factory = new OffchainAssetReceiptVaultFactory(factoryConfig);
    }

    function test_Certify() public {
        // Get the first signer address
        address alice = vm.addr(1);
        // Get the current block number
        uint256 blockNum = block.number;

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        //VaultConfig to create child contract
        vaultConfig = VaultConfig(
            address(0),
            "Asset Name",
            "ASSET"
        );

        offchainAssetVaultConfig = OffchainAssetVaultConfig({
            admin: alice,
            vaultConfig: vaultConfig
        });

        vault = factory.createChildTyped(offchainAssetVaultConfig);

        vault.grantRole(vault.CERTIFIER(), alice);

//        vaultContract.balanceOf(msg.sender);//.grantRole(vaultContract.CERTIFIER(), msg.sender);
//        vm.expectEmit(true, true, true, true);

//        expected emitted event
//        emit Certify(msg.sender, 100, 10, false, abi.encodePacked("Certification data"));
//
        vault.certify(1719777599, blockNum, false, abi.encodePacked("Certification data"));

        vm.stopPrank();

    }
}
