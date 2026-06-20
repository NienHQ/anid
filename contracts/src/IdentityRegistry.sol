// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";

/// @title IdentityRegistry — adopted ERC-8004 Identity
/// @notice Agent IDs are ERC-721 tokens. Adopts the ERC-8004 Identity shape and
///         supersedes the minimal IdentityLite, keeping its `AgentRegistered`
///         event for wire-compatibility (SPEC.md §6). See spec/01-identity.md.
/// @dev    Registration is open (anyone may mint an unused agent id to an owner),
///         mirroring IdentityLite; richer onboarding policy lives off-chain / in
///         the engine layer, not in this minimal binding.
contract IdentityRegistry is ERC721, IIdentityRegistry {
    error AlreadyRegistered(uint256 agentId);
    error ZeroAddress();

    constructor() ERC721("ANID Agent", "ANID") {}

    /// @inheritdoc IIdentityRegistry
    function register(uint256 agentId, address owner) external {
        if (owner == address(0)) revert ZeroAddress();
        if (_ownerOf(agentId) != address(0)) revert AlreadyRegistered(agentId);
        _mint(owner, agentId); // emits ERC-721 Transfer
        emit AgentRegistered(agentId, owner);
    }

    /// @inheritdoc IIdentityRegistry
    function exists(uint256 agentId) external view returns (bool) {
        return _ownerOf(agentId) != address(0);
    }

    /// @inheritdoc IIdentityRegistry
    function ownerOf(uint256 agentId)
        public
        view
        override(ERC721, IIdentityRegistry)
        returns (address)
    {
        return super.ownerOf(agentId);
    }
}
