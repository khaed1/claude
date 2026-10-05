# PondPad legal texts (drafts)

- [`TERMS.md`](TERMS.md): Terms of Use
- [`PRIVACY.md`](PRIVACY.md): Privacy Policy

The site shows both at `/terms` and `/privacy` and asks every connected wallet to accept them before using the site (D-69). The acceptance is kept in a session cookie for that wallet and that version: it lasts until the browser session ends or cookies are cleared, then the wallet accepts again. Bump `LEGAL_VERSION` in `frontend/src/config.ts` whenever either text changes, so everyone accepts the new version.

**These are drafts written for the project, not legal advice.** Before mainnet a lawyer in the operator's jurisdiction must review them and fill the bracketed items: the operator's legal name and address, the contact email, the governing law and venue, and the final list of restricted jurisdictions (sanctioned countries are listed; whether to exclude others, such as the United States or the United Kingdom, is a legal and business decision). MiCA (EU) and similar regimes may require more (for example a white paper for $PONDPAD); counsel decides.
