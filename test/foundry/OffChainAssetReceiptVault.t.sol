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
    address alice;

    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);

    function setUp() public {
        implementation = new OffchainAssetReceiptVault();
        receiptFactory = new ReceiptFactory();

        // Set up factory config
        ReceiptVaultFactoryConfig memory factoryConfig = ReceiptVaultFactoryConfig({
            implementation: address(implementation),
            receiptFactory: address(receiptFactory)
        });

        // Create OffchainAssetReceiptVaultFactory contract
        factory = new OffchainAssetReceiptVaultFactory(factoryConfig);
        // Get the first signer address
        alice = vm.addr(1);

        // VaultConfig to create child contract
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
    }

    function test_Certify() public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Grant CERTIFIER role to Alice
        vault.grantRole(vault.CERTIFIER(), alice);

        // Get the current block number
        uint256 blockNum = block.number;

        // Set up expected parameters
        uint256 certifyUntil = 1719777599;
        bool forceUntil = false;
        bytes memory data = abi.encodePacked("Certification data");

        // Expect the Certify event
        vm.expectEmit(true, true, true, true);
        emit Certify(alice, certifyUntil, blockNum, forceUntil, data);

        // Call the certify function
        vault.certify(certifyUntil, blockNum, forceUntil, data);

        vm.stopPrank();
    }

    function test_Certify_RevertOnZeroCertifyUntil() public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Grant CERTIFIER role to Alice
        vault.grantRole(vault.CERTIFIER(), alice);

        // Get the current block number
        uint256 blockNum = block.number;

        // Expect revert on zero certifyUntil
        vm.expectRevert(abi.encodeWithSignature("ZeroCertifyUntil(address)", alice));
        vault.certify(0, blockNum, false, abi.encodePacked("Certification data"));

        vm.stopPrank();
    }

    function test_Certify_RevertOnFutureReferenceBlock() public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Grant CERTIFIER role to Alice
        vault.grantRole(vault.CERTIFIER(), alice);

        // Set a future block number
        uint256 futureBlockNum = block.number + 10;

        // Expect revert on future reference block
        vm.expectRevert(abi.encodeWithSignature("FutureReferenceBlock(address,uint256)", alice, futureBlockNum));
        vault.certify(1719777599, futureBlockNum, false, abi.encodePacked("Certification data"));

        vm.stopPrank();
    }
}
