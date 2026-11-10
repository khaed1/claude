#!/usr/bin/env python3
"""Builds the 4.1 spec page from the 4.0 page at commit dff405a plus the fragments in this folder.
Every replacement is asserted to match exactly once. Idempotent: always starts from the 4.0 file in git."""
import subprocess, pathlib, re, html.parser, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
FR = pathlib.Path(__file__).parent
OUT = ROOT / "reports" / "Murmuration v4 specification.html"
s = subprocess.run(["git", "show", "dff405a:reports/Murmuration v4 specification.html"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
frag = lambda n: (FR / n).read_text()

def rep(old, new, count=1):
    global s
    assert s.count(old) == count, f"expected {count} of {old[:70]!r}, found {s.count(old)}"
    s = s.replace(old, new)

def section_span(sec_id):
    a = s.index(f'<section id="{sec_id}">'); b = s.index("</section>", a) + len("</section>")
    assert s.count(f'<section id="{sec_id}">') == 1
    return a, b

def replace_section(sec_id, new):
    global s
    a, b = section_span(sec_id); s = s[:a] + new.strip("\n") + s[b:]

def insert_after_section(sec_id, new):
    global s
    a, b = section_span(sec_id); s = s[:b] + "\n\n" + new.strip("\n") + s[b:]

# ---- fragment fixes that depend on verified facts
review = frag("review.html")
def frep(text, old, new):
    assert text.count(old) == 1, old[:60]; return text.replace(old, new)
review = frep(review, "An independent reviewer that saw only the version 4 page was run in parallel, and its findings are merged in. Every finding below",
              "It was done by the same author who then changed the design, so the changes are themselves unreviewed until the review jobs in the <a href=\"#plan\">build plan</a> have run. Every finding below")
review = frep(review, "about 21 ETH or $45,000 of resalable capital, less for anyone who already holds many seats.",
              "about 21 ETH or $45,000 of resalable capital. One address already holds 77 seats and needs to buy nothing.")
review = frep(review, "so the largest seat holders end up with the largest share of the registry.",
              "so the largest seat holders end up with the largest share of the registry. The top ten addresses hold 382 of the 2,000 seats.")
token = frag("token.html")
token = frep(token, "<li>It is a market and a tie to IMD. It raises no money for the project: what buyers pay stays in the pool.</li>",
             "<li>IMD's launch factory was checked and is not used. It can issue a token with no owner and no mint, and its trading fee can go to a contract. But only IMD's own key can call it, it always gives 10% of supply to seat holders, and it would hold the position itself.</li>\n    <li>It is a market and a tie to IMD. It raises no money for the project: what buyers pay stays in the pool.</li>")
token = frep(token, "It is priced in IMD, a thin and volatile token (about $1.27M in its main pool, and an 18% move in two days this week). If IMD fails, this liquidity fails with it.",
             "It is priced in IMD, a thin and volatile token (about $1.14M in its main pool, which is not locked, and an 18% move in two days this week). IMD's owner key can mint IMD through its bridge settings. If IMD fails or is inflated, this liquidity fails with it.")

# ---- whole sections
replace_section("lifecycle", frag("lifecycle.html"))
replace_section("pool", frag("pool.html"))
replace_section("screening", frag("screening.html"))
replace_section("token", token)
replace_section("risks", frag("risks.html"))
replace_section("open", frag("open.html"))
build = frag("build_a.html").rstrip("\n") + "\n\n" + frag("build_b.html").rstrip("\n") + "\n\n" + frag("build_c.html")
assert build.count("<section") == 1 and build.count("</section>") == 1
insert_after_section("token", review + "\n\n" + build.strip("\n") + "\n\n" + frag("sim.html"))
insert_after_section("risks", frag("verify.html"))

# ---- hero
rep("Specification · version 4 · 10 Nov 2026 · Ethereum mainnet · built by the IMD swarm",
    "Specification · version 4.1, build-ready · 10 Nov 2026 · Ethereum mainnet · built by the IMD swarm")
rep("This page is the complete version 4 specification. Nothing in it is built or deployed yet.</p>",
    "This revision attacks the parts of version 4 that had never been reviewed, fixes what it found, and writes the result out so that a build job can work from it. Nothing in it is built or deployed yet.</p>")
rep("<div><b>3</b><span>circuits: deposit, transfer, withdraw</span></div>", "<div><b>1</b><span>circuit, where version 4 had three</span></div>")

# ---- nav
rep('''    <a href="#token">Token and fee</a>
    <a href="#periphery">The node and the wallet</a>''',
'''    <a href="#token">Token and fee</a>
    <a href="#review">Review of the new parts</a>
    <a href="#build">Build specification</a>
    <a class="sub" href="#b-notes">Keys and notes</a>
    <a class="sub" href="#b-circuit">The circuit</a>
    <a class="sub" href="#b-contracts">The six contracts</a>
    <a class="sub" href="#b-states">State machines</a>
    <a class="sub" href="#b-gas">Size and gas</a>
    <a class="sub" href="#b-deploy">Deployment and canary</a>
    <a href="#sim">Economics, simulated</a>
    <a href="#periphery">The node and the wallet</a>''')
rep('''    <a class="sub" href="#parameters">Fixed parameters</a>
    <a href="#legal">Legal position</a>''',
'''    <a class="sub" href="#parameters">Fixed parameters</a>
    <a href="#decisions">Defaults to confirm</a>
    <a href="#legal">Legal position</a>''')
rep('''    <a href="#roadmap">Roadmap</a>
    <a href="#cost">Cost</a>
    <a href="#risks">Risks</a>
    <a href="#open">Open questions</a>''',
'''    <a href="#roadmap">Roadmap</a>
    <a href="#plan">Build plan</a>
    <a href="#cost">Cost</a>
    <a href="#risks">Risks</a>
    <a href="#verified">What was checked</a>
    <a href="#open">Open questions</a>''')

# ---- overview
rep("a network of about 1,150 AI agents run by the holders of 1,999 seat NFTs", "a network of about 1,150 AI agents run by the holders of 2,000 seat NFTs")
rep("<td>Relay transactions, mirror the pool's public log, sign daily screening sets</td>", "<td>Relay transactions, mirror the pool's public log, agree daily screening batches</td>")
rep('''Each is covered in its own section.</p>
  </div>
</section>''',
'''Each is covered in its own section.</p>
  </div>
  <h3>What revision 4.1 changes</h3>
  <p>The first version 4 was written in one session and its new parts had not been reviewed. This revision reviewed them and changed the design where they failed. The owner's decisions are unchanged.</p>
  <ul>
    <li><strong>One circuit instead of three</strong>, with deposits computed by the contract and the machine-checked proofs covering withdrawals as well as transfers.</li>
    <li><strong>No fallback rule.</strong> Under version 4 a third of screeners could switch screening off by staying silent for a week. Now a stalled registry delays deposits and nothing else.</li>
    <li><strong>A reward index that cannot overpay</strong> or be farmed with dust, and that does not reveal the asset of a private transfer.</li>
    <li><strong>A buyback in place of the one-sided liquidity add</strong>, which whoever settled the auction could have taken.</li>
    <li><strong>Caps counted on activated value</strong>, with a recommended stop at 800 ETH per asset.</li>
    <li><strong>A canary that runs the whole system</strong> on a compressed clock, described as a rehearsal.</li>
  </ul>
  <p>The reasons are in <a href="#review">Review of the new parts</a>. Ten values still need the owner's confirmation and are listed in <a href="#decisions">Defaults to confirm</a>. The work is broken into 50 jobs in the <a href="#plan">build plan</a>.</p>
</section>''')

# ---- periphery
rep("<li>A PPOI node URL and an RPC endpoint of the operator's own. The broadcaster refuses any transaction without a valid proof of innocence for the required list.</li>",
    "<li>A PPOI node URL and an RPC endpoint of the operator's own. The broadcaster reads the URL from <code>POI_NODE_URL</code> and ships with it empty. Railgun's documentation publishes a community node at <code>ppoi.fdi.network</code> that any operator can use. The broadcaster refuses any transaction without a valid proof of innocence for the required list.</li>")
rep("<li><strong>Integration.</strong> Railgun's engine takes its quick-sync source as a parameter. The exact hook in engine 9.9.1 is still to be confirmed.</li>",
    "<li><strong>Integration.</strong> Railgun's engine 9.9.1 takes its quick-sync source as two arguments of <code>initForWallet</code>: <code>quickSyncEvents</code> and <code>quickSyncRailgunTransactionsV2</code>. Wallet SDK 11.3.0 passes its own subgraph functions with no option, so an application reassigns the two properties on the engine after start, or patches that one call. The engine checks commitments against on-chain roots, so a snapshot keeps event-batch boundaries. It does not check nullifier or unshield events, so the wallet module does. This was read in the code and not run.</li>")
rep("RPC_URL=…   PPOI_NODE_URL=…   IPFS_API=…", "RPC_URL=…   POI_NODE_URL=…   IPFS_API=…")

# ---- economics
rep("<tr><td>Attest</td><td>Unpaid on Railgun and Privacy Pools. In the pool, a share of the fee</td><td>Per day of agreement with the accepted root, never per use</td></tr>",
    "<tr><td>Attest</td><td>Unpaid on Railgun and Privacy Pools. In the pool, a share of the fee</td><td>Per day of agreement with the accepted batch, never per use</td></tr>")
rep("<td>40% to token stakers, 40% to the screeners who signed that day's accepted root, 20% to permanent liquidity. Nothing on transfers inside the pool</td>",
    "<td>40% to token stakers, 40% to the screeners who revealed that day's accepted batch, 20% to the token's market through the auction and buyback. Nothing on transfers inside the pool</td>")
rep("<tr><td>Seat delegation on EAS, once per seat per 90 days</td><td class=\"n\">about 231,000</td><td class=\"n\">$0.10</td><td class=\"n\">$0.21</td><td class=\"n\">$0.98</td></tr>",
    "<tr><td>Seat delegation on EAS, once per seat per 90 days</td><td class=\"n\">about 231,000</td><td class=\"n\">$0.10</td><td class=\"n\">$0.21</td><td class=\"n\">$0.98</td></tr>\n"
    "    <tr><td>Murmuration deposit, modelled</td><td class=\"n\">80,305</td><td class=\"n\">$0.03</td><td class=\"n\">$0.07</td><td class=\"n\">$0.34</td></tr>\n"
    "    <tr><td>Murmuration activation, modelled</td><td class=\"n\">749,604</td><td class=\"n\">$0.32</td><td class=\"n\">$0.67</td><td class=\"n\">$3.19</td></tr>\n"
    "    <tr><td>Murmuration spend, modelled</td><td class=\"n\">1,081,224</td><td class=\"n\">$0.46</td><td class=\"n\">$0.97</td><td class=\"n\">$4.61</td></tr>\n"
    "    <tr><td>Same spend, under Glamsterdam</td><td class=\"n\">1,300,864</td><td class=\"n\">$0.55</td><td class=\"n\">$1.16</td><td class=\"n\">$5.54</td></tr>")
rep('<tr><td>Privacy Pools-style Groth16 withdrawal, ETH to an existing account, today</td><td class="n">325,544</td><td class="n">$0.14</td><td class="n">$0.29</td><td class="n">$1.39</td></tr>',
    '<tr><td>Privacy Pools-style Groth16 withdrawal, ETH to an existing account, today</td><td class="n">about 294,000</td><td class="n">$0.13</td><td class="n">$0.26</td><td class="n">$1.25</td></tr>')
rep('<tr><td>Same, under Glamsterdam</td><td class="n">417,664</td><td class="n">$0.18</td><td class="n">$0.37</td><td class="n">$1.78</td></tr>',
    '<tr><td>Same, under Glamsterdam</td><td class="n">about 386,000</td><td class="n">$0.16</td><td class="n">$0.35</td><td class="n">$1.64</td></tr>')
rep('<tr><td>Same, under Glamsterdam, to a fresh account</td><td class="n">601,264</td><td class="n">$0.26</td><td class="n">$0.54</td><td class="n">$2.56</td></tr>',
    '<tr><td>Same, under Glamsterdam, to a fresh account</td><td class="n">about 570,000</td><td class="n">$0.24</td><td class="n">$0.51</td><td class="n">$2.43</td></tr>')
a = s.index('    <h3 id="parameters">'); b = s.index("</section>", a)
assert s.count('<h3 id="parameters">') == 1
s = s[:a] + frag("parameters.html").rstrip("\n") + "\n" + s[b:]
insert_after_section("economics", frag("decisions.html"))

# ---- legal
rep("the plan answers that with three small circuits, formal verification, per-asset limits, immutable caps and a fixed deposit window.",
    "the plan answers that with one small circuit, formal verification, per-asset limits, immutable caps and a fixed deposit window.")
rep('''The rule stays.</p>
</section>''',
'''The rule stays.</p>
  <div class="callout warn">
    <p><strong>This page is not legal advice.</strong> A lawyer reviews the fee, the token, the public pool and the founder allocation before launch. Because the canary places a token pool of its own, that review now comes before the canary.</p>
  </div>
</section>''')

rep("The pool contract enforces it at a deposit's first spend, and seat broadcasters enforce PPOI on Railgun.",
    "The pool contract enforces it when a deposit is activated, and seat broadcasters enforce PPOI on Railgun.")
rep("The screening set can be recomputed by anyone, so a wrong refusal is visible", "The screening batch can be recomputed by anyone, so a wrong refusal is visible")

# ---- compat
rep("The next developer calls are on 12 and 19 November.",
    "The next developer calls are on 12 and 19 November. On 9 November the Ethereum Foundation added a timeline to its post: audit reports on the 13th, a testing call on the 16th, and the execution call on the 19th with no decision promised. It reports four more contracts that could break and says the specifications could be revised, so every Glamsterdam gas figure on this page is provisional.")
rep("<td>Groth16 proofs are small. Snapshots and attestations never touch calldata</td>",
    "<td>Groth16 proofs are small. Snapshots and attestations never touch calldata. A spend's 1,312 bytes of ciphertext pay the ordinary rate, because the floor binds only transactions that carry little but data</td>")

# ---- roadmap
rep("<li><strong>Pool specification</strong>: the three circuits, the contracts, the token and the reward index written out in full, as public build and review jobs.</li>",
    "<li><strong>Pool specification</strong>: done in this revision. The circuit, the six contracts and the reward index are written out in the <a href=\"#build\">build specification</a>, with 50 draft job briefs in the <a href=\"#plan\">build plan</a>.</li>")
rep("<li><strong>Pool on testnet</strong>: circuits and contracts running on Sepolia, where the Glamsterdam gas rules are already live, with the wallet module and seat screeners.</li>",
    "<li><strong>Pool on testnet</strong>: the circuit and contracts running on Sepolia, where the Glamsterdam gas rules are already live, with the wallet module and seat screeners.</li>")
rep("PPOI node access for operators (no public default was found)", "PPOI node access for operators (a public community node exists; who runs it and on what terms is not known)")
a = s.index('  <div class="phase">\n    <div class="when">Phase 2'); b = s.index("</section>", a) + len("</section>")
s = s[:a] + frag("roadmap_p2.html").rstrip("\n") + s[b:]
insert_after_section("roadmap", frag("plan.html"))

# ---- cost
rep("<tr><td>IMD build and audit jobs</td><td class=\"n\">$3k to $13k</td><td>2,000 to 10,000 requests at 0.5 IMD, about $1.32 each</td></tr>",
    "<tr><td>IMD build and audit jobs</td><td class=\"n\">$0.4k to $13k</td><td>The build plan has 50 briefs. With rejected attempts, fixes and second audits, 300 to 600 requests at 0.5 IMD, about $1.32 each. The earlier figure of 10,000 requests is kept as the ceiling</td></tr>")
rep("<tr><td>Canary deposit</td><td class=\"n\">10 to 25 ETH ($21k to $53k)</td><td>Returned if the canary is not broken in 90 days</td></tr>",
    "<tr><td>Canary deposit</td><td class=\"n\">about $64k</td><td>10 ETH and the equivalent in USDC and DAI. Returned if the canary is not broken in 90 days</td></tr>")
rep("<tr><td>Screener stake</td><td class=\"n\">tokens</td><td>Amount fixed at deployment. Returned on exit after a delay</td></tr>",
    "<tr><td>Screener stake</td><td class=\"n\">0.05% of supply</td><td>Recommended. About $63 at the starting valuation. Returned 14 days after exit</td></tr>")
rep("<tr><td>Deposit</td><td>Gas, and 0.2% of the amount once it is approved and first spent</td></tr>",
    "<tr><td>Deposit</td><td>Gas for the deposit and for activation, about $0.35 together at 0.2 gwei by the model, and 0.2% of the amount at activation</td></tr>")
rep("<tr><td>Private transfer</td><td>Gas, about $0.50 at 0.2 gwei as a planning figure, plus a relay fee of about 10% of the gas</td></tr>",
    "<tr><td>Private transfer</td><td>Gas, about $0.46 at 0.2 gwei by the model, plus a relay fee of about 10% of the gas</td></tr>")

# ---- footer
rep("<p>Murmuration v4 specification, 10 November 2026. A proposal for review: no contract, circuit or node described here has been built, audited or deployed, and no transaction was made.",
    "<p>Murmuration v4 specification, revision 4.1, 10 November 2026. A proposal for review: no contract, circuit or node described here has been built, audited or deployed, no transaction was made, and nothing was sent to IMD, its developer or any third party. It is not legal advice.")

# ---- validate
class V(html.parser.HTMLParser):
    VOID = {"meta", "link", "br", "img", "hr", "input"}
    def __init__(self): super().__init__(); self.stack = []; self.ids = []; self.errors = []
    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if "id" in d: self.ids.append(d["id"])
        if tag not in self.VOID: self.stack.append((tag, self.getpos()))
    def handle_endtag(self, tag):
        if tag in self.VOID: return
        if not self.stack or self.stack[-1][0] != tag:
            self.errors.append(f"unexpected </{tag}> at {self.getpos()}, open: {self.stack[-1] if self.stack else None}")
            for i in range(len(self.stack) - 1, -1, -1):
                if self.stack[i][0] == tag: del self.stack[i:]; break
        else: self.stack.pop()
v = V(); v.feed(s)
assert not v.errors, v.errors[:5]
assert not v.stack, v.stack[:5]
assert len(v.ids) == len(set(v.ids)), [i for i in v.ids if v.ids.count(i) > 1]
for h in re.findall(r'href="#([^"]+)"', s): assert h in v.ids, f"dangling link #{h}"
assert s.count("<section") == s.count("</section>") == 20, (s.count("<section"), s.count("</section>"))
for bad in ("<!--GAS-->", "the three circuits, the contracts", "fallback rule approves", "accepted screening root"):
    assert bad not in s, bad
OUT.write_text(s)
print("ok", len(s), "bytes,", s.count("\n") + 1, "lines,", len(v.ids), "ids")
