#!/usr/bin/env python3
"""Run 8.5 (launch #1981, Sepolia) live-test helper: thin wrappers over Foundry's `cast`.

Keys: wallet A from env PONDPAD_TESTNET_KEY; players from $STATE_DIR/players.env (mode 600).
No key is ever printed or logged. Every send is estimated first and sent with gas = estimate x 1.3.
Wallet A refuses to send while another of its transactions is pending (the imd/acc session shares it).

Env:
  STATE_DIR  required: players.env / players.json / log.jsonl (a scratch dir, never inside a git checkout)
  RPC        JSON-RPC URL (default: Sepolia publicnode)
  FORK=1     local anvil fork: wallet A and the Intake writer are impersonated, fork-* commands on
  GAS_PRICE  max fee (default 0.02gwei); PRIO priority fee (default 0.01gwei)

Rehearsal on a local fork (nothing reaches Sepolia; fork-init points the gate's and the Tribunal's
oracleSigner at a test key so fork-answer can sign verdicts):
  anvil --fork-url https://ethereum-sepolia-rpc.publicnode.com --port 8545 --silent &
  RPC=http://127.0.0.1:8545 FORK=1 STATE_DIR=<scratch>/fork python3 -I live85.py fork-init

Usage: python3 -I live85.py <command> [args]   (python3 -I live85.py help)
"""
import json
import os
from decimal import Decimal
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
STATE = os.environ.get("STATE_DIR", "")
RPC = os.environ.get("RPC", "https://ethereum-sepolia-rpc.publicnode.com")
FORK = os.environ.get("FORK") == "1"
GAS_PRICE = os.environ.get("GAS_PRICE", "0.02gwei")
PRIO = os.environ.get("PRIO", "0.01gwei")
CAST = os.environ.get("CAST", "/root/.local/bin/cast")

# ---------------------------------------------------------------- run 8.5 (launch #1981)
PLEA = "0xd395ad74f5c31c8afe6316be3b8041be8bac5d1c"
GATE = "0xe1d723b40f6faaf4bd4db7ace93e12544539135a"
SEASONS = "0x331ba80c6f8bad20d73fd30256006a6671813227"
DISTRIBUTOR = "0x1ba83d21c73d75ac79b997ab2f1e20b415daa378"
LAUNCH = "0x88a2d29c6ce265e1990252b33c60753d4018ad0f"
LETTERBOX = "0x993eb617a0d6ad72eD0727aA734c36241bf2448C"
TRIBUNAL = "0x5b3aB1f9A461995f342e1aD7124B974FD52739F1"
HOOK = "0x48f607FbdBD955e283C57A28E57309b8Ec9028cC"
# ---------------------------------------------------------------- Sepolia externals
IMD = "0x2B69099E59b05901faA1DD164fabf098bf831E82"  # TestIMD, faucet() 10k / 24h
ORACLE = "0x44a1Cd38474FB1748400E7DEb5F8D786ccE3F89A"  # oracle-fee token, open mint(to, amount)
INTAKE = "0xa43e6f75ee006411f79ac1c84120606c2330de82"
WRITER = "0x3d3C0Df7C1a17d384545e9D7C8228897bD9625CB"
PST = "0x9b6b46e2c869aa39918db7f52f5557fe577b6eee"  # PoolSwapTest
SEAT = "0xa0443799c320E16C80801c9C1911F3571260287F"  # seat NFT (test), open mint(tokenId)
SIMD = "0xF9e2EEc3B610ec6781f7438aC5Fb4bc049d81Cc1"
WALLET_A = "0x4b91078b2374c956A65F7Af0999CaE0a935E6821"

