// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {EngineRegistry} from "../src/EngineRegistry.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {
    IReputationRegistry,
    ExecutionProof,
    Outcome,
    ProofKind
} from "../src/interfaces/IReputationRegistry.sol";

/// @notice The invariant suite. These tests ARE the spec's proof: each maps to a
///         normative requirement in SPEC.md / spec/02-reputation.md.
contract ReputationRegistryTest is Test {
    int256 constant WAD = 1e18;
    int256 constant LAMBDA = 9e17; // 0.9

    EngineRegistry engineRegistry;
    IdentityRegistry identityRegistry;
    ReputationRegistry rep;

    address owner = address(this);
    address engine = makeAddr("engine");
    address engine2 = makeAddr("engine2");
    address rogue = makeAddr("rogue");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant AGENT = 1;
    uint256 constant AGENT_SAME_OWNER = 2; // also alice's
    uint256 constant AGENT_BOB = 3;

    function setUp() public {
        identityRegistry = new IdentityRegistry();
        engineRegistry = new EngineRegistry(owner);
        rep = new ReputationRegistry(engineRegistry, identityRegistry, LAMBDA);

        identityRegistry.register(AGENT, alice);
        identityRegistry.register(AGENT_SAME_OWNER, alice);
        identityRegistry.register(AGENT_BOB, bob);

        engineRegistry.register(engine);
    }

    // --- helpers ---

    function _proof(bytes32 ref) internal pure returns (ExecutionProof memory) {
        return ExecutionProof({kind: ProofKind.SettledOnChain, ref: ref});
    }

    function _outcome(int256 t, int256 p) internal pure returns (Outcome memory) {
        return Outcome({trustDelta: t, perfDelta: p});
    }

    function _record(address as_, uint256 agentId, bytes32 ref, bytes32 cp, int256 t, int256 p)
        internal
    {
        vm.prank(as_);
        rep.recordOutcome(agentId, _proof(ref), cp, _outcome(t, p), bytes32(0), bytes32("policy"));
    }

    // ---------------------------------------------------------------------
    // R-REP-1 — only 𝒩 may write
    // ---------------------------------------------------------------------

    function test_onlyEngine_revertsForNonMember() public {
        vm.prank(rogue);
        vm.expectRevert(
            abi.encodeWithSelector(ReputationRegistry.NotRegisteredEngine.selector, rogue)
        );
        rep.recordOutcome(
            AGENT, _proof("tx"), bytes32(AGENT_BOB), _outcome(WAD, WAD), bytes32(0), bytes32(0)
        );
    }

    function test_onlyEngine_succeedsForMember() public {
        _record(engine, AGENT, "tx", bytes32(AGENT_BOB), WAD, WAD);
        (,, uint64 n,) = rep.scoreFor(AGENT);
        assertEq(n, 1);
    }

    // ---------------------------------------------------------------------
    // R-REP-2 — no proof, no write
    // ---------------------------------------------------------------------

    function test_noProof_reverts() public {
        vm.prank(engine);
        vm.expectRevert(ReputationRegistry.EmptyProof.selector);
        rep.recordOutcome(
            AGENT, _proof(bytes32(0)), bytes32(AGENT_BOB), _outcome(WAD, WAD), bytes32(0), bytes32(0)
        );
    }

    // ---------------------------------------------------------------------
    // R-REP-3 — score is signed, not monotonic
    // ---------------------------------------------------------------------

    function test_score_isSigned_negativeLowersIt() public {
        // +1.0 outcome → trust = (0.9*0 + 0.1*1.0) = 0.1
        _record(engine, AGENT, "tx1", bytes32(AGENT_BOB), WAD, WAD);
        (int256 trustAfterPos, int256 perfAfterPos,,) = rep.scoreFor(AGENT);
        assertEq(trustAfterPos, 1e17, "trust after +1");
        assertEq(perfAfterPos, 1e17, "perf after +1");

        // -1.0 outcome → trust = (0.9*0.1 + 0.1*(-1.0)) = 0.09 - 0.1 = -0.01
        _record(engine, AGENT, "tx2", bytes32(AGENT_BOB), -WAD, -WAD);
        (int256 trustAfterNeg, int256 perfAfterNeg,,) = rep.scoreFor(AGENT);
        assertEq(trustAfterNeg, -1e16, "trust after -1");
        assertEq(perfAfterNeg, -1e16, "perf after -1");

        assertLt(trustAfterNeg, trustAfterPos, "negative outcome must lower trust");
        assertLt(perfAfterNeg, perfAfterPos, "negative outcome must lower performance");
        assertLt(trustAfterNeg, int256(0), "trust can go below zero");
    }

    function test_reward_outOfRange_reverts() public {
        vm.prank(engine);
        vm.expectRevert(abi.encodeWithSelector(ReputationRegistry.RewardOutOfRange.selector, WAD + 1));
        rep.recordOutcome(
            AGENT, _proof("tx"), bytes32(AGENT_BOB), _outcome(WAD + 1, 0), bytes32(0), bytes32(0)
        );
    }

    // ---------------------------------------------------------------------
    // R-REP-4 — counterparty independence (self-dealing rejected)
    // ---------------------------------------------------------------------

    function test_selfDeal_sameAgent_reverts() public {
        vm.prank(engine);
        vm.expectRevert(
            abi.encodeWithSelector(ReputationRegistry.SelfDealing.selector, AGENT, bytes32(AGENT))
        );
        rep.recordOutcome(
            AGENT, _proof("tx"), bytes32(AGENT), _outcome(WAD, WAD), bytes32(0), bytes32(0)
        );
    }

    function test_selfDeal_sameOwnerDifferentAgent_reverts() public {
        vm.prank(engine);
        vm.expectRevert(
            abi.encodeWithSelector(
                ReputationRegistry.SelfDealing.selector, AGENT, bytes32(AGENT_SAME_OWNER)
            )
        );
        rep.recordOutcome(
            AGENT, _proof("tx"), bytes32(AGENT_SAME_OWNER), _outcome(WAD, WAD), bytes32(0), bytes32(0)
        );
    }

    function test_independentCounterparty_ok() public {
        _record(engine, AGENT, "tx", bytes32(AGENT_BOB), WAD, WAD); // bob != alice
        (,, uint64 n,) = rep.scoreFor(AGENT);
        assertEq(n, 1);
    }

    // ---------------------------------------------------------------------
    // R-ENG-3 — deregistering flips write authority live
    // ---------------------------------------------------------------------

    function test_registryFlip_revokesWriteAuthorityLive() public {
        _record(engine, AGENT, "tx1", bytes32(AGENT_BOB), WAD, WAD); // works while registered

        engineRegistry.deregister(engine);

        vm.prank(engine);
        vm.expectRevert(
            abi.encodeWithSelector(ReputationRegistry.NotRegisteredEngine.selector, engine)
        );
        rep.recordOutcome(
            AGENT, _proof("tx2"), bytes32(AGENT_BOB), _outcome(WAD, WAD), bytes32(0), bytes32(0)
        );

        engineRegistry.register(engine); // re-add → authority returns
        _record(engine, AGENT, "tx3", bytes32(AGENT_BOB), WAD, WAD);
        (,, uint64 n,) = rep.scoreFor(AGENT);
        assertEq(n, 2, "two successful writes (tx1, tx3)");
    }

    // ---------------------------------------------------------------------
    // R-REP-8 — provenance: n and distinctEngines
    // ---------------------------------------------------------------------

    function test_provenance_countsObservationsAndDistinctEngines() public {
        engineRegistry.register(engine2);

        _record(engine, AGENT, "a", bytes32(AGENT_BOB), WAD, 0);
        _record(engine, AGENT, "b", bytes32(AGENT_BOB), WAD, 0); // same engine again
        _record(engine2, AGENT, "c", bytes32(AGENT_BOB), WAD, 0); // second distinct engine

        (,, uint64 n, uint16 distinct) = rep.scoreFor(AGENT);
        assertEq(n, 3, "three observations");
        assertEq(distinct, 2, "two distinct engines");
    }

    // ---------------------------------------------------------------------
    // R-REP-5/6 — EMA decay across repeated outcomes
    // ---------------------------------------------------------------------

    function test_ema_decaysTowardSteadyState() public {
        // Repeated +1.0 outcomes converge upward toward 1.0 but never exceed it.
        int256 prev = 0;
        for (uint256 i = 0; i < 8; i++) {
            _record(engine, AGENT, bytes32(i + 1), bytes32(AGENT_BOB), WAD, WAD);
            (int256 trust,,,) = rep.scoreFor(AGENT);
            assertGt(trust, prev, "monotonically rising under repeated +1");
            assertLt(trust, WAD, "never reaches 1.0 exactly (EMA)");
            prev = trust;
        }
    }

    function test_emitsOutcomeRecorded() public {
        vm.expectEmit(true, true, false, true, address(rep));
        emit IReputationRegistry.OutcomeRecorded(
            AGENT,
            engine,
            bytes32(AGENT_BOB),
            ProofKind.SettledOnChain,
            "tx",
            WAD,
            WAD,
            bytes32(0),
            bytes32("policy")
        );
        _record(engine, AGENT, "tx", bytes32(AGENT_BOB), WAD, WAD);
    }
}
