#!/usr/bin/env python3
"""PoA (minepoa.com) worker: one cycle per run, started hourly at a random minute by a systemd timer.

Each cycle: join once if needed, attest (countersign) new transactions in code, and answer the
current epoch's challenge once per epoch. Only the answer text comes from Claude, run with no
tools. No referrals, forum posts, votes, swaps or external wallets. When the node is busy the
cycle stops and the next hourly run tries again.

Hosted fallback (only if config "hosted_fallback" is true and the self-custody wallet never
joined): register once through the site's hosted API, then each cycle fetch the challenge,
answer it, request "mine" and read the balance. The node holds that account's key; the pk_ key
is stored in ~/poa/hosted.json (0600) and never written to the log. Limits live in /etc/poa-worker/config.json
(root-owned, so this worker cannot raise them); state and records live in ~/poa-agent.
"""
import datetime as dt, fcntl, json, os, re, shutil, subprocess, sys, time, urllib.error, urllib.parse, urllib.request, uuid

USER_HOME = os.path.expanduser('~')
AGENT = f'{USER_HOME}/poa-agent'
WALLET = f'{USER_HOME}/poa'
CACHE = f'{USER_HOME}/poa-cache'
CONFIG = '/etc/poa-worker/config.json'
CLIENT = '/opt/poa/poa.mjs'
NODE = '/opt/node24/bin/node'
NODE_URL = 'https://minepoa.com/'
PATH = '/opt/node24/bin:/opt/reset-claude/bin:/usr/bin:/bin'
STATE, ACTIVITY = f'{AGENT}/state.json', f'{AGENT}/logs/activity.jsonl'
HOSTED = f'{WALLET}/hosted.json'
TASK = ('in 120-600 characters, write an ORIGINAL short text explaining one concrete way an agent economy can resist '
        'sybil attacks. Propose a concrete MECHANISM: how it works and what it costs an attacker, not a story.')


class Busy(Exception):
    pass


class RateLimited(Busy):
    """HTTP 429: the node refused before acting, so nothing was created; retry after `retry_after` seconds."""
    def __init__(self, msg, retry_after):
        super().__init__(msg)
        self.retry_after = retry_after


def now():
    return dt.datetime.now(dt.timezone.utc)


def redact(text):
    return re.sub(r'pk_[A-Za-z0-9_-]+', 'pk_***', str(text))


def log(event, **kw):
    with open(ACTIVITY, 'a') as f:
        f.write(redact(json.dumps({'ts': now().isoformat(timespec='seconds'), 'event': event, **kw})) + '\n')


def load_state():
    try:
        return json.load(open(STATE))
    except FileNotFoundError:
        return {'spent_usd': 0.0, 'address': None, 'joined': False, 'answered': {}}


def save_state(s):
    tmp = STATE + '.tmp'
    json.dump(s, open(tmp, 'w'), indent=1)
    os.replace(tmp, STATE)


def base_env():
    """A minimal environment: our PATH and HOME, plus any proxy/CA settings the machine uses."""
    keep = {k: v for k, v in os.environ.items()
            if re.fullmatch(r'(https?_proxy|HTTPS?_PROXY|no_proxy|NO_PROXY|NODE_EXTRA_CA_CERTS|SSL_CERT_FILE)', k)}
    return {**keep, 'PATH': PATH, 'HOME': USER_HOME}


def client(*args, timeout=600):
    """Run the pinned PoA client; raise Busy when the node is overloaded, RuntimeError on other failures."""
    p = subprocess.run([NODE, CLIENT, *args, '--node', NODE_URL, '--ledger', CACHE], capture_output=True, text=True,
                       timeout=timeout, cwd=AGENT, env=base_env())
    out, err = p.stdout.strip(), p.stderr.strip()
    if p.returncode != 0:
        if re.search(r'busy|503|502|504|ETIMEDOUT|ECONNRESET|fetch failed', err + out, re.I):
            raise Busy(err[-300:] or out[-300:])
        raise RuntimeError(f'{args[0]} exited {p.returncode}: {(err or out)[-500:]}')
    return out


def ask_claude(cfg, ch, budget_left):
    """Ask Claude (no tools) for the challenge answer text. Returns (text, cost)."""
    words = ch['words']
    prompt = (f"Write the answer to this task and output ONLY the answer text, nothing else.\n\n"
              f"Task: {ch['task']}\n\n"
              f"Hard requirements: 120 to 600 characters; plain prose on one paragraph; it must contain each of "
              f"these words exactly as written: {', '.join(words)}; original, specific and coherent.")
    claude = shutil.which('claude', path=PATH)
    if not claude:
        raise RuntimeError('claude not found in /opt/reset-claude/bin')
    cap = min(cfg['per_run_max_usd'], budget_left)
    p = subprocess.run([claude, '-p', prompt, '--model', cfg['model'], '--tools', '', '--strict-mcp-config',
                        '--mcp-config', '{"mcpServers":{}}', '--no-session-persistence', '--output-format', 'json',
                        '--max-budget-usd', f'{cap:.4f}'],
                       capture_output=True, text=True, timeout=300, cwd=f'{AGENT}/work',
                       env={**base_env(), 'DISABLE_AUTOUPDATER': '1'})
    try:
        res = json.loads(p.stdout)
    except ValueError:
        return None, cap  # count a failed run at its cap so the budget stays conservative
    text = ' '.join(str(res.get('result', '')).split()).strip().strip('"')
    return (None if res.get('is_error') else text), float(res.get('total_cost_usd') or cap)


