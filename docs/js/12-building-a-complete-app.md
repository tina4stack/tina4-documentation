# Chapter 12: Building a Complete App

## The Admin Dashboard

Picture the screen. A dark navbar across the top. Four stat cards showing live numbers -- total users, active sessions, revenue, orders -- updating without a page refresh. A notification bell with a red badge. A data table with search, pagination, and inline editing. A login page that guards everything behind it.

This chapter builds that dashboard from scratch. It uses every tina4-js module: signals, html, components, routing, API, WebSocket, and PWA. By the end, you will have a complete, deployable application -- and you will have seen how all the pieces from previous chapters fit together in production.

---

## 1. Project Setup

```bash
npx tina4 create admin-dashboard --css
cd admin-dashboard
npm install
```

We will build this structure:

```
src/
  main.ts              # Entry point
  store.ts             # Global state
  routes/
    index.ts           # Route definitions
  pages/
    login.ts           # Login page
    dashboard.ts       # Dashboard with live stats
    users.ts           # CRUD user management
  components/
    app-layout.ts      # Layout wrapper with nav
    data-table.ts      # Reusable data table
    stat-card.ts       # Statistics card
    notification-bell.ts  # WebSocket notification bell
```

---

## 2. Global Store

Start with the shared state. Authentication drives the entire application -- which pages render, which API calls include tokens, what the navbar displays. The store is the foundation.

```typescript
// src/store.ts
import { signal, computed } from 'tina4js';

// Auth
export const token = signal<string | null>(
  localStorage.getItem('tina4_token'),
  'auth-token'
);
export const user = signal<{ id: number; name: string; role: string } | null>(
  null,
  'current-user'
);
export const isLoggedIn = computed(() => token.value !== null);
export const isAdmin = computed(() => user.value?.role === 'admin');

export function setAuth(newToken: string, userData: { id: number; name: string; role: string }) {
  localStorage.setItem('tina4_token', newToken);
  token.value = newToken;
  user.value = userData;
}

export function clearAuth() {
  localStorage.removeItem('tina4_token');
  token.value = null;
  user.value = null;
}

// Notifications
export const notifications = signal<{ id: number; text: string; time: string }[]>(
  [],
  'notifications'
);
export const unreadCount = computed(() => notifications.value.length);
```

Every signal has a debug label. Every piece of derived state is a computed signal. The store exports functions for mutations, not raw signal writes. This discipline pays for itself the moment you open the debug overlay and see named, traceable state.

---

## 3. App Entry

```typescript
// src/main.ts
import { api, router } from 'tina4js';
import { pwa } from 'tina4js';
import { token, clearAuth } from './store';
import { navigate } from 'tina4js';
import './routes/index';
import './components/app-layout';
import './components/data-table';
import './components/stat-card';
import './components/notification-bell';

// Debug overlay in dev only
if (import.meta.env.DEV) {
  import('tina4js/debug');
}

// API configuration
api.configure({
  baseUrl: '/api',
  auth: true,
});

// Global 401 handler
api.intercept('response', (response) => {
  if (response.status === 401) {
    clearAuth();
    navigate('/login', { replace: true });
  }
});

// PWA
pwa.register({
  name: 'Admin Dashboard',
  shortName: 'Admin',
  themeColor: '#1e293b',
  cacheStrategy: 'network-first',
  precache: ['/'],
});

// Start router
router.start({ target: '#root', mode: 'hash' });
```

The entry point is the wiring diagram. API configured. Interceptor registered. PWA enabled. Debug overlay loaded in development. Router started. Every cross-cutting concern lives here, declared once, applied everywhere.

---

## 4. Routes

```typescript
// src/routes/index.ts
import { route } from 'tina4js';
import { isLoggedIn } from '../store';
import { loginPage } from '../pages/login';
import { dashboardPage } from '../pages/dashboard';
import { usersPage } from '../pages/users';
import { html } from 'tina4js';

// Public
route('/login', loginPage);

// Protected
route('/', {
  guard: () => isLoggedIn.value || '/login',
  handler: dashboardPage,
});

route('/users', {
  guard: () => isLoggedIn.value || '/login',
  handler: usersPage,
});

// 404
route('*', () => html`
  <app-layout>
    <h1>404 - Page Not Found</h1>
    <a href="/">Go to Dashboard</a>
  </app-layout>
