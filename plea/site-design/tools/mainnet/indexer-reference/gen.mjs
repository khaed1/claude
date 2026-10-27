// Writes abis/*.ts and ponder.config.ts from a PLEA build and an addresses file (deploy.mjs's, or the launch's).
//   node gen.mjs <forge out dir> <addresses.json> <rpc url> [chain id]
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
const [out, addrFile, rpc, chainId = "1"] = process.argv.slice(2);
const A = JSON.parse(readFileSync(addrFile, "utf8"));
const names = ["PLEA", "CabalGate", "Seasons", "PleaDistributor", "PleaLaunch", "Letterbox", "Tribunal", "PleaHook"];
mkdirSync("abis", { recursive: true });
for (const n of names) writeFileSync(`abis/${n}.ts`, `export const ${n}Abi = ${JSON.stringify(JSON.parse(readFileSync(`${out}/${n}.sol/${n}.json`, "utf8")).abi)} as const;\n`);
writeFileSync("ponder.config.ts", `import { createConfig } from "ponder";
${names.map((n) => `import { ${n}Abi } from "./abis/${n}";`).join("\n")}
export default createConfig({
  chains: { mainnet: { id: ${chainId}, rpc: ${JSON.stringify(rpc)} } },
  contracts: {
${names.map((n) => `    ${n}: { chain: "mainnet", abi: ${n}Abi, address: "${A[n]}", startBlock: ${A.deployBlock} },`).join("\n")}
  },
});
`);
console.log("wrote abis/ and ponder.config.ts");
