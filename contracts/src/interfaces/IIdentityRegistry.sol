// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IIdentityRegistry — adopted ERC-8004 Identity
/// @notice Agent IDs are ERC-721 tokens with an owner. ANID adopts the ERC-8004
///         Identity model verbatim and pins the `AgentRegistered` event for
///         wire-compatibility with the deployed IdentityLite (SPEC.md §6).
interface IIdentityRegistry {
    /// @notice Owner (controller) of an agent id. Reverts for an unregistered id
    ///         in the ERC-721 implementation; reference impl exposes `ownerOf`.
    function ownerOf(uint256 agentId) external view returns (address);

    /// @notice True once `agentId` has been registered.
    function exists(uint256 agentId) external view returns (bool);

    /// @notice Register (mint) an agent id to an owner.
    function register(uint256 agentId, address owner) external;

    /// @notice Wire-compatible with IdentityLite. Emitted in addition to ERC-721 Transfer.
    event AgentRegistered(uint256 indexed agentId, address indexed owner);
}
