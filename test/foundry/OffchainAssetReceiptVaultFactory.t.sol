pragma solidity =0.8.17;

import {VaultConfig} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig,
    OffchainAssetReceiptVaultConfig
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

contract OffChainAssetReceiptVaultFactoryTest is Test, CreateOffchainAssetReceiptVaultFactory {
    OffchainAssetVaultConfig offchainAssetVaultConfig;
    VaultConfig vaultConfig;
    OffchainAssetReceiptVault vault;

    function setUp() public {
        createOffchainAssetReceiptVaultFactory();
    }

    function testOffchainAssetReceiptVaultFactoryConstuction() public view {
        assert(address(factory) != address(0));
    }

    function testCreateChild(address alice, string memory assetName, string memory assetSymbol) public {
        // Exclude the zero address
        vm.assume(alice != address(0));

        // VaultConfig to create child contract
        vaultConfig = VaultConfig(address(0), assetName, assetSymbol);

        // Simulate transaction from alice
        vm.prank(alice);
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        vault = factory.createChildTyped(offchainAssetVaultConfig);

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        address msgSender = address(0);
        address admin = address(0);
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "OffchainAssetReceiptVaultInitialized(address,(address,(address,(address,string,string))))"
                    )
            ) {
                // Decode the event data
                (address sender, OffchainAssetReceiptVaultConfig memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfig));
                msgSender = sender;
                admin = config.admin;
                break;
            }
        }

        assertEq(msgSender, address(factory));
        assertEq(admin, alice);
        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));
    }
}
