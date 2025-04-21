// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// MUST be thrown by an `IAuthorizeV1` contract if the user is not authorized.
/// @param user The address of the user that was not authorized.
/// @param permission The permission that was not granted.
/// @param data The data that was passed to the authorization contract.
error Unauthorized(address user, bytes32 permission, bytes data);

/// Minimal interface for a contract to provide authorization for another.
/// The contract implementing this is expected to REVERT if the user is not
/// authorized for the given permission. There are no return values.
///
/// There's no assumption that the authorization works in any particular way. A
/// simple example would be an RBAC such as implemented by Open Zeppelin's
/// standard contracts. A more complex example would be handing over the
/// authorization to a rainlang expression that could be voted on and deployed
/// by a DAO.
///
/// The point is that the calling contract can decouple its basic workflows and
/// associated state from the authorization logic. This is in contract to the
/// `Ownable` pattern where the calling contract would expect itself to be owned
/// by some contract that implements the authorization logic as a wrapper. The
/// main benefit of `IAuthorizeV1` is that the authorization contract can be
/// passed contextual data about state changes from the caller, without
/// duplication of sensitive internal logic.
///
/// If the `Ownable` pattern is desirable for whatever reason, the `IAuthorizeV1`
/// contract can simply revert whenever the caller is not the owner.
///
/// Obviously, setting the `IAuthorizeV1` contract on the caller is an extremely
/// sensitive operation and should be done with care, such as through a multisig
/// and/or dedicated governance contract.
interface IAuthorizeV1 {
    /// MUST be emitted when a new authorizer contract is set.
    /// This includes the initial setting of the authorizer contract if it is
    /// set in the constructor/initializer.
    /// @param sender The msg sender setting the authorizer.
    /// @param authorizer The new authorizer contract.
    event AuthorizerSet(address sender, IAuthorizeV1 authorizer);

    /// Authorize a user for a caller-specified permission.
    ///
    /// The authorization contract is expected to be implemented to be compatible
    /// with a specific caller only. It MUST be aware of and handle all
    /// `permission` values that the caller may send.
    ///
    /// Authorization MAY CHANGE STATE as `view` is NOT mandated at the interface
    /// level, however it is RECOMMENDED. For example, a user may only be
    /// authorized to perform an action a specified number of times, and so the
    /// authorization contract will need to maintain a counter. However, if state
    /// changes are allowed, the authorization contract MUST enforce that the
    /// caller is the expected contract, otherwise it is very likely that state
    /// will be corrupted by a malicious caller.
    ///
    /// @param user The address of the user to authorize. Most likely will be
    /// the `msg.sender` from the calling contract's perspective, but MAY NOT be.
    /// @param permission The permission to authorize.
    /// @param data Arbitrary data to pass to the authorization contract. Most
    /// likely to be an abi encoded representation of the state change that the
    /// caller needs to authorize.
    function authorize(address user, bytes32 permission, bytes memory data) external;
}
