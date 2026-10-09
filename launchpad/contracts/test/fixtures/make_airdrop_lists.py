#!/usr/bin/env python3
"""Writes the airdrop claims fixtures for DeployCreate2.t.sol (audit P5-3), with airdrop/snapshot.py's own build_tree.

  python3 test/fixtures/make_airdrop_lists.py      (from launchpad/contracts)

Each file has the shape `snapshot.py build` writes ({root, total, claims}) and 100 keys whose amounts add up to the
total and rebuild the root, but only 99 wallets that can initiate:
  airdrop-repeated-wallet.json  one wallet listed twice, in lowercase and in uppercase
  airdrop-zero-wallet.json      99 wallets and address 0
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "airdrop"))
from snapshot import build_tree, keccak  # noqa: E402

AMOUNT = 400_000 * 10**18


def wallet(i):
    return "0x" + keccak(b"P5-3 wallet %d" % i)[12:].hex()


def write(name, accounts):
    entries = [(a, AMOUNT) for a in accounts]
    root, _dump, claims = build_tree(entries)
    assert len(claims) == 100, name
    with open(os.path.join(HERE, name), "w") as f:
        json.dump({"root": root, "total": str(AMOUNT * len(entries)), "claims": claims}, f)


wallets = [wallet(i) for i in range(99)]
write("airdrop-repeated-wallet.json", wallets + ["0x" + wallets[0][2:].upper()])
write("airdrop-zero-wallet.json", wallets + ["0x" + "00" * 20])
