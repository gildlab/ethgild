// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    PaymentTokenDecimalMismatch,
    MaxSharesSupplyExceeded,
    Unauthorized
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config} from
    "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {ICloneableV2} from "rain.factory/interface/ICloneableV2.sol";
import {DepositStateChange, DEPOSIT, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    ReceiptVaultConstructionConfigV2,
    OffchainAssetVaultConfigV2,
    VaultConfig
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {VerifyAlwaysApproved} from "rain.verify.interface/concrete/VerifyAlwaysApproved.sol";

import {TestErc20} from "test/concrete/TestErc20.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1DepositTest is OffchainAssetReceiptVaultAuthorizerV1Test {
    function newAuthorizer(address receiptVault, address owner, address paymentToken, uint256 maxSharesSupply)
        internal
        returns (OffchainAssetReceiptVaultPaymentMintAuthorizerV1)
    {
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();
        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                receiptVault: receiptVault,
                verify: address(new VerifyAlwaysApproved()),
                owner: owner,
                paymentToken: paymentToken,
                maxSharesSupply: maxSharesSupply
            })
        );
        return OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
    }

    function testMintSimpleRealReceiptVault(address alice, address bob) external {
        vm.assume(uint160(alice) > type(uint160).max / 2 && uint160(bob) > type(uint160).max / 2 && alice != bob);

        vm.prank(bob);
        TestErc20 paymentToken = new TestErc20();

        OffchainAssetReceiptVault receiptVaultImplementation = new OffchainAssetReceiptVault(
            ReceiptVaultConstructionConfigV2({factory: new CloneFactory(), receiptImplementation: new ReceiptContract()})
        );
        OffchainAssetReceiptVault receiptVault = OffchainAssetReceiptVault(
            payable(
                (new CloneFactory()).clone(
                    address(receiptVaultImplementation),
                    abi.encode(
                        OffchainAssetVaultConfigV2({
                            initialAdmin: alice,
                            vaultConfig: VaultConfig({asset: address(0), name: "Test Vault", symbol: "TVLT"})
                        })
                    )
                )
            )
        );

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(address(receiptVault), alice, address(paymentToken), 1000e18);
        vm.startPrank(alice);
        receiptVault.setAuthorizer(authorizer);
        authorizer.grantRole(CERTIFY, alice);
        receiptVault.certify(block.timestamp + 1, false, "");
        vm.stopPrank();

        assertEq(authorizer.owner(), alice, "Owner should be set to Alice");
        assertEq(1e27, paymentToken.balanceOf(bob), "Bob should have all the payment tokens initially");
        assertEq(0, paymentToken.balanceOf(alice), "Alice should have no tokens initially");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens initially");

        // Alice can't afford to deposit.
        vm.startPrank(alice);
        paymentToken.approve(address(authorizer), 100e18);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        receiptVault.deposit(1e18, alice, 0, hex"");
        vm.stopPrank();

        // Bob can afford to deposit.
        vm.startPrank(bob);
        paymentToken.approve(address(authorizer), 100e18);
        receiptVault.deposit(1e18, bob, 0, hex"");
        vm.stopPrank();

        assertEq(1e27 - 1e18, paymentToken.balanceOf(bob), "Bob should have reduced balance after deposit");
        assertEq(
            1e18, paymentToken.balanceOf(address(authorizer)), "Authorizer should have received tokens after deposit"
        );
        assertEq(0, paymentToken.balanceOf(alice), "Alice should still have no tokens after deposit");

        authorizer.sendPaymentToOwner();

        assertEq(1e27 - 1e18, paymentToken.balanceOf(bob), "Bob should still have reduced balance after payment");
        assertEq(1e18, paymentToken.balanceOf(alice), "Alice should have received payment after send");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens after send");
    }

    function testMintSimpleMockedReceiptVault(address receiptVault, address alice, address bob) external {
        vm.assume(alice != address(0) && bob != address(0) && alice != bob);
        vm.assume(uint160(receiptVault) > type(uint160).max / 2);

        vm.prank(alice);
        TestErc20 paymentToken = new TestErc20();

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, bob, address(paymentToken), 1000e18);

        assertEq(authorizer.owner(), bob, "Owner should be set to Bob");
        assertEq(1e27, paymentToken.balanceOf(alice), "Alice should have tokens initially");
        assertEq(0, paymentToken.balanceOf(bob), "Bob should have no tokens initially");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens initially");

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(500e18));

        vm.prank(alice);
        paymentToken.approve(address(authorizer), 100e18);

        vm.prank(receiptVault);
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: 100e18,
                    sharesMinted: 100e18,
                    data: ""
                })
            )
        );

        assertEq(1e27 - 100e18, paymentToken.balanceOf(alice), "Alice should have reduced balance after mint");
        assertEq(
            100e18, paymentToken.balanceOf(address(authorizer)), "Authorizer should have received tokens after mint"
        );
        assertEq(0, paymentToken.balanceOf(bob), "Bob should still have no tokens after mint");

        vm.prank(alice);
        authorizer.sendPaymentToOwner();

        assertEq(1e27 - 100e18, paymentToken.balanceOf(alice), "Alice should still have reduced balance after payment");
        assertEq(100e18, paymentToken.balanceOf(bob), "Bob should have received payment after send");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens after send");
    }

    function testTokenDecimals(address receiptVault, address alice, address bob) external {
        vm.assume(alice != address(0) && bob != address(0) && alice != bob);
        vm.assume(uint160(receiptVault) > type(uint160).max / 2);

        vm.prank(alice);
        TestErc20 paymentToken = new TestErc20();
        paymentToken.setDecimals(12);

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, bob, address(paymentToken), 1000e18);

        assertEq(authorizer.paymentTokenDecimals(), 12, "Payment token decimals should be set to 18");

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(500e18));

        vm.prank(alice);
        paymentToken.approve(address(authorizer), 100e18);

        vm.prank(receiptVault);
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: 100e18,
                    sharesMinted: 100e18,
                    data: ""
                })
            )
        );

        assertEq(1e27 - 100e12, paymentToken.balanceOf(alice), "Alice should have reduced balance after mint");
        assertEq(
            100e12, paymentToken.balanceOf(address(authorizer)), "Authorizer should have received tokens after mint"
        );
    }

    function testTofuTokenDecimals(address receiptVault, address alice, address bob) external {
        vm.assume(alice != address(0) && bob != address(0) && alice != bob);
        vm.assume(uint160(receiptVault) > type(uint160).max / 2);

        vm.prank(alice);
        TestErc20 paymentToken = new TestErc20();
        paymentToken.setDecimals(6);

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, bob, address(paymentToken), 1000e18);

        assertEq(authorizer.paymentTokenDecimals(), 6, "Payment token decimals should be set to 6");

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(500e18));

        vm.prank(alice);
        paymentToken.approve(address(authorizer), 100e18);

        vm.prank(receiptVault);
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: 100e18,
                    sharesMinted: 100e18,
                    data: ""
                })
            )
        );

        assertEq(1e27 - 100e6, paymentToken.balanceOf(alice), "Alice should have reduced balance after mint");
        assertEq(
            100e6,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have received tokens after second mint"
        );

        paymentToken.setDecimals(18);
        vm.prank(receiptVault);
        vm.expectRevert(abi.encodeWithSelector(PaymentTokenDecimalMismatch.selector, 6, 18));
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: 100e18,
                    sharesMinted: 100e18,
                    data: ""
                })
            )
        );

        paymentToken.setDecimals(6);
        vm.prank(receiptVault);
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: 100e18,
                    sharesMinted: 100e18,
                    data: ""
                })
            )
        );

        assertEq(1e27 - 200e6, paymentToken.balanceOf(alice), "Alice should have reduced balance after second mint");
        assertEq(
            200e6,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have received tokens after second mint"
        );
    }

    function testMaxSharesSupplyExceeded(
        address receiptVault,
        address alice,
        address bob,
        uint256 maxShares,
        uint256 totalSupply,
        uint256 firstShares,
        uint256 secondShares
    ) external {
        vm.assume(alice != address(0) && bob != address(0) && alice != bob);
        vm.assume(uint160(receiptVault) > type(uint160).max / 2);

        vm.prank(alice);
        TestErc20 paymentToken = new TestErc20();

        maxShares = bound(maxShares, 1e18, 1e27);
        totalSupply = bound(totalSupply, 0, maxShares - 1);
        firstShares = bound(firstShares, 0, maxShares - totalSupply);
        secondShares = bound(secondShares, maxShares - totalSupply + 1, type(uint128).max);

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, bob, address(paymentToken), maxShares);

        assertEq(authorizer.maxSharesSupply(), maxShares, "Max shares supply should be set");

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply));

        vm.prank(alice);
        paymentToken.approve(address(authorizer), maxShares);

        vm.prank(receiptVault);
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: firstShares,
                    sharesMinted: firstShares,
                    data: ""
                })
            )
        );

        assertEq(1e27 - firstShares, paymentToken.balanceOf(alice), "Alice should have reduced balance after mint");
        assertEq(
            firstShares,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have received tokens after mint"
        );

        vm.prank(receiptVault);
        vm.expectRevert(abi.encodeWithSelector(MaxSharesSupplyExceeded.selector, maxShares, totalSupply + secondShares));
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: secondShares,
                    sharesMinted: secondShares,
                    data: ""
                })
            )
        );
    }
}