`);
```

Four routes. One is public. Two are guarded. One catches everything else. The guard is the same computed signal for both protected routes -- `isLoggedIn` returns true or redirects to `/login`. The entire routing table fits on one screen.

---

## 5. Layout Component

```typescript
// src/components/app-layout.ts
import { Tina4Element, html } from 'tina4js';
import { user, isLoggedIn, clearAuth, unreadCount } from '../store';
import { navigate } from 'tina4js';

class AppLayout extends Tina4Element {
  static shadow = false;

  render() {
    return html`
      <div style="min-height: 100vh; display: flex; flex-direction: column;">
        ${() => isLoggedIn.value
          ? html`
              <nav class="navbar" style="background: #1e293b; color: white; padding: 0.75rem 1.5rem;">
                <a class="navbar-brand" href="/" style="color: white; text-decoration: none; font-weight: bold;">
                  Admin Dashboard
                </a>
                <div style="display: flex; align-items: center; gap: 1rem;">
                  <a href="/" style="color: #94a3b8; text-decoration: none;">Dashboard</a>
                  <a href="/users" style="color: #94a3b8; text-decoration: none;">Users</a>
                  <notification-bell></notification-bell>
                  <span style="color: #94a3b8;">${() => user.value?.name ?? ''}</span>
                  <button
                    class="btn btn-sm"
                    style="background: #475569; color: white; border: none;"
                    @click=${() => { clearAuth(); navigate('/login'); }}
                  >Logout</button>
                </div>
              </nav>
            `
          : null
        }
        <main style="flex: 1; padding: 1.5rem; max-width: 1200px; width: 100%; margin: 0 auto;">
          <slot></slot>
        </main>
      </div>
    `;
  }
}

customElements.define('app-layout', AppLayout);
```

The layout wraps every page. It renders the navbar when the user is logged in and hides it when they are not. The notification bell sits in the navbar. The user's name appears next to the logout button. The `<slot>` element passes through whatever the route handler renders.

One component. Every page gets a consistent shell.

---

## 6. Login Page

```typescript
// src/pages/login.ts
import { signal, html, api, navigate, batch } from 'tina4js';
import { setAuth } from '../store';

export function loginPage() {
  const email = signal('', 'login-email');
  const password = signal('', 'login-password');
  const error = signal<string | null>(null, 'login-error');
  const loading = signal(false, 'login-loading');

  const handleLogin = async (e: Event) => {
    e.preventDefault();
    loading.value = true;
    error.value = null;

    try {
      const result = await api.post<{
        token: string;
        user: { id: number; name: string; role: string };
      }>('/auth/login', {
        email: email.value,
        password: password.value,
      });

      setAuth(result.token, result.user);
      navigate('/');
    } catch (err: any) {
      error.value = err.data?.message ?? 'Login failed. Please try again.';
    } finally {
      loading.value = false;
    }
  };

  return html`
    <div style="max-width: 400px; margin: 4rem auto; padding: 2rem;">
      <h1 style="text-align: center; margin-bottom: 2rem;">Admin Login</h1>

      ${() => error.value
        ? html`<div class="alert alert-danger">${error}</div>`
        : null
      }

      <form @submit=${handleLogin}>
        <div class="form-group">
          <label>Email</label>
          <input
            type="email"
            class="form-control"
            placeholder="admin@example.com"
            .value=${email}
            @input=${(e: Event) => { email.value = (e.target as HTMLInputElement).value; }}
            ?disabled=${loading}
            required
          />
        </div>

        <div class="form-group">
          <label>Password</label>
          <input
            type="password"
            class="form-control"
            placeholder="Enter password"
            .value=${password}
            @input=${(e: Event) => { password.value = (e.target as HTMLInputElement).value; }}
            ?disabled=${loading}
            required
          />
        </div>

        <button
          type="submit"
          class="btn btn-primary"
          style="width: 100%"
          ?disabled=${loading}
        >
          ${() => loading.value ? 'Logging in...' : 'Login'}
        </button>
      </form>
    </div>
  `;
}
```

