// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IValidationRegistry} from "./interfaces/IValidationRegistry.sol";

/// @title ValidationRegistry — adopted ERC-8004 Validation (minimal hook)
/// @notice Kept as-is from ERC-8004. A recorded response MAY double as a tier-2
///         (TEE attestation) execution-proof source for the Reputation registry.
///         See spec/04-validation.md. Deliberately minimal.
contract ValidationRegistry is IValidationRegistry {
    struct Validation {
        address validator;
        uint256 agentId;
        uint8 response;
        bool requested;
        bool answered;
    }

    mapping(bytes32 => Validation) private _validations;

    error AlreadyRequested(bytes32 dataHash);
    error UnknownRequest(bytes32 dataHash);
    error NotValidator(bytes32 dataHash);
    error AlreadyAnswered(bytes32 dataHash);
    error ZeroValidator();

    /// @inheritdoc IValidationRegistry
    function validationRequest(address validator, uint256 agentId, bytes32 dataHash) external {
        if (validator == address(0)) revert ZeroValidator();
        if (_validations[dataHash].requested) revert AlreadyRequested(dataHash);
        _validations[dataHash] =
            Validation({validator: validator, agentId: agentId, response: 0, requested: true, answered: false});
        emit ValidationRequested(dataHash, validator, agentId);
    }

    /// @inheritdoc IValidationRegistry
    function validationResponse(bytes32 dataHash, uint8 response) external {
        Validation storage v = _validations[dataHash];
        if (!v.requested) revert UnknownRequest(dataHash);
        if (msg.sender != v.validator) revert NotValidator(dataHash);
        if (v.answered) revert AlreadyAnswered(dataHash);
        v.response = response;
        v.answered = true;
        emit ValidationResponded(dataHash, msg.sender, response);
    }

    /// @inheritdoc IValidationRegistry
    function getValidation(bytes32 dataHash)
        external
        view
        returns (address validator, uint256 agentId, uint8 response, bool answered)
    {
        Validation storage v = _validations[dataHash];
        return (v.validator, v.agentId, v.response, v.answered);
    }
}
