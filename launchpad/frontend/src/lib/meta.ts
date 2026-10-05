import { useQuery } from '@tanstack/react-query';

// Coin metadata: JSON {image, description, website, x, telegram} at an ipfs://, https:// or (testnet) data: URI.
// Everything here is untrusted creator input: links must be https or ipfs, text is rendered as text (React escapes it).
export type CoinMeta = { image?: string; description?: string; website?: string; x?: string; telegram?: string };

const IPFS_GATEWAY = 'https://ipfs.io/ipfs/';

/** https / ipfs only; anything else (javascript:, data:, http:) is dropped. */
export function safeUrl(u: unknown): string | undefined {
  if (typeof u !== 'string') return undefined;
  const s = u.trim();
  if (s.startsWith('ipfs://')) return IPFS_GATEWAY + s.slice(7).replace(/^ipfs\//, '');
  try {
    const url = new URL(s);
    return url.protocol === 'https:' ? url.toString() : undefined;
  } catch {
    return undefined;
  }
}

function clean(raw: unknown): CoinMeta {
  if (!raw || typeof raw !== 'object') return {};
  const r = raw as Record<string, unknown>;
  const text = (v: unknown, max: number) => (typeof v === 'string' ? v.slice(0, max) : undefined);
  return { image: safeUrl(r.image), description: text(r.description, 500), website: safeUrl(r.website), x: safeUrl(r.x), telegram: safeUrl(r.telegram) };
}

export async function loadMeta(uri: string): Promise<CoinMeta> {
  if (uri.startsWith('data:application/json')) {
    const [head, body] = uri.split(',', 2);
    const json = head.includes(';base64') ? new TextDecoder().decode(Uint8Array.from(atob(body), (c) => c.charCodeAt(0))) : decodeURIComponent(body);
    return clean(JSON.parse(json));
  }
  const url = safeUrl(uri);
  if (!url) return {};
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 6000);
  try {
    const res = await fetch(url, { signal: ctrl.signal });
    if (!res.ok || Number(res.headers.get('content-length') ?? 0) > 64_000) return {};
    return clean(await res.json());
  } catch {
    return {};
  } finally {
    clearTimeout(t);
  }
}

export function useMeta(uri?: string) {
  return useQuery({ queryKey: ['meta', uri], enabled: !!uri, staleTime: Infinity, retry: false, queryFn: () => loadMeta(uri!) });
}

/** Testnet stand-in for the upload service: metadata inlined as a data: URI (mainnet pins to IPFS, D-68). */
export function inlineMeta(m: CoinMeta): string {
  const json = JSON.stringify(Object.fromEntries(Object.entries(m).filter(([, v]) => v)));
  return 'data:application/json;base64,' + btoa(String.fromCharCode(...new TextEncoder().encode(json)));
}
