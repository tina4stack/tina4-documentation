# Persistent Signals

A signal lives in memory. Refresh the page and it forgets. For values the user picked themselves -- theme, sidebar collapsed state, the last-used filter, draft text, a guest cart -- forgetting is rude. This chapter wraps a signal so its value survives a refresh, and draws the hard line around what you must never keep there.

A signal lives in memory. Refresh the page and it forgets. For values the user picked themselves -- theme, sidebar collapsed state, last-used filter, draft text, guest cart contents -- forgetting is rude.

`tina4js/storage` wraps a signal so its value reads from `localStorage` on creation and writes back on every change. Opt-in per signal. Zero dependencies. Tree-shakeable, so apps that do not import it ship zero bytes.

```typescript
import { signal } from 'tina4js';
import { persist, clearPersistedKeys } from 'tina4js/storage';

const theme = persist(signal('light'), { key: 'theme' });

theme.value = 'dark';   // saved to localStorage. Survives a refresh.
```

The wrapper returns the same signal you passed in, with two extras attached: `.clear()` removes the key from storage, `.dispose()` stops the write effect.

## The Dangers List, Up Front

`localStorage` is XSS-readable. Any script that runs on your origin reads every value. So `persist()` is the right tool for small, safe, user-chosen preferences. It is the wrong tool for the following, no exceptions:

- Auth tokens, JWTs, session IDs, API keys. Use `httpOnly` cookies.
- Passwords, including ones you think you encrypted client-side.
- Personal data: names, emails, phone numbers, addresses, IDs.
- Payment data: card numbers, CVV, expiry.
- Permission flags, roles, `isAdmin` booleans. The user can edit them in devtools.
- Encryption keys, OTP seeds, secrets.
- Server-of-record state: orders, balances, ledger entries. Fetch fresh from the database.

If you ignore this list, the framework warns you in the console. It looks at the key name (`token`, `password`, `secret`, `apikey`, `auth`, `credential`, `jwt`, `bearer`, `otp`, `private_key`, `session_id`) and at the value shape (a JWT, a long base64 string, an object with a credential-shape field). The warning is loud, once per key, and on purpose. See `STORAGE.md` in the tina4-js repo for the full table and the reasoning behind each row.

## Options

```typescript
persist(signal(0), {
  key: 'count',                        // required
  storage: 'local',                    // 'local' (default) or 'session'
  serializer: { read, write },         // default: JSON
  version: 1,                          // stored-shape version
  migrate: (oldValue, oldVersion) => 0,// run when versions disagree
  syncTabs: false,                     // 'storage' event sync, opt-in
  silenceCredentialWarning: false,     // for false positives like tokenColor
});
```

## Cross-tab Sync

Two tabs of the same app, both running `persist(signal([]), { key: 'cart', syncTabs: true })`. Add an item to the cart in tab A, and tab B sees it without a refresh. The `storage` event fires in tabs that did not write the value, so the framework subscribes there and updates the signal.

It is opt-in per signal. You decide which values cross tabs. No global broadcast.

## Wipe on Logout

When a user logs out, persisted state can leak to the next user on the same machine. The cure is `clearPersistedKeys()` on the logout path:

```typescript
import { clearPersistedKeys } from 'tina4js/storage';

function logout() {
  api.post('/auth/logout');
  clearPersistedKeys(['cart', 'lastFilter', 'draftReply']);
  window.location.reload();
}
```

The function removes only the keys you name. Other persisted state survives.

## Version Migration

A deploy changes the stored shape. Old browsers still hold the old shape. Without `migrate`, the framework discards the stored value and logs a warning. With `migrate`, you convert in place:

```typescript
// v1 stored: { name: 'Alice' }
// v2 wants:  { firstName: 'Alice', lastName: '' }

const user = persist(signal({ firstName: '', lastName: '' }), {
  key: 'user',
  version: 2,
  migrate: (old) => ({
    firstName: (old as { name?: string }).name ?? '',
    lastName: '',
  }),
});
```

## Safety Guarantees

- **SSR-safe.** No `window` or `localStorage`? `persist()` is a silent no-op. The signal still works in memory.
- **Quota-safe.** `QuotaExceededError` is logged and skipped; the signal still updates.
- **No "encrypted" option.** Encryption with a key sitting in the same bundle is theatre. The framework refuses to ship that knob.
- **Cross-tab sync is opt-in.** Off by default.

## Bundle Cost

`dist/storage.es.js` is 1.67 KB gzipped. Apps that never import from `tina4js/storage` ship zero bytes from this module. The 1.5 KB core promise is untouched.
