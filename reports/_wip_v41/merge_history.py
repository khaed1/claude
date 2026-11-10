#!/usr/bin/env python3
"""Adds the revision 4.1 changelog and the second-pass review table to the history page. Starts from commit dff405a."""
import subprocess, pathlib, re, html.parser
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "reports" / "Murmuration privacy stack.html"
s = subprocess.run(["git", "show", "dff405a:reports/Murmuration privacy stack.html"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
def rep(old, new, count=1):
    global s
    assert s.count(old) == count, f"expected {count} of {old[:70]!r}, found {s.count(old)}"
    s = s.replace(old, new)

SPEC = '<a href="https://claude.ai/artifact/4BpAYUhRLVR3vv4u9RfsaB">version 4 specification</a>'

second_pass = f'''
  <h3>Second pass, 10 November 2026: the parts added in revisions 3 and 4</h3>
  <p>The pool, the token contracts, the fee auction and the screening registry were designed in one session and had not been reviewed. This pass put the same three questions to each. The full findings, the answers to eight specific questions and the resulting design changes are in the {SPEC}, under "Review of the new parts". Reasoning and checks are in <code>design_review_v3.md</code>. The review and the redesign were done by the same author, so the changes are unreviewed until the review jobs in the build plan have run.</p>
  <div class="tbl"><table class="wide">
    <tr><th>Part</th><th>Weakest assumption</th><th>Most likely failure</th><th>Overengineered</th></tr>
    <tr><td><strong>The pool</strong></td><td>That a reward index updated once a day, one per asset, can be used inside a private proof. A proof cannot name a number that moves, a per-asset number reveals the asset, and a daily step pays a note created at 23:59 for the whole day.</td><td>The pool sits full. Refunds are free and the cap was not tied to activated value, so one address can hold a 25 ETH cap for nothing.</td><td>Two of the three circuits. The deposit circuit proved a hash the contract can compute. Transfer and withdraw were one statement with a single number made public.</td></tr>
    <tr><td><strong>Token contracts</strong></td><td>That the launch transaction is the first to touch the token's market. Anyone can create and price a Uniswap pool for an address that has no code yet.</td><td>Unlocks meet no bids. 75% of supply unlocks over two years and the only exit liquidity is the IMD that buyers have paid in.</td><td>The screener stake as a security measure. Nothing can slash it, and at the starting valuation the whole supply is worth about $127,000.</td></tr>
    <tr><td><strong>Fee auction</strong></td><td>That liquidity can be added one-sided at "the current price". Whoever settles the auction sets the current price in the same transaction.</td><td>The 20% is taken by the settler: push the price up, let the contract place IMD bids under it, sell into them.</td><td>One auction per asset per day, each with its own start price and no reference for the first.</td></tr>
    <tr><td><strong>Screening registry</strong></td><td>That two thirds of screeners must be bought to defeat screening. Under the fallback rule one third is enough: stay silent for seven days.</td><td>Screeners copy the first root they see, because pay depends on agreement and computing costs more than copying.</td><td>Aggregated signatures chosen by the submitter. A Poseidon tree of approved labels that no circuit needs to read.</td></tr>
  </table></div>
'''

r41 = f'''
  <p><strong>Revision 4.1, 10 November 2026.</strong> A review of the parts that had never been reviewed, a build-ready specification, a simulation, and checks of seven assumptions. The owner's decisions are unchanged. Items marked "to confirm" change a default the owner had not confirmed and are listed for decision in the {SPEC} under "Defaults to confirm". File names refer to notes in the repository; those ending <code>_v3.md</code> are new.</p>
  <div class="tbl"><table class="wide">
    <tr><th>#</th><th>Change</th><th>Reason</th><th>Basis</th></tr>
    <tr><td class="n">R4.1-1</td><td>One circuit, Spend, replaces the deposit, transfer and withdraw circuits. Deposits need no proof: the pool computes the commitment</td><td>The deposit circuit proved a hash the contract can compute. Transfer and withdraw were one statement. The launch gate had required a proof of only one of the three</td><td><code>design_review_v3.md</code>, finding 9</td></tr>
    <tr><td class="n">R4.1-2</td><td>Activation is a public call by the depositor once a screening batch covers the deposit. The first-spend screening proof is removed. A refund is possible at any time before activation</td><td>Deposit and approval are both public, so the check needs no zero-knowledge. It lets the contract write the exact reward index at entry. Activation by anyone would remove the free refund</td><td><code>design_review_v3.md</code>, section 2</td></tr>
    <tr><td class="n">R4.1-3</td><td>The seven-day fallback rule is removed. The threshold is two thirds of active screeners, with at least seven active, and silent screeners are dropped after seven days. To confirm</td><td>One third of registered screeners could switch screening off by staying silent: 8 seats, about 5.6 ETH, against 15 honest ones. The fallback also tied the pool to an oracle with an owner key</td><td><code>design_review_v3.md</code>, finding 1</td></tr>
    <tr><td class="n">R4.1-4</td><td>Screeners commit and reveal a batch each day. Refusals are a bitmap read at activation. Screeners can post flags that the published rule turns into refusals. New screeners count after 30 days and stakes return after 14</td><td>Pay for agreement rewarded copying. An aggregator could leave signers out. Fresh thefts are on no list. Seats could be bought, used once and sold</td><td><code>design_review_v3.md</code>, findings 5 and 6; seat distribution in <code>imd_launch_factory_v3.md</code>, section 6</td></tr>
    <tr><td class="n">R4.1-5</td><td>One reward index for all assets with fixed weights. Exact value at activation, a checkpoint every 300 blocks for spends, a floor on the divisor at a quarter of capacity, and the reward carried inside the note until claimed in an ordinary spend</td><td>The daily per-asset index could pay more than the budget, gave a dust depositor a whole period's emission, could not be referenced by a proof, and revealed the asset of a private transfer</td><td><code>design_review_v3.md</code>, finding 2; <code>reports/sim/results.md</code>, section 4</td></tr>
    <tr><td class="n">R4.1-6</td><td>The 20% share is sold in one continuous descending-price auction for the whole basket. The IMD then buys the token from the locked pool in limited steps and the tokens are burned. The one-sided liquidity add is removed. To confirm</td><td>Whoever settled the auction could set the price, let the contract place its IMD under it, and sell into it in the same transaction. A buyback step below the pool's fee rate times its reserves cannot be sandwiched at a profit</td><td><code>reports/sim/sandwich_results.md</code>; Euler <a href="https://github.com/euler-xyz/fee-flow">fee-flow</a> source, 10 Nov; <code>design_review_v3.md</code>, section 3</td></tr>
    <tr><td class="n">R4.1-7</td><td>The cap is counted on activated value only. A stop at 800 ETH per asset is recommended. To confirm</td><td>A free refundable deposit could hold the cap shut. Without a stop, three assets hold about $41M after two years and the doubling continues</td><td><code>reports/sim/results.md</code>, section 4; <code>design_review_v3.md</code>, finding 4</td></tr>
    <tr><td class="n">R4.1-8</td><td>The relayer is paid with a shielded note in the same proof. Every exit of a size pays out the same amount. Exit sizes start at 0.001 ETH and 1 unit of a stablecoin. To confirm</td><td>A public fee reveals the asset of a transfer and marks each exit with the fee quoted. Dust below the smallest size can never leave once deposits close</td><td><code>design_review_v3.md</code>, finding 10</td></tr>
    <tr><td class="n">R4.1-9</td><td>Note encryption is specified as HPKE over X-Wing, one recipient ciphertext per spend. Its cost is corrected from about 70,000 gas per note to about 31,500 gas per spend</td><td>The calldata floor applies only to transactions that carry little but data. A hand-made hybrid is replaced by the specified one</td><td><code>gas_model_and_pq_cost_v3.md</code>; <a href="https://eips.ethereum.org/EIPS/eip-7623">EIP-7623</a>, <a href="https://eips.ethereum.org/EIPS/eip-7976">EIP-7976</a>; draft-connolly-cfrg-xwing-kem-11</td></tr>
    <tr><td class="n">R4.1-10</td><td>The public pool is a Uniswap v3 pool at the 1% tier, placed by the Distribution contract. Launch handles a pool that someone created and priced first. IMD's launch factory is ruled out</td><td>Uniswap's factory does not check that a token exists. IMD's factory can be called only by IMD's key, always gives 10% of supply to seat holders, and holds the position itself</td><td>Uniswap v3-core v1.0.0 source; <code>imd_launch_factory_v3.md</code></td></tr>
    <tr><td class="n">R4.1-11</td><td>Each fee sweep is paid to stakers evenly over the following seven days</td><td>Fees arriving in lumps could be taken by staking just before a sweep and leaving just after</td><td><code>design_review_v3.md</code>, finding 11</td></tr>
    <tr><td class="n">R4.1-12</td><td>The canary is the whole system with a compressed clock and a published script that calls every function. The lawyer's review moves to before the canary</td><td>Ninety days at the real pace reaches no schedule boundary, no second asset and none of the token paths. A canary with those paths places a public token pool</td><td><code>design_review_v3.md</code>, finding 8</td></tr>
    <tr><td class="n">R4.1-13</td><td>The circuit is written in Lean 4 with the <code>clean</code> framework, proved against statements frozen in advance, with an independent Circom copy as a test oracle and an explicit check of the verification key</td><td>It is the one route with a public record on a comparable circuit and agent-written proofs. The push-button checkers stall on hashes. Two verifiers were drained in February 2026 over a skipped setup step</td><td><code>circuit_proof_tooling_v3.md</code></td></tr>
    <tr><td class="n">R4.1-14</td><td>Launch gate: proofs of five properties covering the whole circuit, against statements the owner signs off; the lawyer's review before the canary; a complete canary script</td><td>Follows from R4.1-1, R4.1-12 and R4.1-13</td><td>{SPEC}, Roadmap</td></tr>
    <tr><td class="n">R4.1-15</td><td>Deployment through a one-time staged deployer, one contract per transaction. The pool uses the poseidon-solidity hash contracts already on mainnet</td><td>The six contracts refer to each other and do not fit one transaction under EIP-8037</td><td><code>gas_model_and_pq_cost_v3.md</code>, part 3</td></tr>
    <tr><td class="n">R4.1-16</td><td>A two-year linear vest is recommended for the swarm's 10%. To confirm. The share of supply that unlocks is corrected from 70% to 75%</td><td>The owner's rule is that every schedule runs two years, and a one-year release is the largest early unlock</td><td><code>reports/sim/results.md</code>, section 2</td></tr>
    <tr><td class="n">R4.1-17</td><td>Sections added to the specification: Review of the new parts, Build specification, Economics simulated, Defaults to confirm, Build plan, What was checked. Fifty draft job briefs saved under <code>reports/build_plan/</code>. None submitted</td><td>Requested for this revision</td><td>{SPEC}</td></tr>
  </table></div>
  <h3>Facts checked or corrected in revision 4.1</h3>
  <div class="tbl"><table class="wide">
    <tr><th>Item</th><th>Was</th><th>Now</th><th>Source</th></tr>
    <tr><td>IMD launch factory</td><td class="was">"Neither has been checked"</td><td>It can issue a token with no owner and no mint, and its fee (80% of a 1.25% Uniswap v4 pool fee) can go to a contract. Only IMD's deployer key can call it. 10% of supply always goes to seat holders</td><td>Sourcify and chain reads, 10 Nov, in <code>imd_launch_factory_v3.md</code></td></tr>
    <tr><td>IMD and circuit audits</td><td class="was">"Nothing in the research shows that IMD has audited a zero-knowledge circuit"</td><td>Searched: 432 to 450 public audits, none of a circuit. The audit template is a Solidity checklist with no mention of circuits. IMD's verifier builds and tests Foundry code only</td><td><a href="https://imd.fun/docs/">IMD docs</a> and API, 10 Nov, in <code>imd_audit_and_jobs_v3.md</code></td></tr>
    <tr><td>IMD token</td><td class="was">$1.27M in its main pool</td><td>About $1.14M in an unlocked Uniswap v4 pool. An owner key sets the bridge peers that can mint. No transfer tax, blocklist or pause</td><td>Chain reads, 10 Nov, same note, section 5</td></tr>
    <tr><td>Seats</td><td class="was">1,999 seats, 795 owners</td><td>2,000 seats at 791 addresses. Largest 77, top five 243, top ten 382</td><td>Chain reads, 10 Nov, same note, section 6</td></tr>
    <tr><td>IMD network and worker</td><td class="was">1,149 agents, 871 online, 118 working; worker 0.1.16</td><td>1,151 agents, 844 online, 6 working at 14:50 UTC. Worker 0.1.17 of 10 Nov with goal fixes. Custody still off, no paid goal action</td><td><a href="https://explorer.imd.fun/status">explorer.imd.fun</a>; <a href="https://github.com/Identity-md/worker">Identity-md/worker</a>, 10 Nov</td></tr>
    <tr><td>PPOI node access</td><td class="was">"No public default was found"</td><td>A community node at <code>ppoi.fdi.network</code> is published in Railgun's docs and SDK defaults and answered. Operator and terms unknown</td><td><code>railgun_ppoi_quicksync_v3.md</code></td></tr>
    <tr><td>Railgun quick-sync hook</td><td class="was">"Still to be confirmed"</td><td>Engine 9.9.1 takes <code>quickSyncEvents</code> and <code>quickSyncRailgunTransactionsV2</code> in <code>initForWallet</code>. Wallet SDK 11.3.0 hard-wires its own. Read, not run</td><td>npm packages, 10 Nov, same note</td></tr>
    <tr><td>Post-quantum ciphertext cost</td><td class="was">"Roughly 70,000 gas each at the Glamsterdam calldata floor"</td><td>About 29,000 gas for a 1,216-byte ciphertext inside a spend, today and under Glamsterdam. 69,640 today and 98,824 under Glamsterdam only if sent alone</td><td><code>gas_model_and_pq_cost_v3.md</code></td></tr>
    <tr><td>Groth16 withdrawal gas</td><td class="was">325,544 today, 417,664 under Glamsterdam</td><td>About 294,000 and 386,000. The earlier arithmetic counted the base cost and calldata twice</td><td>Same note, part 2</td></tr>
    <tr><td>Glamsterdam</td><td class="was">Next calls 12 and 19 Nov</td><td>The Ethereum Foundation added a timeline on 9 Nov: audit reports 13 Nov, testing call 16 Nov, execution call 19 Nov with no decision promised. Revisions to EIP-8037 and EIP-8038 are a stated possibility. Both EIP texts unchanged. Still no date</td><td><a href="https://blog.ethereum.org/2026/11/06/glamsterdam-8037-8038">EF blog</a>, update of 9 Nov, in <code>status_changes_v3.md</code></td></tr>
    <tr><td>US v. Storm</td><td class="was">No ruling found through 9 Nov</td><td>Unchanged through 10 Nov. Retrial still 26 April 2027</td><td>Same note, part B</td></tr>
    <tr><td>FinCEN</td><td class="was">Not in the notes</td><td>Withdrew its 2020 recordkeeping and travel-rule proposal on 6 Nov, the third digital-asset proposal withdrawn in five weeks</td><td><a href="https://www.fincen.gov/news/press-releases">fincen.gov</a>, same note, part C</td></tr>
  </table></div>
  <h3>Not verified in revision 4.1</h3>
  <ul>
    <li>Every gas figure for the pool, the constraint count and proving time. Nothing was built.</li>
    <li>That the <code>clean</code> framework's exporter is correct and that its unmerged Poseidon proofs build.</li>
    <li>A real request to the public PPOI node, and replacing quick-sync in a running wallet.</li>
    <li>The Storm docket between 20 October and 8 November at docket level, and the Pertsev appeal.</li>
    <li>How many people stand behind the 791 seat addresses.</li>
    <li>Whether Uniswap governance takes a share of fees on v3 pools at the 1% tier.</li>
    <li>The design changes of this revision, which nobody but their author has read. An independent second review was started and lost to a usage limit.</li>
  </ul>
'''

rep('''<section id="changelog">
  <h2>Changelog</h2>
  <p><strong>Revision 4, 10 November 2026.</strong>''', '''<section id="changelog">
  <h2>Changelog</h2>''' + r41 + '''  <p><strong>Revision 4, 10 November 2026.</strong>''')
rep('''  </table></div>
</section>

<section id="changelog">''', '''  </table></div>''' + second_pass + '''</section>

<section id="changelog">''')
rep('<p>Revision 4, 10 November 2026. This page replaces the earlier versions at the same address;',
    '<p>Revision 4, 10 November 2026, with the review findings and changelog of revision 4.1 added the same day. The current specification is the separate page at <a href="https://claude.ai/artifact/4BpAYUhRLVR3vv4u9RfsaB">claude.ai/artifact/4BpAYUhRLVR3vv4u9RfsaB</a>, and where the two differ that page is the one to follow. This page replaces the earlier versions at the same address;')

class V(html.parser.HTMLParser):
    VOID = {"meta", "link", "br", "img", "hr", "input"}
    def __init__(self): super().__init__(); self.stack = []; self.ids = []; self.errors = []
    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if "id" in d: self.ids.append(d["id"])
        if tag not in self.VOID: self.stack.append((tag, self.getpos()))
    def handle_endtag(self, tag):
        if tag in self.VOID: return
        if not self.stack or self.stack[-1][0] != tag: self.errors.append((tag, self.getpos()))
        else: self.stack.pop()
v = V(); v.feed(s)
assert not v.errors and not v.stack, (v.errors[:5], v.stack[:5])
assert len(v.ids) == len(set(v.ids))
for h in re.findall(r'href="#([^"]+)"', s): assert h in v.ids, h
OUT.write_text(s)
print("ok", len(s), "bytes,", s.count("\n") + 1, "lines")
