// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OwnableUpgradeable as Ownable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IOwnerFreezableV1, IERC5313} from "../interface/IOwnerFreezableV1.sol";

/// @title OwnerFreezable
/// This abstract contract inherits from Ownable and adds the ability for the
/// owner to freeze the contract until a given timestamp. The owner cannot
/// reverse this freeze, although they can extend it.
///
/// The idea is that if an attacker were to phish/compromise the owner key then
/// the owner can no longer be trusted to perform any actions on the contract.
/// At this point, the only real solution is to snapshot and airdrop a fresh
/// token using offchain data, with a new uncompromised owner.
///
/// The main challenges when performing this snapshot are:
/// - Ascertaining the most correct moment to take the snapshot.
/// - Mitigating secondary fund losses from markets, such as tokens paired
///   against the compromised token on Uniswap, etc.
///
/// By freezing the contract in a way the owner cannot reverse, we create a clear
/// moment to snapshot the contract.
///
/// By allowing the owner to add addresses that can always send/receive, they can
/// partially mitigate the risk of secondary fund losses. For example, the owner
/// could add Uniswap contracts to the always allowed list, to allow LPs to
/// remove their LP positions gracefully. Even if the attacker adds more
/// addresses to the always allowed list, they cannot e.g. infinite mint and rug
/// the pool themselves, everyone still only has access to the tokens they
/// already had.
///
/// Important note: Alone these functions do not protect against a compromised
/// owner key. They are a basic toolkit that would allow a smart contract to be
/// written _as the owner_ to implement the actual governance process desired.
/// For example, the owner could be written such that any modification to the
/// ownership and/or authorizor contract triggers a 24 hour freeze. Or it could
/// allow adding `from` addresses to the always allowed list, but not `to`
/// addresses, to mitigate the risk that the attacker opens up the ability to
/// dump on the LPs en masse after the snapshot.
abstract contract OwnerFreezable is Ownable, IOwnerFreezableV1 {
    /// Contract is frozen until this time.
    /// Explicitly initialized to `0` for clarity.
    uint256 private sOwnerFrozenUntil = 0;

    /// @dev Mapping of `from` addresses that are always allowed to send.
    /// If the protected time is any non-zero value then the `from` address is
    /// always allowed to send. While the current time is less than the
    /// protected time the `from` address cannot be removed from the always
    /// allowed list.
    mapping(address from => uint256 protectedUntil) private sAlwaysAllowedFroms;

    /// @dev Mapping of `to` addresses that are always allowed to receive.
    /// If the protected time is any non-zero value then the `to` address is
    /// always allowed to receive. While the current time is less than the
    /// protected time the `to` address cannot be removed from the always
    /// allowed list.
    mapping(address to => uint256 protectedUntil) private sAlwaysAllowedTos;

    /// @inheritdoc IERC5313
    function owner() public view virtual override(IERC5313, Ownable) returns (address) {
        return super.owner();
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFrozenUntil() external view returns (uint256) {
        return sOwnerFrozenUntil;
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeUntil(uint256 freezeUntil) external onlyOwner {
        // Freezing is additive so we can only increase the freeze time.
        // It is a no-op on the state if the new freeze time is less than the
        // current one.
        if (freezeUntil > sOwnerFrozenUntil) {
            sOwnerFrozenUntil = freezeUntil;
        }

        // Emit the event with the new freeze time. We do this even if the
        // freeze time is unchanged so that we can track the history of
        // freeze calls offchain.
        emit OwnerFrozenUntil(owner(), freezeUntil, sOwnerFrozenUntil);
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeAlwaysAllowedFrom(address from) external view returns (uint256) {
        return sAlwaysAllowedFroms[from];
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeAlwaysAllowFrom(address from, uint256 protectUntil) external onlyOwner {
        // Until MUST NOT be zero. Call `ownerFreezeStopAlwaysAllowingFrom`
        // explicitly to remove a `from` address.
        if (protectUntil == 0) {
            revert OwnerFreezeAlwaysAllowedFromZero(from);
        }

        // Adding a `from` is additive so we can only increase the protected
        // time. It is a no-op on the state if the new protected time is less
        // than the current one.
        if (protectUntil > sAlwaysAllowedFroms[from]) {
            sAlwaysAllowedFroms[from] = protectUntil;
        }
        // Emit the event with the new protected time. We do this even if the
        // protected time is unchanged so that we can track the history of
        // protections offchain.
        emit OwnerFreezeAlwaysAllowedFrom(owner(), from, protectUntil, sAlwaysAllowedFroms[from]);
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeStopAlwaysAllowingFrom(address from) external onlyOwner {
        // If the current time is after the protection for this `from` then
        // we can remove it. Otherwise we revert to respect the protection.
        if (block.timestamp <= sAlwaysAllowedFroms[from]) {
            revert OwnerFreezeAlwaysAllowedFromProtected(from, sAlwaysAllowedFroms[from]);
        }

        delete sAlwaysAllowedFroms[from];
        emit OwnerFreezeAlwaysAllowedFrom(owner(), from, 0, 0);
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeAlwaysAllowTo(address to, uint256 protectUntil) external onlyOwner {
        // Until MUST NOT be zero. Call `ownerFreezeStopAlwaysAllowingTo`
        // explicitly to remove a `to` address.
        if (protectUntil == 0) {
            revert IOwnerFreezableV1.OwnerFreezeAlwaysAllowedToZero(to);
        }

        // Adding a `to` is additive so we can only increase the protected time.
        // It is a no-op on the state if the new protected time is less than the
        // current one.
        if (protectUntil > sAlwaysAllowedTos[to]) {
            sAlwaysAllowedTos[to] = protectUntil;
        }
        // Emit the event with the new protected time. We do this even if the
        // protected time is unchanged so that we can track the history of
        // protections offchain.
        emit OwnerFreezeAlwaysAllowedTo(owner(), to, protectUntil);
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeStopAlwaysAllowingTo(address to) external onlyOwner {
        // If the current time is after the protection for this `to` then
        // we can remove it. Otherwise we revert to respect the protection.
        if (block.timestamp <= sAlwaysAllowedTos[to]) {
            revert IOwnerFreezableV1.OwnerFreezeAlwaysAllowedToProtected(to, sAlwaysAllowedTos[to]);
        }

        delete sAlwaysAllowedTos[to];
        emit OwnerFreezeAlwaysAllowedTo(owner(), to, 0);
    }

    /// Check if the contract is frozen. If it is, revert if the `from` or
    /// `to` addresses are not in their respective always allowed lists.
    /// @param from The address that tokens are being sent from.
    /// @param to The address that tokens are being sent to.
    function ownerFreezeCheckTransaction(address from, address to) internal view {
        // We either simply revert or no-op for this check.
        // Revert if the contract is frozen and neither the `from` nor `to` are
        // in their respective always allowed lists.
        if (block.timestamp < sOwnerFrozenUntil || sAlwaysAllowedFroms[from] != 0 || sAlwaysAllowedTos[to] != 0) {
            revert IOwnerFreezableV1.OwnerFrozen(sOwnerFrozenUntil, from, to);
        }
    }
}
