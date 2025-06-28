// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    PaymentTokenDecimalMismatch
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config} from
    "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {ICloneableV2} from "rain.factory/interface/ICloneableV2.sol";
import {DepositStateChange, DEPOSIT} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

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
                owner: owner,
                paymentToken: paymentToken,
                maxSharesSupply: maxSharesSupply
            })
        );
        return OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
    }

    function testMintSimple(address receiptVault, address alice, address bob) external {
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
}
