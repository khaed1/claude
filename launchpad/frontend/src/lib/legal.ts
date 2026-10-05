import { LEGAL_VERSION } from '../config';

// Acceptance of the Terms and Privacy Policy, per wallet and version, in a session cookie (no Expires/Max-Age):
// it lasts until the browser session ends or cookies are cleared, then the wallet accepts again (D-69).
const name = (address: string) => `pp_legal_${address.toLowerCase()}`;

export function hasAccepted(address?: string): boolean {
  if (!address) return false;
  try {
    return document.cookie.split('; ').some((c) => c === `${name(address)}=${LEGAL_VERSION}`);
  } catch {
    return false;
  }
}

export function accept(address: string) {
  document.cookie = `${name(address)}=${LEGAL_VERSION}; Path=/; SameSite=Lax${location.protocol === 'https:' ? '; Secure' : ''}`;
}
