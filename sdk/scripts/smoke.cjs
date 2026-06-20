/**
 * End-to-end smoke test: deploy the four registries to a local node via the
 * generated factories, then drive them through the SDK's reader / writer / admin.
 *
 *   anvil &                       # in another shell
 *   pnpm build && node scripts/smoke.cjs
 */
const {ethers} = require("ethers");
const {
  EngineRegistry__factory,
  IdentityRegistry__factory,
  ValidationRegistry__factory,
  ReputationRegistry__factory,
  AnidReader,
  EngineClient,
  AdminClient,
  ProofKind,
  agentIdToBytes32,
  toAnid,
} = require("../dist/index.js");

async function main() {
  const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");
  const signer = await provider.getSigner(0); // anvil unlocked account 0
  const me = await signer.getAddress();

  // --- deploy via generated factories (bytecode is bundled in the ABIs) ---
  const identity = await new IdentityRegistry__factory(signer).deploy();
  await identity.waitForDeployment();
  const engine = await new EngineRegistry__factory(signer).deploy(me);
  await engine.waitForDeployment();
  const validation = await new ValidationRegistry__factory(signer).deploy();
  await validation.waitForDeployment();
  const lambda = (10n ** 18n * 9n) / 10n; // 0.9
  const reputation = await new ReputationRegistry__factory(signer).deploy(
    await engine.getAddress(),
    await identity.getAddress(),
    lambda,
  );
  await reputation.waitForDeployment();

  const addresses = {
    identity: await identity.getAddress(),
    engine: await engine.getAddress(),
    reputation: await reputation.getAddress(),
    validation: await validation.getAddress(),
  };

  const alice = ethers.Wallet.createRandom().address;
  const bob = ethers.Wallet.createRandom().address;

  // --- governance: register two agents + the engine (this signer) ---
  const admin = new AdminClient(addresses, signer);
  await (await admin.registerAgent(1n, alice)).wait();
  await (await admin.registerAgent(2n, bob)).wait();
  await (await admin.registerEngine(me)).wait();

  // --- engine writes one +1.0 execution-bound outcome for agent 1 ---
  const engineClient = new EngineClient(addresses, signer);
  await (
    await engineClient.recordOutcome({
      agentId: 1n,
      proof: {kind: ProofKind.SettledOnChain, ref: ethers.id("settlement-tx-1")},
      counterpartyId: agentIdToBytes32(2n), // bob — independent of alice
      trust: 1,
      performance: 1,
    })
  ).wait();

  // --- read it back ---
  const reader = new AnidReader(addresses, provider);
  const score = await reader.scoreFor(1n);
  console.log("addresses           :", addresses);
  console.log("score(agent 1)      :", score);
  console.log("ownerOf(agent 1)    :", await reader.ownerOf(1n), "(alice)");
  console.log("isRegisteredEngine  :", await reader.isRegisteredEngine(me));
  console.log("anid id (alice)     :", toAnid("bnb", alice));

  // EMA: trust = 0.9*0 + 0.1*1.0 = 0.1
  if (score.trustFloat !== 0.1) throw new Error(`expected trustFloat 0.1, got ${score.trustFloat}`);
  if (score.n !== 1 || score.distinctEngines !== 1) throw new Error("bad provenance");
  console.log("\nSMOKE OK ✓");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