# Another run's addresses (run 9: imdTEST as pool currency and oracle fee): ADDRS=<json> with any of
# PLEA GATE SEASONS DISTRIBUTOR LAUNCH LETTERBOX TRIBUNAL HOOK IMD ORACLE. ORACLE == IMD means the
# oracle fee is paid in the pool's IMD (no minting, no faucet: wallet A hands imdTEST out with `give`).
if os.environ.get("ADDRS"):
    for _k, _v in json.load(open(os.environ["ADDRS"])).items():
        if _k in ("PLEA", "GATE", "SEASONS", "DISTRIBUTOR", "LAUNCH", "LETTERBOX", "TRIBUNAL", "HOOK", "IMD", "ORACLE"):
            globals()[_k] = _v
ONE_TOKEN = IMD.lower() == ORACLE.lower()
POOL_MANAGER = "0xE03A1074c86CFeDd5C142C4F04F1a1536e203543"

MIN_SQRT_PRICE_PLUS_1 = "4295128740"
MAX_SQRT_PRICE_MINUS_1 = "1461446703485210103287273052203988822378723970341"
MAX = str(2**256 - 1)
E18 = 10**18

PLEA_T = "(address,uint8,uint8,uint8,uint8,bool,bool,uint8,uint128,uint64,uint64,uint64,bytes32,string)"
PLEA_F = ["seller", "factScore", "need", "score", "status", "appealed", "isAppeal", "flags", "amount",
          "submittedAt", "verdictAt", "originalId", "intakeId", "text"]
STATUS = ["None", "Pending", "Approved", "Denied", "Executed", "Lapsed", "Expired"]
OBJ_T = "(uint64,address,uint8,uint8,bool,uint64,bytes32,string)"
OBJ_F = ["pleaId", "objector", "ruling", "newScore", "settled", "filedAt", "intakeId", "text"]
RULING = ["None", "Pending", "Sustained", "Overruled", "Void"]
ATT_T = "(bytes32,uint256,bytes32,uint8,bytes,uint256,uint64,uint64,bytes32,bytes32,uint16,uint16,uint16,uint64,uint64)"
FORK_SIGNER_KEY = "0x" + "00" * 29 + "0a11ce"  # test key, only ever written into a local fork


def wei(x):
    """Exact token units from a decimal string ("90000" -> 90000e18); float would be off by a few wei."""
    return int(Decimal(str(x)) * E18)


class Fail(Exception):
    pass


# ---------------------------------------------------------------- cast plumbing

def _run(args, secret=None):
    """Runs cast; `secret` is redacted from any error text."""
    p = subprocess.run([CAST] + args, capture_output=True, text=True)
    if p.returncode != 0:
        err = (p.stderr or p.stdout).strip()
        if secret:
            err = err.replace(secret, "<key>")
        raise Fail(err[-1500:] + _error_names(err))
    return p.stdout.strip()


def _error_names(err):
    """Names every known custom-error selector found in a revert (also inside v4's WrappedError)."""
    path = os.path.join(HERE, "live85-errors.json")
    if not os.path.exists(path):
        return ""
    table = json.load(open(path))
    low = err.lower()
    found = [sig for sel, sig in table.items() if sel[2:] in low]
    return ("\n  = " + ", ".join(found)) if found else ""


def call(to, sig, *args, block=None):
    a = ["call", to, sig, *map(str, args), "--rpc-url", RPC]
    if block:
        a += ["--block", str(block)]
    return _run(a)


def call_json(to, sig, *args):
    return json.loads(_run(["call", to, sig, *map(str, args), "--rpc-url", RPC, "--json"]))


def num(s):
    """First integer in a cast output line ('123 [1.23e2]' -> 123)."""
    return int(str(s).split()[0], 0)


def rpc(method, *params):
    return _run(["rpc", method, *[json.dumps(p) if not isinstance(p, str) else p for p in params],
                 "--rpc-url", RPC])


def now():
    return int(_run(["block", "latest", "-f", "timestamp", "--rpc-url", RPC]))


# ---------------------------------------------------------------- wallets

def players():
    path = os.path.join(STATE, "players.json")
    return json.load(open(path)) if os.path.exists(path) else {}


def _player_key(name):
    label = _derive_label()
    if label:
        return _derived_key(label, int(name.lstrip("p")))
    path = os.path.join(STATE, "players.env")
    for line in open(path):
        k, _, v = line.strip().partition("=")
        if k == name.upper() + "_KEY":
            return v
    raise Fail(f"no key for {name}")