Four signals drive this page. `email` and `password` hold the form state. `error` displays feedback. `loading` disables the form during the API call. The login handler calls the store's `setAuth` on success and navigates to the dashboard. On failure, the error signal updates and the alert appears.

No form library. No validation library. Signals and HTML.

---

## 7. Stat Card Component

```typescript
// src/components/stat-card.ts
import { Tina4Element, html } from 'tina4js';

class StatCard extends Tina4Element {
  static props = { label: String, value: String, color: String };

  static styles = `
    :host { display: block; }
    .stat {
      padding: 1.5rem;
      border-radius: 8px;
      background: white;
      border: 1px solid #e2e8f0;
    }
    .label { font-size: 0.875rem; color: #64748b; margin-bottom: 0.25rem; }
    .value { font-size: 2rem; font-weight: 700; }
  `;

  render() {
    return html`
      <div class="stat">
        <div class="label">${this.prop('label')}</div>
        <div class="value" style=${() => `color: ${this.prop<string>('color').value || '#1e293b'}`}>
          ${this.prop('value')}
        </div>
      </div>
    `;
  }
}

customElements.define('stat-card', StatCard);
```

A small, focused component. Three props. Shadow DOM for style isolation. The value updates reactively when the parent passes a new attribute. Drop four of these in a grid and you have a statistics dashboard.

---

## 8. Notification Bell Component

```typescript
// src/components/notification-bell.ts
import { Tina4Element, html, signal } from 'tina4js';
import { notifications, unreadCount } from '../store';

class NotificationBell extends Tina4Element {
  static styles = `
    :host { display: inline-block; position: relative; cursor: pointer; }
    .bell { font-size: 1.25rem; }
    .badge {
      position: absolute; top: -6px; right: -8px;
      background: #ef4444; color: white;
      font-size: 0.625rem; font-weight: 700;
      width: 18px; height: 18px;
      border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
    }
    .dropdown {
      position: absolute; top: 100%; right: 0; margin-top: 0.5rem;
      background: white; border: 1px solid #e2e8f0; border-radius: 8px;
      width: 300px; max-height: 400px; overflow-y: auto;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1); z-index: 100;
    }
    .item { padding: 0.75rem 1rem; border-bottom: 1px solid #f1f5f9; }
    .item:last-child { border-bottom: none; }
    .time { font-size: 0.75rem; color: #94a3b8; }
    .empty { padding: 1rem; text-align: center; color: #94a3b8; }
  `;

  render() {
    const open = signal(false);

    return html`
      <div @click=${() => { open.value = !open.value; }}>
        <span class="bell">&#128276;</span>
        ${() => unreadCount.value > 0
          ? html`<span class="badge">${unreadCount}</span>`
          : null
        }
      </div>

      ${() => open.value
        ? html`
            <div class="dropdown">
              ${() => notifications.value.length === 0
                ? html`<div class="empty">No notifications</div>`
                : null
              }
              ${() => notifications.value.map(n => html`
                <div class="item">
                  <div>${n.text}</div>
                  <div class="time">${n.time}</div>
                </div>
              `)}
              ${() => notifications.value.length > 0
                ? html`
                    <div style="padding: 0.5rem; text-align: center;">
                      <button
                        style="border: none; background: none; color: #3b82f6; cursor: pointer;"
                        @click=${() => { notifications.value = []; }}
                      >Clear all</button>
                    </div>
                  `
                : null
              }
            </div>
          `
        : null
      }
    `;
  }
}

customElements.define('notification-bell', NotificationBell);
```

The bell reads from the global notification store. The badge appears when `unreadCount` is greater than zero. The dropdown opens on click. Each notification shows its text and timestamp. The "Clear all" button empties the array. All of this -- the badge count, the dropdown toggle, the notification list, the clear action -- runs on signals. No imperative state management. No event bus.

---

## 9. Dashboard Page with Live Stats

```typescript
// src/pages/dashboard.ts
import { signal, computed, html, api, ws, batch } from 'tina4js';
import { user, notifications } from '../store';

export function dashboardPage() {
  // Stats from API
  const stats = signal({
    totalUsers: 0,
    activeUsers: 0,
    revenue: 0,
    orders: 0,
  }, 'dashboard-stats');

  const loading = signal(true, 'dashboard-loading');

  // Load initial stats
  async function loadStats() {
    loading.value = true;
    try {
      stats.value = await api.get('/dashboard/stats');
    } finally {
      loading.value = false;
    }
  }

  loadStats();

  // Live updates via WebSocket
  const socket = ws.connect(`${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/ws/dashboard`);

  // Pipe live stat updates
  socket.pipe(stats, (msg, current) => {
    const m = msg as { type: string; data: any };
    if (m.type === 'stats_update') {
      return { ...current, ...m.data };
    }
    return current;
  });

  // Pipe notifications
  socket.pipe(notifications, (msg, current) => {
    const m = msg as { type: string; text: string; time: string };
    if (m.type === 'notification') {
      return [{ id: Date.now(), text: m.text, time: m.time }, ...current].slice(0, 50);
    }
    return current;
  });

  // Recent activity
  const activity = signal<{ action: string; user: string; time: string }[]>([], 'recent-activity');

  socket.pipe(activity, (msg, current) => {
    const m = msg as { type: string; action: string; user: string; time: string };
    if (m.type === 'activity') {
      return [{ action: m.action, user: m.user, time: m.time }, ...current].slice(0, 20);
    }
    return current;
  });

  return html`
    <app-layout>
      <h1>Dashboard</h1>
      <p style="color: #64748b; margin-bottom: 1.5rem;">
        Welcome back, ${() => user.value?.name ?? 'User'}
      </p>

      ${() => loading.value
        ? html`<p>Loading stats...</p>`
        : html`
            <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 2rem;">
              <stat-card
                label="Total Users"
                value=${() => String(stats.value.totalUsers)}
                color="#3b82f6"
              ></stat-card>
              <stat-card
                label="Active Now"
                value=${() => String(stats.value.activeUsers)}
                color="#10b981"
              ></stat-card>
              <stat-card
                label="Revenue"
                value=${() => `$${stats.value.revenue.toLocaleString()}`}
                color="#8b5cf6"
              ></stat-card>
              <stat-card
                label="Orders Today"
                value=${() => String(stats.value.orders)}
                color="#f59e0b"
              ></stat-card>
            </div>
          `
      }

      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem;">
        <div>
          <h2>Live Connection</h2>
          <p style="margin-bottom: 1rem;">
            Status:
            <span style=${() =>
              socket.status.value === 'open'
                ? 'color: #10b981'
                : 'color: #ef4444'
            }>${socket.status}</span>
          </p>
        </div>

        <div>
          <h2>Recent Activity</h2>
          <div style="max-height: 300px; overflow-y: auto;">
            ${() => activity.value.length === 0
              ? html`<p style="color: #94a3b8;">No recent activity</p>`
              : null
            }
            ${() => activity.value.map(a => html`
              <div style="padding: 0.5rem 0; border-bottom: 1px solid #f1f5f9;">
                <strong>${a.user}</strong> ${a.action}
                <span style="color: #94a3b8; font-size: 0.75rem; margin-left: 0.5rem;">${a.time}</span>
              </div>
            `)}
          </div>
        </div>
      </div>
    </app-layout>
  `;
}
```

The page loads stats from the API, then opens a WebSocket for live updates. Three `pipe()` calls route incoming messages to three different signals: stats, notifications, and activity. The stat cards update in real time. Notifications push into the bell component. Activity entries stream into the feed.

The API provides the initial snapshot. The WebSocket provides the deltas. The signals merge both into a single reactive view.

---

## 10. CRUD Users Page

```typescript
// src/pages/users.ts
import { signal, computed, html, api, batch } from 'tina4js';

interface User {
  id: number;
  name: string;
  email: string;
  role: string;
  active: boolean;
}

export function usersPage() {
  const users = signal<User[]>([], 'users-list');
  const loading = signal(true, 'users-loading');
  const search = signal('', 'users-search');
  const page = signal(1, 'users-page');
  const perPage = 10;

  // Editing state
  const editingUser = signal<User | null>(null, 'editing-user');
  const showCreateForm = signal(false, 'show-create-form');
  const formName = signal('');
  const formEmail = signal('');
  const formRole = signal('editor');
  const formError = signal<string | null>(null);

  // Filtered users
  const filtered = computed(() => {
    const q = search.value.toLowerCase();
    if (!q) return users.value;
    return users.value.filter(u =>
      u.name.toLowerCase().includes(q) ||
      u.email.toLowerCase().includes(q)
    );
  });

  // Paginated
  const paginated = computed(() => {
    const start = (page.value - 1) * perPage;
    return filtered.value.slice(start, start + perPage);
  });

  const totalPages = computed(() => Math.ceil(filtered.value.length / perPage));

  // Load
  async function loadUsers() {
    loading.value = true;
    try {
      users.value = await api.get<User[]>('/users');
    } finally {
      loading.value = false;
    }
  }

  // Create
  async function createUser() {
    formError.value = null;
    try {
      const newUser = await api.post<User>('/users', {
        name: formName.value,
        email: formEmail.value,
        role: formRole.value,
      });
      batch(() => {
        users.value = [...users.value, newUser];
        showCreateForm.value = false;
        formName.value = '';
        formEmail.value = '';
        formRole.value = 'editor';
      });
    } catch (err: any) {
      formError.value = err.data?.message ?? 'Failed to create user';
    }
  }

  // Update
  async function updateUser() {
    if (!editingUser.value) return;
    formError.value = null;
    try {
      const updated = await api.put<User>(`/users/${editingUser.value.id}`, {
        name: formName.value,
        email: formEmail.value,
        role: formRole.value,
      });
      batch(() => {
        users.value = users.value.map(u => u.id === updated.id ? updated : u);
        editingUser.value = null;
      });
    } catch (err: any) {
      formError.value = err.data?.message ?? 'Failed to update user';
    }
  }

  // Delete
  async function deleteUser(id: number) {
    try {
      await api.delete(`/users/${id}`);
      users.value = users.value.filter(u => u.id !== id);
    } catch (err: any) {
      formError.value = err.data?.message ?? 'Failed to delete user';
    }
  }

  // Start editing
  function startEdit(user: User) {
    batch(() => {
      editingUser.value = user;
      showCreateForm.value = false;
      formName.value = user.name;
      formEmail.value = user.email;
      formRole.value = user.role;
      formError.value = null;
    });
  }

  function cancelEdit() {
    batch(() => {
      editingUser.value = null;
      showCreateForm.value = false;
      formError.value = null;
    });
  }

  loadUsers();

  return html`
    <app-layout>
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
        <h1>Users</h1>
        <button class="btn btn-primary" @click=${() => {
          batch(() => {
            showCreateForm.value = true;
            editingUser.value = null;
            formName.value = '';
            formEmail.value = '';
            formRole.value = 'editor';
            formError.value = null;
          });
        }}>Add User</button>
      </div>

      ${() => formError.value
        ? html`<div class="alert alert-danger">${formError}</div>`
        : null
      }

      ${() => (showCreateForm.value || editingUser.value)
        ? html`
            <div class="card" style="margin-bottom: 1.5rem;">
              <div class="card-header">
                ${() => editingUser.value ? 'Edit User' : 'Create User'}
              </div>
              <div class="card-body">
                <div style="display: grid; grid-template-columns: 1fr 1fr 1fr auto; gap: 1rem; align-items: end;">
                  <div class="form-group">
                    <label>Name</label>
                    <input class="form-control" .value=${formName}
                      @input=${(e: Event) => { formName.value = (e.target as HTMLInputElement).value; }} />
                  </div>
                  <div class="form-group">
                    <label>Email</label>
                    <input class="form-control" type="email" .value=${formEmail}
                      @input=${(e: Event) => { formEmail.value = (e.target as HTMLInputElement).value; }} />
                  </div>
                  <div class="form-group">
                    <label>Role</label>
                    <select class="form-control" .value=${formRole}
                      @change=${(e: Event) => { formRole.value = (e.target as HTMLSelectElement).value; }}>
                      <option value="admin">Admin</option>
                      <option value="editor">Editor</option>
                      <option value="viewer">Viewer</option>
                    </select>
                  </div>
                  <div style="display: flex; gap: 0.5rem;">
                    <button class="btn btn-primary"
                      @click=${() => editingUser.value ? updateUser() : createUser()}>
                      ${() => editingUser.value ? 'Update' : 'Create'}
                    </button>
                    <button class="btn" @click=${cancelEdit}>Cancel</button>
                  </div>
                </div>
              </div>
            </div>
          `
        : null
      }

      <div style="margin-bottom: 1rem;">
        <input
          type="search"
          class="form-control"
          placeholder="Search users..."
          .value=${search}
          @input=${(e: Event) => {
            search.value = (e.target as HTMLInputElement).value;
            page.value = 1;
          }}
        />
      </div>

      ${() => loading.value
        ? html`<p>Loading users...</p>`
        : html`
            <table class="table table-striped table-hover">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                ${() => paginated.value.map(u => html`
                  <tr>
                    <td>${u.name}</td>
                    <td>${u.email}</td>
                    <td><span class="badge">${u.role}</span></td>
                    <td>
                      <span class=${`badge ${u.active ? 'badge-success' : 'badge-danger'}`}>
                        ${u.active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td>
                      <button class="btn btn-sm" @click=${() => startEdit(u)}>Edit</button>
                      <button class="btn btn-sm btn-danger" @click=${() => deleteUser(u.id)}>Delete</button>
                    </td>
                  </tr>
                `)}
              </tbody>
            </table>

            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 1rem;">
              <span style="color: #64748b;">${filtered} total users</span>
              <div style="display: flex; gap: 0.5rem;">
                <button class="btn btn-sm" ?disabled=${() => page.value <= 1}
                  @click=${() => { page.value = page.value - 1; }}>Previous</button>
                <span style="padding: 0.25rem 0.5rem;">
                  Page ${page} of ${totalPages}
                </span>
                <button class="btn btn-sm" ?disabled=${() => page.value >= totalPages.value}
                  @click=${() => { page.value = page.value + 1; }}>Next</button>
              </div>
            </div>
          `
      }
    </app-layout>
  `;
}
```

This is the most complex page in the application, and it demonstrates the full CRUD lifecycle. Load data from the API. Display it in a searchable, paginated table. Create new records. Edit existing ones. Delete them. Handle errors. Reset form state.

The `batch()` calls group multiple signal writes into single DOM updates. The `computed` signals derive the filtered and paginated lists from the raw data. The search input resets pagination to page 1. Every interaction flows through signals.

---

## 11. What We Built

This dashboard uses every module in the framework:

| Module | Usage |
|---|---|
| **Signals** | `token`, `user`, `notifications`, `stats`, `users`, form state |
| **Computed** | `isLoggedIn`, `isAdmin`, `filtered`, `paginated`, `totalPages`, `unreadCount` |
| **Effects** | Debug overlay auto-tracking, signal subscriptions in templates |
| **Batch** | Grouping form state resets, edit mode transitions |
| **html** | Every page and component template |
| **Tina4Element** | `stat-card`, `notification-bell`, `app-layout` |
| **Routing** | Login, dashboard, users, 404 with guards |
| **API** | Login, CRUD operations, stats loading, 401 interceptor |
| **WebSocket** | Live stats, notifications, activity feed |
| **PWA** | Installable with network-first caching |
| **Debug** | Labels on every signal, conditional import |

Every module. One application. Deployable as-is.

The entire frontend -- framework, components, routes, state management, everything -- ships under 10KB gzipped. Try building this dashboard with React, Vue, or Angular. Count the packages. Measure the bundle.

---

## Summary

A complete, production-grade admin dashboard does not need 50 npm packages, a state management library, a routing library, a form library, and a CSS-in-JS solution. It needs tina4-js and clear thinking.

The patterns repeat:

1. **Signals for state.** One signal per piece of data.
2. **Computed for derived data.** Filtering, pagination, auth checks.
3. **Batch for grouped writes.** Form resets, mode transitions.
4. **html for templates.** Reactive text, reactive blocks, events.
5. **Components for reuse.** Props in, events out.
6. **Routes with guards.** Public and protected.
7. **API with interceptors.** Auth, error handling.
8. **WebSocket for live data.** Pipe into signals.

Eight patterns. One framework. Now build your own.
