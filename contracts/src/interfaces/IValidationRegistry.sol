// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IValidationRegistry — adopted ERC-8004 Validation (minimal hook)
/// @notice Kept as-is from ERC-8004. A recorded validation response MAY double as a
///         tier-2 (TEE attestation) execution-proof source for the Reputation
///         registry. See spec/04-validation.md.
interface IValidationRegistry {
    /// @notice An agent (or its engine) requests validation of `dataHash` by `validator`.
    function validationRequest(address validator, uint256 agentId, bytes32 dataHash) external;

    /// @notice The designated validator records a response (e.g. 0..100 score, or a flag).
    function validationResponse(bytes32 dataHash, uint8 response) external;

    /// @notice Read a recorded response and whether it has been answered.
    function getValidation(bytes32 dataHash)
        external
        view
        returns (address validator, uint256 agentId, uint8 response, bool answered);

    event ValidationRequested(
        bytes32 indexed dataHash, address indexed validator, uint256 indexed agentId
    );
    event ValidationResponded(bytes32 indexed dataHash, address indexed validator, uint8 response);
}
