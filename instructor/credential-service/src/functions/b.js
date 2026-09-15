// The whole service. It reads one string from Key Vault and returns it.
//
// It does not decode that string, parse it, or name any field inside it. The
// value is stored already base64-encoded, so this process only ever handles
// opaque bytes — which is deliberate (ADR-010). Nothing in this file says what
// the string is for.
const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

const VAULT_URI = process.env.KEYVAULT_URI;
const SECRET_NAME = process.env.SECRET_NAME || 'classroom-value';
const COHORT = process.env.COHORT || '';
const OPS_TOKEN = process.env.OPS_TOKEN || '';

// Thirty pipelines can start within a few seconds of each other. Serve them
// from memory rather than opening Key Vault thirty times.
const CACHE_MS = 60_000;

let client;
let cache;

function vault() {
  if (!client) client = new SecretClient(VAULT_URI, new DefaultAzureCredential());
  return client;
}

/** Both switches are read per request, so the portal is the control panel. */
function isOpen() {
  if (String(process.env.ENABLED).toLowerCase() !== 'true') return false;
  const until = process.env.OPEN_UNTIL;
  if (until) {
    const t = Date.parse(until);
    if (Number.isNaN(t) || Date.now() > t) return false;
  }
  return true;
}

async function currentValue() {
  if (cache && Date.now() - cache.at < CACHE_MS) return cache.value;
  const secret = await vault().getSecret(SECRET_NAME);
  const value = (secret.value || '').trim();
  if (!value) return '';
  cache = { at: Date.now(), value };
  return value;
}

// Every refusal is byte-identical: closed, expired, wrong cohort, secret
// missing, Key Vault unreachable. Saying which one confirms to whoever is
// probing that there is something here to find.
const REFUSED = { status: 404, body: '' };

app.http('b', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'v1/b/{cohort}',
  handler: async (request, context) => {
    // Instructor diagnostics. Behind a header rather than a public /health
    // endpoint, which would announce that a secret exists here.
    if (OPS_TOKEN && request.headers.get('x-ops') === OPS_TOKEN) {
      let present = false;
      let reachable = true;
      try {
        present = Boolean(await currentValue());
      } catch {
        reachable = false;
      }
      return {
        status: 200,
        jsonBody: {
          open: isOpen(),
          enabled: process.env.ENABLED ?? null,
          openUntil: process.env.OPEN_UNTIL || null,
          now: new Date().toISOString(),
          cohort: COHORT,
          requestedCohort: request.params.cohort,
          vaultReachable: reachable,
          valuePresent: present, // whether, never what
        },
      };
    }

    if (!isOpen()) return REFUSED;
    if (!COHORT || request.params.cohort !== COHORT) return REFUSED;

    let value;
    try {
      value = await currentValue();
    } catch (err) {
      // Logged for the instructor; the caller still gets an identical 404.
      context.error('vault read failed:', err.name);
      return REFUSED;
    }
    if (!value) return REFUSED;

    // A count, not a payload. The value is never logged.
    context.log('served');

    return {
      status: 200,
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'cache-control': 'no-store',
        'x-content-type-options': 'nosniff',
      },
      body: value,
    };
  },
});