def _derive_label():
    path = os.path.join(STATE, "players.derive")
    return open(path).read().strip() if os.path.exists(path) else ""


def _derived_key(label, i):
    """Player i's key = keccak256(wallet A's key ++ utf8(label + i)): a container restart cannot strand
    the players' funds, and no player key is ever written down."""
    key = os.environ.get("PONDPAD_TESTNET_KEY", "")
    if FORK and not key:
        key = "0x" + "00" * 31 + "a1"  # fork rehearsal without the real key
    if len(key.removeprefix("0x")) != 64:
        raise Fail("PONDPAD_TESTNET_KEY not set")
    from distributor_root import keccak256
    return "0x" + keccak256(bytes.fromhex(key.removeprefix("0x")) + f"{label}{i}".encode()).hex()


def addr(name):
    if name.lower() == "a":
        return WALLET_A
    if name == "writer":
        return WRITER
    if name.startswith("0x") and len(name) == 42:
        return name
    p = players()
    if name not in p:
        raise Fail(f"unknown wallet {name}")
    return p[name]


def _signer_args(name):
    if name.lower() == "a":
        if FORK:
            return ["--unlocked", "--from", WALLET_A], None
        key = os.environ.get("PONDPAD_TESTNET_KEY")
        if not key:
            raise Fail("PONDPAD_TESTNET_KEY not set")
        return ["--private-key", key], key
    if name == "writer":
        if not FORK:
            raise Fail("the writer is only impersonated on a fork")
        return ["--unlocked", "--from", WRITER], None
    key = _player_key(name)
    return ["--private-key", key], key


def _log(entry):
    with open(os.path.join(STATE, "log.jsonl"), "a") as f:
        f.write(json.dumps(entry) + "\n")


def send(name, to, sig=None, *args, data=None, value=None, gas=None, quiet=False):
    """Estimate, send with gas x 1.3, wait, return the receipt dict. Raises on a revert."""
    frm = addr(name)
    if name.lower() == "a" and not FORK:
        latest = int(_run(["nonce", frm, "--rpc-url", RPC]))
        pending = int(_run(["nonce", frm, "--block", "pending", "--rpc-url", RPC]))
        if latest != pending:
            raise Fail(f"wallet A has a pending transaction (nonce latest {latest}, pending {pending})")
    # Raw calldata (a letter) goes where the signature would: cast estimate has no --data.
    target = [to] + ([sig, *map(str, args)] if sig else ([data] if data else []))
    extra = ["--value", str(value)] if value else []
    if gas is None:
        est = int(_run(["estimate", "--from", frm, *target, *extra, "--rpc-url", RPC]))
        gas = est * 13 // 10
    signer, secret = _signer_args(name)
    out = _run(["send", *target, *extra, *signer, "--rpc-url", RPC, "--gas-limit", str(gas),
                "--gas-price", GAS_PRICE, "--priority-gas-price", PRIO, "--json", "--timeout", "300"],
               secret=secret)
    rc = json.loads(out)
    st = int(rc["status"], 16)
    used = int(rc["gasUsed"], 16)
    _log({"t": int(time.time()), "fork": FORK, "from": name, "to": to, "sig": sig, "args": [str(a) for a in args],
          "data": (data[:200] if data else None), "value": value, "tx": rc["transactionHash"],
          "block": int(rc["blockNumber"], 16), "status": st, "gas": used, "limit": gas})
    if not quiet:
        what = sig or (f"letter {len(data) // 2 - 1} bytes" if data else f"{value} to {to}")
        print(f"  {name} -> {what}: tx {rc['transactionHash']} "
              f"block {int(rc['blockNumber'], 16)} status {st} gas {used:,}")
    if st != 1:
        raise Fail(f"reverted on chain: {rc['transactionHash']}")
    return rc


# ---------------------------------------------------------------- reads

