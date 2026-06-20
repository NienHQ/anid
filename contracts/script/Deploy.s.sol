// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {EngineRegistry} from "../src/EngineRegistry.sol";
import {ValidationRegistry} from "../src/ValidationRegistry.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";

/// @title Deploy — the four ANID registries, wired together
/// @notice Deploys Identity, Engine, Validation, and the forked Reputation registry,
///         wiring Reputation → Engine + Identity. Target: BNB Smart Chain testnet
///         (chain 97), but chain-agnostic.
///
/// Usage (dry-run / simulate):
///   forge script script/Deploy.s.sol --rpc-url bsc_testnet --sender <addr>
/// Broadcast:
///   forge script script/Deploy.s.sol --rpc-url bsc_testnet \
///     --account <keystore> --broadcast --verify
///
/// Env:
///   ENGINE_REGISTRY_OWNER  (optional) governance owner of 𝒩; defaults to deployer.
///   LAMBDA_WAD             (optional) EMA λ, WAD-scaled in (0,1e18); defaults 0.9e18.
contract Deploy is Script {
    function run()
        external
        returns (
            IdentityRegistry identity,
            EngineRegistry engine,
            ValidationRegistry validation,
            ReputationRegistry reputation
        )
    {
        address owner = vm.envOr("ENGINE_REGISTRY_OWNER", msg.sender);
        int256 lambda = int256(vm.envOr("LAMBDA_WAD", uint256(9e17)));

        vm.startBroadcast();

        identity = new IdentityRegistry();
        engine = new EngineRegistry(owner);
        validation = new ValidationRegistry();
        reputation = new ReputationRegistry(engine, identity, lambda);

        vm.stopBroadcast();

        console2.log("IdentityRegistry  ", address(identity));
        console2.log("EngineRegistry    ", address(engine));
        console2.log("ValidationRegistry", address(validation));
        console2.log("ReputationRegistry", address(reputation));
        console2.log("  -> engineRegistry ", address(reputation.engineRegistry()));
        console2.log("  -> identityReg    ", address(reputation.identityRegistry()));
        console2.log("  -> engine set owner", owner);
    }
}