def hosted_get(path, timeout=150, **params):
    """GET a hosted API path; returns parsed JSON. Busy on 5xx/timeouts, RuntimeError on other errors."""
    url = NODE_URL + path + '?' + urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'poa-worker/1'}), timeout=timeout) as r:
            body = r.read(1_000_000).decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        detail = redact(e.read(2000).decode('utf-8', 'replace'))
        if e.code == 429:
            try:
                wait = int(json.loads(detail).get('retry_after_seconds') or 60)
            except (ValueError, AttributeError):
                wait = 60
            raise RateLimited(f'{path} HTTP 429: {detail[:200]}', wait)
        if e.code >= 500:
            raise Busy(f'{path} HTTP {e.code}: {detail[:200]}')
        raise RuntimeError(f'{path} HTTP {e.code}: {detail[:300]}')
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise Busy(f'{path}: {redact(e)}'[:300])
    try:
        return json.loads(body)
    except ValueError:
        raise RuntimeError(f'{path}: not JSON: {redact(body[:200])}')


def find(obj, keys):
    """First value for any of keys, searching nested dicts (response field names vary)."""
    if isinstance(obj, dict):
        for k in keys:
            if k in obj:
                return obj[k]
        for v in obj.values():
            r = find(v, keys)
            if r is not None:
                return r
    return None


def hosted_cycle(cfg, state):
    acct = json.load(open(HOSTED))
    key = acct['api_key']
    ch = hosted_get('api/hosted/challenge', key=key)
    words = find(ch, ['words', 'required_words', 'challenge_words'])
    epoch = find(ch, ['epoch', 'current_epoch'])
    if not (isinstance(words, list) and len(words) == 3 and all(isinstance(w, str) for w in words) and epoch is not None):
        log('challenge_unreadable', response=json.dumps(ch)[:600])
    elif state['answered'].get(f'h{epoch}', 0) >= 2:
        log('challenge_skip', epoch=epoch, reason='already answered or tried twice this epoch')
    else:
        start, end = dt.datetime.fromisoformat(cfg['start']), dt.datetime.fromisoformat(cfg['end'])
        allowed = cfg['budget_usd'] * min(1.0, (now() - start) / (end - start) + 1 / 28)
        if state['spent_usd'] + cfg['per_run_max_usd'] > allowed:
            log('challenge_skip', epoch=epoch, reason='budget pacing', spent_usd=round(state['spent_usd'], 4))
        else:
            run = uuid.uuid4().hex[:12]
            text, cost = ask_claude(cfg, {'words': words, 'task': f'Epoch {epoch} challenge: {TASK}'},
                                    cfg['budget_usd'] - state['spent_usd'])
            state['spent_usd'] += cost
            state['answered'][f'h{epoch}'] = state['answered'].get(f'h{epoch}', 0) + 1
            save_state(state)
            if not valid_answer(text, words):
                log('answer_rejected_locally', run=run, epoch=epoch, words=words, cost_usd=round(cost, 4), text=(text or '')[:600])
            else:
                res = hosted_get('api/hosted/answer', key=key, answer=text)
                state['answered'][f'h{epoch}'] = 2
                log('answer_submitted', mode='hosted', run=run, epoch=epoch, words=words, cost_usd=round(cost, 4),
                    spent_usd=round(state['spent_usd'], 4), response=json.dumps(res)[:400], text=text)
    mine = hosted_get('api/hosted/mine', key=key)
    log('mined', mode='hosted', response=json.dumps(mine)[:300])
    me = hosted_get('api/hosted/me', key=key)
    log('balance', mode='hosted', address=acct.get('poa_address'),
        **{k: find(me, [k]) for k in ('balance', 'spendable', 'locked') if find(me, [k]) is not None})


