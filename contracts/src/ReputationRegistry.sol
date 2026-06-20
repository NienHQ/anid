// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IReputationRegistry, ExecutionProof, Outcome} from
    "./interfaces/IReputationRegistry.sol";
import {IEngineRegistry} from "./interfaces/IEngineRegistry.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";

/// @title ReputationRegistry — the ANID fork of ERC-8004 reputation
/// @notice Restricted-write, execution-bound reputation. The load-bearing rule:
///         a write succeeds iff `msg.sender ∈ 𝒩` AND a valid execution proof is
///         supplied. There is no open submit, no anonymous writer, no star rating.
///         Scores are the whitepaper EMA two-score (trust + performance):
///             s(t+1) = λ·s(t) + (1−λ)·g(o),  λ ∈ (0,1),  g(o) ∈ [−1,1].
///         See spec/02-reputation.md. The invariant tests are the spec's proof.
contract ReputationRegistry is IReputationRegistry {
    /// @notice Fixed-point scale (1.0). Scores and rewards are WAD-scaled.
    int256 public constant WAD = 1e18;

    /// @notice The authorized writer set 𝒩.
    IEngineRegistry public immutable engineRegistry;
    /// @notice Identity registry, used to enforce counterparty independence by owner.
    IIdentityRegistry public immutable identityRegistry;
    /// @notice EMA half-life lever λ, WAD-scaled, strictly in (0, WAD).
    int256 public immutable lambda;

    struct Score {
        int256 trust; // EMA trust score, WAD-scaled, signed in [-WAD, WAD]
        int256 performance; // EMA performance score, WAD-scaled, signed in [-WAD, WAD]
        uint64 n; // number of observations
        uint16 distinctEngines; // distinct members of 𝒩 that contributed
    }

    mapping(uint256 => Score) private _scores;
    /// @notice agentId => engine => has this engine ever written for this agent.
    mapping(uint256 => mapping(address => bool)) public hasWritten;

    error NotRegisteredEngine(address caller);
    error EmptyProof();
    error RewardOutOfRange(int256 value);
    error SelfDealing(uint256 agentId, bytes32 counterpartyId);

    /// @dev Enforces the only-𝒩 write invariant (R-REP-1) on every write.
    modifier onlyRegisteredEngine() {
        if (!engineRegistry.isRegistered(msg.sender)) revert NotRegisteredEngine(msg.sender);
        _;
    }

    /// @param _engineRegistry   The 𝒩 allowlist this registry trusts.
    /// @param _identityRegistry Identity registry for counterparty-independence checks.
    /// @param _lambda           EMA λ, WAD-scaled, in (0, WAD). e.g. 0.9e18.
    constructor(IEngineRegistry _engineRegistry, IIdentityRegistry _identityRegistry, int256 _lambda)
    {
        require(_lambda > 0 && _lambda < WAD, "lambda out of (0,WAD)");
        engineRegistry = _engineRegistry;
        identityRegistry = _identityRegistry;
        lambda = _lambda;
    }

    /// @inheritdoc IReputationRegistry
    function recordOutcome(
        uint256 agentId,
        ExecutionProof calldata proof,
        bytes32 counterpartyId,
        Outcome calldata outcome,
        bytes32 feedbackCommit,
        bytes32 policyId
    ) external onlyRegisteredEngine {
        // R-REP-2: no-proof-no-write.
        if (proof.ref == bytes32(0)) revert EmptyProof();
        // R-REP-3 domain: rewards are signed and bounded to [-1, 1] (WAD-scaled).
        if (outcome.trustDelta < -WAD || outcome.trustDelta > WAD) {
            revert RewardOutOfRange(outcome.trustDelta);
        }
        if (outcome.perfDelta < -WAD || outcome.perfDelta > WAD) {
            revert RewardOutOfRange(outcome.perfDelta);
        }
        // R-REP-4: counterparty independence (self-dealing rejected).
        _requireIndependent(agentId, counterpartyId);

        Score storage s = _scores[agentId];

        // R-REP-5/6: EMA update applies the decay lever λ to each score.
        s.trust = _ema(s.trust, outcome.trustDelta);
        s.performance = _ema(s.performance, outcome.perfDelta);

        // R-REP-8: provenance.
        s.n += 1;
        if (!hasWritten[agentId][msg.sender]) {
            hasWritten[agentId][msg.sender] = true;
            s.distinctEngines += 1;
        }

        emit OutcomeRecorded(
            agentId,
            msg.sender,
            counterpartyId,
            proof.kind,
            proof.ref,
            outcome.trustDelta,
            outcome.perfDelta,
            feedbackCommit,
            policyId
        );
    }

    /// @inheritdoc IReputationRegistry
    function scoreFor(uint256 agentId)
        external
        view
        returns (int256 trust, int256 performance, uint64 n, uint16 distinctEngines)
    {
        Score storage s = _scores[agentId];
        return (s.trust, s.performance, s.n, s.distinctEngines);
    }

    /// @dev EMA step: s' = (λ·s + (WAD−λ)·g) / WAD, with s,g ∈ [-WAD, WAD].
    ///      Result stays within [-WAD, WAD]; integer division truncates toward zero.
    function _ema(int256 s, int256 g) internal view returns (int256) {
        return (lambda * s + (WAD - lambda) * g) / WAD;
    }

    /// @dev Rejects a write whose counterparty is the agent itself, or a different
    ///      agent under the same owner (related-counterparty self-dealing).
    function _requireIndependent(uint256 agentId, bytes32 counterpartyId) internal view {
        if (counterpartyId == bytes32(agentId)) revert SelfDealing(agentId, counterpartyId);
        uint256 cpId = uint256(counterpartyId);
        if (identityRegistry.exists(cpId) && identityRegistry.exists(agentId)) {
            if (identityRegistry.ownerOf(cpId) == identityRegistry.ownerOf(agentId)) {
                revert SelfDealing(agentId, counterpartyId);
            }
        }
    }
}
