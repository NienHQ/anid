import type {BigNumberish, ContractRunner} from "ethers";
import {
  EngineRegistry,
  EngineRegistry__factory,
  IdentityRegistry,
  IdentityRegistry__factory,
  ReputationRegistry,
  ReputationRegistry__factory,
  ValidationRegistry,
  ValidationRegistry__factory,
} from "./typechain";
import type {AnidAddresses} from "./addresses";
import type {Score} from "./record";
import {fromWad} from "./fixed";

/**
 * Read-only view over the four ANID registries. Construct with any ethers
 * `ContractRunner` (a `Provider` for reads). All methods are public + composable.
 */
export class AnidReader {
  readonly identity: IdentityRegistry;
  readonly engine: EngineRegistry;
  readonly reputation: ReputationRegistry;
  readonly validation: ValidationRegistry;

  constructor(addresses: AnidAddresses, runner: ContractRunner) {
    this.identity = IdentityRegistry__factory.connect(addresses.identity, runner);
    this.engine = EngineRegistry__factory.connect(addresses.engine, runner);
    this.reputation = ReputationRegistry__factory.connect(addresses.reputation, runner);
    this.validation = ValidationRegistry__factory.connect(addresses.validation, runner);
  }

  /** Public reputation read with provenance (R-REP-8). */
  async scoreFor(agentId: BigNumberish): Promise<Score> {
    const [trust, performance, n, distinctEngines] = await this.reputation.scoreFor(agentId);
    return {
      trust,
      performance,
      n: Number(n),
      distinctEngines: Number(distinctEngines),
      trustFloat: fromWad(trust),
      performanceFloat: fromWad(performance),
    };
  }

  /** Owner (controller) of an agent id. */
  ownerOf(agentId: BigNumberish): Promise<string> {
    return this.identity.ownerOf(agentId);
  }

  /** Whether an agent id has been registered. */
  exists(agentId: BigNumberish): Promise<boolean> {
    return this.identity.exists(agentId);
  }

  /** Whether an address is a member of 𝒩 (authorized writer). */
  isRegisteredEngine(engine: string): Promise<boolean> {
    return this.engine.isRegistered(engine);
  }
}
