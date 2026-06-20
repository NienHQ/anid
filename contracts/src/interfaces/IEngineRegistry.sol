// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEngineRegistry — the authorized writer set 𝒩
/// @notice On-chain allowlist of engine contracts permitted to write reputation.
///         The Reputation registry calls `isRegistered` on every write to enforce
///         the only-𝒩 invariant (R-ENG-1 / R-REP-1 in SPEC.md).
/// @dev    The read-only half (`isRegistered`) is the minimal `IEngineSet` seam.
interface IEngineRegistry {
    /// @notice Membership test for 𝒩.
    function isRegistered(address engine) external view returns (bool);

    /// @notice Add an engine to 𝒩 (governance-gated).
    function register(address engine) external;

    /// @notice Remove an engine from 𝒩 (governance-gated). Revokes write authority live.
    function deregister(address engine) external;

    event EngineRegistered(address indexed engine);
    event EngineDeregistered(address indexed engine);
}