def plea_of(pid):
    v = call_json(GATE, f"getPlea(uint256)({PLEA_T})", pid)[0]
    vals = _tuple(v)
    d = dict(zip(PLEA_F, vals))
    d["status"] = STATUS[int(d["status"])]
    return d


def _tuple(v):
    """cast --json returns a tuple as a string '(a, b, ...)' or a list; normalise to a list."""
    if isinstance(v, list):
        return v
    s = v.strip()
    if s.startswith("(") and s.endswith(")"):
        s = s[1:-1]
    out, depth, cur, q = [], 0, "", False
    for ch in s:
        if ch == '"':
            q = not q
        if ch == "," and depth == 0 and not q:
            out.append(cur.strip())
            cur = ""
            continue
        if not q and ch in "([":
            depth += 1
        if not q and ch in ")]":
            depth -= 1
        cur += ch
    if cur.strip():
        out.append(cur.strip())
    return [x.strip('"') for x in out]


def objection_of(oid):
    v = call_json(TRIBUNAL, f"objection(uint256)({OBJ_T})", oid)[0]
    d = dict(zip(OBJ_F, _tuple(v)))
    d["ruling"] = RULING[int(d["ruling"])]
    return d


def bal(token, who):
    return num(call(token, "balanceOf(address)(uint256)", addr(who)))


def fmt(x, d=18):
    return f"{x / 10**d:,.4f}"


def pool_key():
    return call(HOOK, "poolKey()((address,address,uint24,int24,address))")


# ---------------------------------------------------------------- commands

def cmd_state(*_):
    t = now()
    print(f"block time {t} ({time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(t))} UTC)")
    started = num(call(GATE, "startedAt()(uint64)"))
    print(f"gate startedAt {started} cabalAlive {call(GATE, 'cabalAlive()(bool)')} diedAt {num(call(GATE, 'diedAt()(uint64)'))}"
          f" lastVerdictAt {num(call(GATE, 'lastVerdictAt()(uint64)'))} nextId {num(call(GATE, 'nextId()(uint256)'))}")
    if started:
        print(f"season {call(SEASONS, 'currentSeason()(bool,uint256,uint64)').split()} pot {fmt(num(call(SEASONS, 'pot()(uint256)')))} tIMD")
        print(f"hook tick {call(HOOK, 'currentTick()(int24)')} launchExtraBps {num(call(HOOK, 'launchExtraBps()(uint256)'))}"
              f" pleaInMarket {fmt(num(call(HOOK, 'pleaInMarket()(uint256)')))} imdInMarket {fmt(num(call(HOOK, 'imdInMarket()(uint256)')))}"
              f" pendingRebalance {call(HOOK, 'pendingRebalance()(bool)')}")
    print(f"Letterbox custody {fmt(bal(PLEA, LETTERBOX))} PLEA, {fmt(bal(IMD, LETTERBOX))} tIMD")
    for n in ["a"] + list(players()):
        a = addr(n)
        eth = int(_run(["balance", a, "--rpc-url", RPC]))
        print(f"  {n:4} {a} ETH {fmt(eth)} tIMD {fmt(bal(IMD, a))} PLEA {fmt(bal(PLEA, a))}")


