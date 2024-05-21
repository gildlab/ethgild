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
    string ARBITRUM_SEPOLIA_RPC_URL;
    uint256 arbitrumSepoliaFork;

    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);

    function setUp() public {
        // Fetch the RPC URL from the environment
        ARBITRUM_SEPOLIA_RPC_URL = "https://arbitrum-sepolia.blockpi.network/v1/rpc/public";

        // Attempt to create a fork
        arbitrumSepoliaFork = vm.createFork(ARBITRUM_SEPOLIA_RPC_URL);
        vm.selectFork(arbitrumSepoliaFork);

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

    function testCertify() public {
        assertEq(vm.activeFork(), arbitrumSepoliaFork);
        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Grant CERTIFIER role to Alice
        vault.grantRole(vault.CERTIFIER(), alice);

        // Get the current block number
        uint256 blockNum = block.number;
        console.log("blockNum",blockNum);
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
}
