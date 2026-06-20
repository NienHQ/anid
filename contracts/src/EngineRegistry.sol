// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEngineRegistry} from "./interfaces/IEngineRegistry.sol";

/// @title EngineRegistry — the authorized writer set 𝒩
/// @notice On-chain allowlist of engine contracts permitted to write reputation.
///         v1 governance is a curated allowlist held by `owner` (the Nien Identity
///         Council in production). This is intentional and closes client-Sybil;
///         the path to permissionless onboarding (staking + guardian challenge)
///         changes only the gate, not the integrity model. See spec/03-engine-registry.md.
contract EngineRegistry is IEngineRegistry, Ownable {
    /// @inheritdoc IEngineRegistry
    mapping(address => bool) public isRegistered;

    error ZeroAddress();
    error AlreadyRegistered(address engine);
    error NotRegistered(address engine);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @inheritdoc IEngineRegistry
    function register(address engine) external onlyOwner {
        if (engine == address(0)) revert ZeroAddress();
        if (isRegistered[engine]) revert AlreadyRegistered(engine);
        isRegistered[engine] = true;
        emit EngineRegistered(engine);
    }

    /// @inheritdoc IEngineRegistry
    /// @dev Takes effect immediately: the Reputation registry queries `isRegistered`
    ///      on every write, so a deregistered engine's next write reverts (R-ENG-3).
    function deregister(address engine) external onlyOwner {
        if (!isRegistered[engine]) revert NotRegistered(engine);
        isRegistered[engine] = false;
        emit EngineDeregistered(engine);
    }
}
