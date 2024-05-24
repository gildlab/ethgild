pragma solidity 0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";
import "../../contracts/vault/receipt/ReceiptFactory.sol";
import "../../contracts/test/TestErc20.sol";

import "forge-std/Test.sol";

import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

contract DepositTest is Test {
    OffchainAssetReceiptVaultFactory factory;
    OffchainAssetVaultConfig offchainAssetVaultConfig;
    VaultConfig vaultConfig;
    OffchainAssetReceiptVault implementation;
    ReceiptFactory receiptFactory;
    ReceiptVaultFactoryConfig factoryConfig;
    OffchainAssetReceiptVault vault;
    address alice;
    uint256 shareRatio;
    TestErc20 testErc20Contract;

    function setUp() public {
        implementation = new OffchainAssetReceiptVault();
        receiptFactory = new ReceiptFactory();

        // Set up factory config
        factoryConfig = ReceiptVaultFactoryConfig({
            implementation: address(implementation),
            receiptFactory: address(receiptFactory)
        });

        // Create OffchainAssetReceiptVaultFactory contract
        factory = new OffchainAssetReceiptVaultFactory(factoryConfig);

        // Get the first signer address
        alice = vm.addr(1);

        address asset = address(0);
        string memory assetName = "Asset Name";
        string memory assetSymbol = "ASSET";

        vaultConfig = VaultConfig(asset, assetName, assetSymbol);
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});
        vault = factory.createChildTyped(offchainAssetVaultConfig);
    }

    function testTotalAssets() public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Get the second signer address
        address bob = vm.addr(2);

        uint256 aliceAssets = 1000;
        bytes memory receiptInformation = "";

        //New testErc20 contract
        testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        // Grant CERTIFIER role to Alice
        vault.grantRole(vault.CERTIFIER(), alice);

        // Get the current block number
        uint256 blockNum = block.number;

        // Set up expected parameters
        uint256 certifyUntil = block.timestamp + 1000;
        bool forceUntil = false;
        bytes memory data = abi.encodePacked("Certification data");

        // Call the certify function
        vault.certify(certifyUntil, blockNum, forceUntil, data);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);

        assertEqUint(vault.totalSupply(), vault.totalAssets());

        vm.stopPrank();
    }

    function testPreviewDepositReturnedShares() public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);

        uint256 aliceAssets = 100;

        //New testErc20 contract
        testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        vault.grantRole(vault.DEPOSITOR(), alice);
        uint256 shares = vault.previewDeposit(aliceAssets);

        assertEqUint(shares, aliceAssets);

        vm.stopPrank();
    }
}
