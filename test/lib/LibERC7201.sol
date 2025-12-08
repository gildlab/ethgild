// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

library LibERC7201 {
    /// https://eips.ethereum.org/EIPS/eip-7201#formula
    /// > The formula identified by erc7201 is defined as
    /// > `erc7201(id: string) = keccak256(keccak256(id) - 1) & ~0xff`.
    /// > In Solidity, this corresponds to the expression
    /// > `keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff))`.
    /// > When using this formula the annotation becomes
    /// > @custom:storage-location erc7201:<NAMESPACE_ID>.
    /// > For example, @custom:storage-location erc7201:foobar annotates a
    /// > namespace with id "foobar" rooted at erc7201("foobar").
    function idForString(string memory name) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(name))) - 1)) & ~bytes32(uint256(0xff));
    }
}
