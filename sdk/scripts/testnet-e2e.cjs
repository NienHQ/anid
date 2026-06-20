/**
 * LIVE end-to-end on BNB testnet (chain 97) through the SDK:
 *   create an agent → authorize an engine → engine records an outcome → read score.
 *
 * Env: RPC_URL, AGENT_MNEMONIC, and the four ANID_* addresses.
 *   node scripts/testnet-e2e.cjs
 */
const {ethers} = require("ethers");
const {
  AnidReader,
  EngineClient,
  AdminClient,
  ProofKind,
  agentIdToBytes32,
  toAnid,
} = require("../dist/index.js");

const GAS = {gasPrice: 5_000_000_000n}; // 5 gwei — this RPC under-estimates

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const signer = ethers.Wallet.fromPhrase(process.env.AGENT_MNEMONIC).connect(provider);
  const me = await signer.getAddress();

  const addresses = {
    identity: process.env.ANID_IDENTITY,
    engine: process.env.ANID_ENGINE,
    reputation: process.env.ANID_REPUTATION,
    validation: process.env.ANID_VALIDATION,
  };

  // unique agent id per run so reruns don't collide on AlreadyRegistered
  const agentId = BigInt(Math.floor(Date.now() / 1000));
  const agentOwner = ethers.Wallet.createRandom().address;
  const counterparty = agentIdToBytes32(agentId + 1n); // unregistered, independent

  const admin = new AdminClient(addresses, signer);
  const engine = new EngineClient(addresses, signer);
  const reader = new AnidReader(addresses, provider);

  console.log("deployer/engine :", me);
  console.log("new agentId     :", agentId.toString());

  // 1) create the agent
  let tx = await admin.registerAgent(agentId, agentOwner, GAS);
  console.log("registerAgent   :", tx.hash);
  await tx.wait();

  // 2) authorize this signer as an engine in 𝒩 (idempotent)
  if (!(await reader.isRegisteredEngine(me))) {
    tx = await admin.registerEngine(me, GAS);
    console.log("registerEngine  :", tx.hash);
    await tx.wait();
  } else {
    console.log("registerEngine  : (already in 𝒩)");
  }

  // 3) engine gives reputation, execution-bound by a settlement-tx proof
  tx = await engine.recordOutcome(
    {
      agentId,
      proof: {kind: ProofKind.SettledOnChain, ref: ethers.id(`settlement-${agentId}`)},
      counterpartyId: counterparty,
      trust: 1,
      performance: 1,
    },
    GAS,
  );
  console.log("recordOutcome   :", tx.hash);
  await tx.wait();

  // 4) read it back
  const score = await reader.scoreFor(agentId);
  console.log("\nscoreFor(agent) :", {
    trustFloat: score.trustFloat,
    performanceFloat: score.performanceFloat,
    n: score.n,
    distinctEngines: score.distinctEngines,
  });
  console.log("ownerOf(agent)  :", await reader.ownerOf(agentId), "(matches:", (await reader.ownerOf(agentId)) === agentOwner, ")");
  console.log("anid id         :", toAnid("bnb", agentOwner));

  if (score.trustFloat !== 0.1 || score.n !== 1) {
    throw new Error(`unexpected score: ${JSON.stringify(score)}`);
  }
  console.log("\nLIVE TESTNET E2E OK ✓");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