def cmd_new_players(n, *_):
    """Creates n throwaway wallets p1..pn (keys only in players.env, mode 600)."""
    keyfile = os.path.join(STATE, "players.env")
    if os.path.exists(keyfile):
        raise Fail("players.env exists; refusing to overwrite")
    ws = json.loads(_run(["wallet", "new", "--number", str(n), "--json"]))
    ws = ws["data"] if isinstance(ws, dict) else ws  # cast 1.8 wraps the list in {"data": [...]}
    fd = os.open(keyfile, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as f:
        for i, w in enumerate(ws, 1):
            f.write(f"P{i}_KEY={w['private_key']}\n")
    pj = {f"p{i}": w["address"] for i, w in enumerate(ws, 1)}
    json.dump(pj, open(os.path.join(STATE, "players.json"), "w"), indent=1)
    for k, v in pj.items():
        print(f"  {k} {v}")


def cmd_derive_players(n, label="plea-run9-p", *_):
    """Players p1..pn with keys derived from wallet A's key (keccak256(key ++ label+i)); only the
    addresses and the label are stored."""
    if os.path.exists(os.path.join(STATE, "players.env")):
        raise Fail("players.env exists (random players); use another STATE_DIR")
    pj = {}
    for i in range(1, int(n) + 1):
        k = _derived_key(label, i)
        pj[f"p{i}"] = _run(["wallet", "address", "--private-key", k], secret=k)
    with open(os.path.join(STATE, "players.derive"), "w") as f:
        f.write(label)
    json.dump(pj, open(os.path.join(STATE, "players.json"), "w"), indent=1)
    for k, v in pj.items():
        print(f"  {k} {v}")


def cmd_tree(each, a_amount="0", *names):
    """Distributor tree: `each` PLEA to each named player (default: all), `a_amount` PLEA to wallet A.
    Leaf = keccak256(abi.encodePacked(index, account, amount)); writes $STATE_DIR/tree.json."""
    from distributor_root import leaf, build, proof, verify
    rows = [(n, addr(n), wei(each)) for n in (names or list(players()))]
    if Decimal(a_amount) > 0:
        rows.append(("a", WALLET_A, wei(a_amount)))
    leaves = [leaf(i, a, amt) for i, (_, a, amt) in enumerate(rows)]
    layers = build(leaves)
    root = layers[-1][0]
    claims = []
    for i, (n, a, amt) in enumerate(rows):
        pf = proof(layers, i)
        assert verify(root, leaves[i], pf)
        claims.append({"name": n, "index": i, "account": a, "amount": str(amt), "proof": ["0x" + x.hex() for x in pf]})
    out = {"root": "0x" + root.hex(), "total": str(sum(r[2] for r in rows)), "claims": claims}
    json.dump(out, open(os.path.join(STATE, "tree.json"), "w"), indent=1)
    print(f"  root {out['root']} total {fmt(int(out['total']))} PLEA")
    for c in claims:
        print(f"  #{c['index']} {c['name']:4} {c['account']} {fmt(int(c['amount']))}")


def _tree():
    return json.load(open(os.path.join(STATE, "tree.json")))


def cmd_set_root(*_):
    """Wallet A sets the distributor's one-time root from tree.json."""
    t = _tree()
    cur = call(DISTRIBUTOR, "merkleRoot()(bytes32)")
    if int(cur, 16) != 0:
        raise Fail(f"root already set: {cur}")
    send("a", DISTRIBUTOR, "setMerkleRoot(bytes32)", t["root"])
    print(f"  root now {call(DISTRIBUTOR, 'merkleRoot()(bytes32)')}")


def cmd_claim(caller, *names):
    """`caller` claims from the distributor for each named leaf (the PLEA always goes to the leaf's account)."""
    t = _tree()
    if call(DISTRIBUTOR, "merkleRoot()(bytes32)").lower() != t["root"].lower():
        raise Fail("tree.json's root is not the distributor's")
    for n in names:
        c = next((c for c in t["claims"] if c["name"] == n), None)
        if c is None:
            raise Fail(f"{n} is not in the tree")
        if call(DISTRIBUTOR, "isClaimed(uint256)(bool)", c["index"]) == "true":
            print(f"  {n} already claimed")
            continue
        before = bal(PLEA, c["account"])
        send(caller, DISTRIBUTOR, "claim(uint256,address,uint256,bytes32[])", c["index"], c["account"], c["amount"],
             "[" + ",".join(c["proof"]) + "]")
        print(f"  {n} received {fmt(bal(PLEA, c['account']) - before)} PLEA")


def cmd_fund(eth, *names):
    """Wallet A sends `eth` ETH to each player."""
    for n in names:
        send("a", addr(n), value=f"{eth}ether")


def cmd_faucet(*names):
    if ONE_TOKEN:
        raise Fail("this run's IMD has no faucet: use `give`")
    for n in names:
        send(n, IMD, "faucet()")


def cmd_give(amount, *names):
    """Wallet A sends `amount` IMD (imdTEST on run 9) to each player."""
    for n in names:
        send("a", IMD, "transfer(address,uint256)", addr(n), wei(amount))


def cmd_claims(*names):
    """ERC-6909 IMD claims each wallet holds on the PoolManager (the hook's IOU when it cannot pay)."""
    for n in names or ["a"] + list(players()):
        c = num(call(POOL_MANAGER, "balanceOf(address,uint256)(uint256)", addr(n), int(IMD, 16)))
        print(f"  {n:4} {addr(n)} IMD claims {fmt(c)}")


def cmd_approve(*names):
    """Every approval a player needs: tIMD to PoolSwapTest, the gate (appeal share) and the Tribunal
    (stake); oracle token and PLEA to the gate (hand pleas and sales)."""
    for n in names:
        pairs = [(IMD, PST), (IMD, GATE), (IMD, TRIBUNAL), (PLEA, GATE)] + ([] if ONE_TOKEN else [(ORACLE, GATE)])
        for token, spender in pairs:
            if num(call(token, "allowance(address,address)(uint256)", addr(n), spender)) < 10**30:
                send(n, token, "approve(address,uint256)", spender, MAX)


def cmd_mint_oracle(name, amount="5"):
    send(name, ORACLE, "mint(address,uint256)", addr(name), wei(amount))


def cmd_seat(name, token_id):
    send(name, SEAT, "mint(uint256)", token_id)


def cmd_buy(name, imd_in):
    """Exact-input buy through PoolSwapTest with hookData abi.encode(buyer)."""
    a = addr(name)
    if num(call(IMD, "allowance(address,address)(uint256)", a, PST)) < wei(imd_in):
        send(name, IMD, "approve(address,uint256)", PST, MAX)
    pz = call(HOOK, "pleaIsZero()(bool)") == "true"
    zero_for_one = not pz  # a buy pays IMD; IMD is currency0 when PLEA is not
    limit = MIN_SQRT_PRICE_PLUS_1 if zero_for_one else MAX_SQRT_PRICE_MINUS_1
    hook_data = _run(["abi-encode", "f(address)", a])
    before = bal(PLEA, a)
    send(name, PST, "swap((address,address,uint24,int24,address),(bool,int256,uint160),(bool,bool),bytes)",
         pool_key(), f"({str(zero_for_one).lower()},-{wei(imd_in)},{limit})", "(false,false)", hook_data)
    print(f"  {name} bought {fmt(bal(PLEA, a) - before)} PLEA for {imd_in} tIMD")


def _text_hex(text):
    return "0x" + text.encode("utf-8").hex()


def cmd_letter(name, text):
    """A letter: the text as raw input data to the Letterbox."""
    send(name, LETTERBOX, data=_text_hex(text))
    _after_plea(name)


def cmd_typed(name, text):
    """The same letter typed into letter(text)."""
    send(name, LETTERBOX, "letter(string)", text)
    _after_plea(name)


def _amount(name, amount):
    if str(amount).endswith("%"):
        return bal(PLEA, name) * int(Decimal(amount[:-1]) * 100) // 10_000
    return wei(amount)


def cmd_plead(name, amount, text):
    """The site's auto-sell box: Letterbox.plead(amount, text)."""
    send(name, LETTERBOX, "plead(uint256,string)", _amount(name, amount), text)
    _after_plea(name)


def cmd_submit(name, amount, text):
    """A hand plea: gate.submitSell(amount, text); 0.5 oracle token from the seller."""
    if bal(ORACLE, name) < E18 // 2:
        if ONE_TOKEN:
            raise Fail("not enough IMD for the 0.5 oracle fee")
        cmd_mint_oracle(name, "1")
    send(name, GATE, "submitSell(uint256,string)", _amount(name, amount), text)
    _after_plea(name)


def cmd_appeal(name, orig, amount, text):
    """A hand appeal: gate.appeal(originalId, amount, text); 0.5 oracle token + 0.35 tIMD."""
    if bal(ORACLE, name) < E18 // 2:
        if ONE_TOKEN:
            raise Fail("not enough IMD for the 0.5 oracle fee and the 0.35 wall share")
        cmd_mint_oracle(name, "1")
    amt = num(plea_of(orig)["amount"]) if amount == "same" else _amount(name, amount)
    send(name, GATE, "appeal(uint256,uint256,string)", orig, amt, text)
    _after_plea(name)


def cmd_appeal_auto(name, orig, text):
    send(name, LETTERBOX, "appealAuto(uint256,string)", orig, text)
    _after_plea(name)


def _after_plea(name):
    pid = num(call(GATE, "lastPleaOf(address)(uint256)", addr(name)))
    p = plea_of(pid)
    print(f"  plea #{pid} {p['status']} amount {fmt(num(p['amount']))} fact {p['factScore']} need {p['need']}"
          f" flags {p['flags']} intake {p['intakeId']}")


def cmd_plea(pid):
    p = plea_of(pid)
    print(json.dumps(p, indent=1))
    print("  tribunal:", call(TRIBUNAL, "status(uint256)(string)", pid))


def cmd_status(name):
    print(call(LETTERBOX, "status(address)(string)", addr(name)))


def cmd_board(*_):
    print(call(LETTERBOX, "leaderboard()(string)"))


def cmd_sell(name, slippage_bps="100"):
    """gate.executeSell(minOut): previews the sale with eth_call, then sells for >= preview - slippage."""
    a = addr(name)
    preview = num(_run(["call", GATE, "executeSell(uint256)(uint256)", "0", "--from", a, "--rpc-url", RPC]))
    min_out = preview * (10_000 - int(slippage_bps)) // 10_000
    before = bal(IMD, a)
    send(name, GATE, "executeSell(uint256)", min_out)
    print(f"  {name} sold for {fmt(bal(IMD, a) - before)} tIMD (preview {fmt(preview)})")


def cmd_deliver(name, pid):
    send(name, LETTERBOX, "deliver(uint256)", pid)


def cmd_settle(name, pid):
    send(name, LETTERBOX, "settle(uint256)", pid)


def cmd_expire(name, pid):
    send(name, GATE, "expire(uint256)", pid)


def cmd_object(name, pid, text):
    """Tribunal.object(pleaId, text): 0.35 tIMD stake (approved), the oracle fee minted by the Tribunal."""
    if num(call(IMD, "allowance(address,address)(uint256)", addr(name), TRIBUNAL)) < 35 * E18 // 100:
        send(name, IMD, "approve(address,uint256)", TRIBUNAL, MAX)
    send(name, TRIBUNAL, "object(uint256,string)", pid, text)
    oid = num(call(TRIBUNAL, "nextId()(uint256)")) - 1
    print(f"  objection #{oid}: {objection_of(oid)}")


def cmd_objection(oid):
    print(json.dumps(objection_of(oid), indent=1))


def cmd_tsettle(name, oid):
    send(name, TRIBUNAL, "settle(uint256)", oid)


def cmd_texpire(name, oid):
    send(name, TRIBUNAL, "expire(uint256)", oid)


def cmd_record(name, pid):
    send(name, SEASONS, "record(uint256)", pid)


def cmd_close(name, *ids):
    send(name, SEASONS, "closeSeason(uint256[])", "[" + ",".join(ids) + "]")


def cmd_rebalance(name):
    send(name, HOOK, "rebalance()")


def cmd_seed(*_):
    send("a", LAUNCH, "seed()")
    print(f"  startedAt {num(call(GATE, 'startedAt()(uint64)'))}")


# ---------------------------------------------------------------- local fork only

def _fork_only():
    if not FORK:
        raise Fail("fork-only command (set FORK=1 and RPC to the anvil fork)")


def cmd_fork_init(*_):
    """Points the gate's and the Tribunal's oracleSigner (slot 2) at a test key, impersonates wallet A
    and the Intake writer, and gives both ETH. Never run against a real chain."""
    _fork_only()
    signer = _run(["wallet", "address", "--private-key", FORK_SIGNER_KEY])
    word = "0x" + "00" * 12 + signer[2:].lower()
    for c in (GATE, TRIBUNAL):
        rpc("anvil_setStorageAt", c, "0x2", word)
        assert call(c, "oracleSigner()(address)").lower() == signer.lower()
    for w in (WALLET_A, WRITER):
        rpc("anvil_impersonateAccount", w)
        rpc("anvil_setBalance", w, hex(100 * E18))
    print(f"  fork: oracleSigner of gate and Tribunal = test key {signer}; A and writer impersonated")


def _attestation(score):
    t = now()
    rid = "0x" + os.urandom(32).hex()
    job = "0x" + os.urandom(32).hex()
    answer = _run(["abi-encode", "f(uint256)", str(score)])
    return (f"({rid},1,{'0x' + '11' * 32},3,{answer},{score},1,2,{'0x' + '22' * 32},{job},30,17,20,{t},{t + 3600})")


def cmd_fork_answer(kind, ident, score):
    """The writer completes plea / objection `ident` with a signed `score` (status 0)."""
    _fork_only()
    consumer, rid = _consumer(kind, ident)
    att = _attestation(int(score))
    digest = call(consumer, f"attestationDigest({ATT_T})(bytes32)", att)
    sig = _run(["wallet", "sign", "--no-hash", "--private-key", FORK_SIGNER_KEY, digest])
    args = _run(["abi-encode", f"f(bytes32,{ATT_T},bytes)", rid, att, sig])
    keccak = _run(["keccak", "attestation"])
    send("writer", INTAKE, "complete(bytes32,uint8,bytes32,string,bytes)", rid, 0, keccak, "uri", args)


def cmd_fork_fail(kind, ident, status="2"):
    """The writer completes plea / objection `ident` without an answer (status 1 refused, 2 no answer)."""
    _fork_only()
    _, rid = _consumer(kind, ident)
    reason = "0x" + b"failed".hex().ljust(64, "0")
    args = _run(["abi-encode", "f(bytes32,uint8,bytes32,uint16,uint16,bytes)", rid, status, reason, "0", "0", "0x"])
    send("writer", INTAKE, "complete(bytes32,uint8,bytes32,string,bytes)", rid, status, "0x" + "00" * 32, "uri", args)


def _consumer(kind, ident):
    if kind == "plea":
        return GATE, plea_of(ident)["intakeId"]
    if kind == "objection":
        return TRIBUNAL, objection_of(ident)["intakeId"]
    raise Fail("kind is plea or objection")


def cmd_fork_warp(seconds):
    _fork_only()
    rpc("evm_increaseTime", hex(int(seconds)))
    rpc("evm_mine")
    print(f"  fork time now {now()}")


sys.dont_write_bytecode = True
sys.path.insert(0, HERE)  # distributor_root (keccak, Merkle tree) sits beside this file
COMMANDS = {k[4:].replace("_", "-"): v for k, v in globals().items() if k.startswith("cmd_")}


def main():
    if len(sys.argv) < 2 or sys.argv[1] == "help":
        print(__doc__)
        for k, v in COMMANDS.items():
            print(f"  {k:12} {(v.__doc__ or '').splitlines()[0] if v.__doc__ else ''}")
        return
    # Player keys live in STATE_DIR: never inside a git checkout, so they can never be committed.
    if not STATE or subprocess.run(["git", "-C", STATE, "rev-parse"], capture_output=True).returncode == 0:
        print("FAILED: set STATE_DIR to a scratch directory outside any git checkout")
        sys.exit(1)
    os.makedirs(STATE, mode=0o700, exist_ok=True)
    try:
        COMMANDS[sys.argv[1]](*sys.argv[2:])
    except Fail as e:
        print(f"FAILED: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