def hosted_register(cfg, state):
    """Register once (at most one attempt per day, so a lost reply cannot create a string of accounts)."""
    if time.time() - state.get('hosted_register_try', 0) < 86400:
        log('hosted_wait', note='registration already attempted in the last 24 h; waiting for it or the next day')
        return False
    state['hosted_register_try'] = time.time()   # an unclear outcome (timeout) may still have created an account
    save_state(state)
    for attempt in range(5):
        try:
            res = hosted_get('api/hosted/register', timeout=180, label=cfg.get('hosted_label', 'vps-claude-miner'))
            break
        except RateLimited as e:                  # refused before acting: no account exists, so waiting is safe
            log('hosted_register_paced', attempt=attempt + 1, retry_after_s=e.retry_after)
            time.sleep(min(max(e.retry_after, 10), 120))
    else:
        state['hosted_register_try'] = 0          # only refusals happened: retry at the next cycle, not in 24 h
        save_state(state)
        raise Busy('registration paced globally; next hourly cycle retries')
    key, addr = find(res, ['api_key']), find(res, ['poa_address', 'address'])
    if not (isinstance(key, str) and key.startswith('pk_')):
        log('hosted_register_failed', response=json.dumps(res)[:400])
        return False
    fd = os.open(HOSTED, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as f:
        json.dump({'api_key': key, 'poa_address': addr, 'registered': now().isoformat(timespec='seconds')}, f)
    log('hosted_registered', poa_address=addr, note='key saved to ~/poa/hosted.json; show it with: poactl hosted-key')
    return True


def valid_answer(text, words):
    return bool(text) and 120 <= len(text) <= 600 and all(re.search(rf'\b{re.escape(w)}\b', text, re.I) for w in words)


def cycle(cfg, state):
    if not state['joined']:
        out = client('join', '--wallet', WALLET)
        j = json.loads(out.splitlines()[-1])
        state.update(joined=True, address=j['address'])
        log('joined', address=j['address'], join_txid=j['join_txid'])
        save_state(state)

    out = client('attest', '--wallet', WALLET)
    m = re.search(r'attested (\d+)', out)
    log('attested', count=int(m.group(1)) if m else None)

    ch = json.loads(client('challenge-show', '--wallet', WALLET))
    epoch = str(ch['epoch'])
    if state['answered'].get(epoch, 0) >= 2:
        log('challenge_skip', epoch=ch['epoch'], reason='already answered or tried twice this epoch')
    else:
        start, end = dt.datetime.fromisoformat(cfg['start']), dt.datetime.fromisoformat(cfg['end'])
        allowed = cfg['budget_usd'] * min(1.0, (now() - start) / (end - start) + 1 / 28)
        if state['spent_usd'] + cfg['per_run_max_usd'] > allowed:
            log('challenge_skip', epoch=ch['epoch'], reason='budget pacing', spent_usd=round(state['spent_usd'], 4))
        else:
            run = uuid.uuid4().hex[:12]
            text, cost = ask_claude(cfg, ch, cfg['budget_usd'] - state['spent_usd'])
            state['spent_usd'] += cost
            state['answered'][epoch] = state['answered'].get(epoch, 0) + 1
            save_state(state)
            if not valid_answer(text, ch['words']):
                log('answer_rejected_locally', run=run, epoch=ch['epoch'], words=ch['words'], cost_usd=round(cost, 4),
                    length=len(text or ''), text=(text or '')[:600])
            else:
                res = json.loads(client('challenge-answer', '--wallet', WALLET, '--answer', text).splitlines()[-1])
                state['answered'][epoch] = 2  # submitted: no more attempts this epoch
                log('answer_submitted', run=run, epoch=ch['epoch'], words=ch['words'], cost_usd=round(cost, 4),
                    spent_usd=round(state['spent_usd'], 4), txid=res.get('challenge_txid'), text=text)
        for k in [k for k in state['answered'] if int(k) < int(epoch) - 8]:
            del state['answered'][k]

    if state['address']:
        bal = client('balance', '--addr', state['address'])
        log('balance', line=bal.splitlines()[-1] if bal else None)


def main():
    os.makedirs(f'{AGENT}/logs', exist_ok=True)
    os.makedirs(f'{AGENT}/work', exist_ok=True)
    lock = open(f'{AGENT}/worker.lock', 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print('another cycle is running', file=sys.stderr)
        return 0
    cfg = json.load(open(CONFIG))
    state = load_state()
    if os.path.exists(f'{AGENT}/PAUSE'):
        log('paused')
        return 0
    if now() >= dt.datetime.fromisoformat(cfg['end']):
        log('stopped', reason='run duration ended')
        return 0
    if state['spent_usd'] >= cfg['budget_usd']:
        log('stopped', reason='model budget used up')
        return 0
    try:
        if os.path.exists(HOSTED):
            hosted_cycle(cfg, state)
        else:
            try:
                cycle(cfg, state)
            except Busy:
                if not (cfg.get('hosted_fallback') and not state['joined']):
                    raise
                log('self_custody_busy', note='switching to the hosted fallback')
                if hosted_register(cfg, state):
                    hosted_cycle(cfg, state)
    except Busy as e:
        log('node_busy', detail=str(e)[:300], note='next hourly cycle retries')
    except Exception as e:
        log('error', error=str(e)[:500])
        save_state(state)
        return 1
    save_state(state)
    return 0


if __name__ == '__main__':
    sys.exit(main())
