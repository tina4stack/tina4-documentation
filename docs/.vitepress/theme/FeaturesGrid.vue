<script setup lang="ts">
const features = [
  { icon: '🌐', title: 'Four Languages, One API', details: 'Python, Node.js, PHP, and Ruby share the same project structure, CLI, template syntax, route patterns, and .env variables. Learn one, know all four.' },
  { icon: '🧭', title: 'One CLI to Rule the Stack', details: 'The Rust-based `tina4` CLI detects the language, compiles SCSS, watches files, and delegates to the framework. `tina4 init`, `tina4 serve`, and `tina4 migrate` run the same across Python, PHP, Ruby, and Node.js.' },
  { icon: '📦', title: 'Zero Runtime Dependencies', details: 'Every Tina4 backend runs on the standard library. No native addons, no node-gyp, no vendor tree. Your requirements.txt / composer.json / Gemfile / package.json each hold one entry.' },
  { icon: '🛣️', title: 'Convention-Based Routing', details: 'Drop a file in `src/routes/`. The framework registers it. Typed path params (`{id:int}`, `{slug:slug}`, `{id:uuid}`) reject bad input with 404 before your handler runs.' },
  { icon: '🔌', title: 'Built-in WebSocket + SSE', details: 'Real-time bidirectional comms and server-sent events across all backends. Redis backplane for horizontal scaling. The same `WebSocketServer` API in every language.' },
  { icon: '🎨', title: 'Frond (Twig) Templating', details: 'One Twig-compatible engine. Variables, loops, template inheritance with `{{ parent() }}`, macros, filters. Write your layout once, render it in any language.' },
  { icon: '🗃️', title: 'Six Databases, One ORM', details: 'SQLite, PostgreSQL, MySQL, MSSQL, Firebird, MongoDB. `Database::create("sqlite:///app.db")` works anywhere. `sqlite:///path` is relative to your project root, the same convention across all four frameworks.' },
  { icon: '🔐', title: 'Secure by Default', details: 'GET routes are public, POST/PUT/PATCH/DELETE require a bearer token. JWT (HS256/RS256), PBKDF2 password hashing, rate limiting, CSRF form tokens, all built in, nothing to configure.' },
  { icon: '📋', title: 'Swagger at /swagger', details: 'Add an `@description` decorator to your route. Visit `/swagger`. Your API docs appear, typed, grouped, ready for your team.' },
  { icon: '🪢', title: 'GraphQL Included', details: 'Zero-dependency GraphQL engine. Point it at your ORM models, get a full schema with queries, mutations, and a GraphiQL IDE. `POST /graphql` in one line.' },
  { icon: '📬', title: 'Queues + Background Work', details: 'File-backed by default, RabbitMQ/Kafka/MongoDB when you scale. Producer/consumer/dead-letter semantics consistent across languages. Periodic tasks via `background(fn, interval)`, no threads.' },
  { icon: '🛠️', title: 'Dev Dashboard on /__dev', details: 'Routes, requests, SQL runner, queue monitor, mailbox, WebSocket inspector, error tracker, AI chat, a shared SPA across all four frameworks. `TINA4_DEBUG=true` turns it on.' },
]
</script>

<template>
  <section class="fg">
    <div class="fg-inner">
      <div class="fg-grid">
        <div v-for="f in features" :key="f.title" class="fg-card">
          <div class="fg-icon">{{ f.icon }}</div>
          <h2 class="fg-title">{{ f.title }}</h2>
          <p class="fg-details">{{ f.details }}</p>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.fg {
  margin: 32px 0 8px;
}
.fg-inner {
  width: 100%;
}
.fg-grid {
  display: grid;
  grid-template-columns: repeat(1, 1fr);
  gap: 16px;
}
.fg-card {
  display: block;
  min-width: 0;
  height: 100%;
  padding: 24px;
  border: 1px solid var(--vp-c-bg-soft);
  border-radius: 12px;
  background: var(--vp-c-bg-soft);
  transition: border-color 0.25s, background-color 0.25s;
}
.fg-card:hover {
  border-color: var(--vp-c-brand-1);
}
.fg-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  margin-bottom: 20px;
  border-radius: 8px;
  background: var(--vp-c-default-soft);
  font-size: 24px;
  line-height: 1;
}
.fg-title {
  margin: 0 0 8px;
  border: 0;
  padding: 0;
  font-size: 16px;
  font-weight: 600;
  line-height: 1.4;
  letter-spacing: -0.01em;
}
.fg-details {
  margin: 0;
  color: var(--vp-c-text-2);
  font-size: 14px;
  font-weight: 500;
  line-height: 1.6;
}
@media (min-width: 640px) {
  .fg-grid { grid-template-columns: repeat(2, 1fr); gap: 24px; }
}
@media (min-width: 960px) {
  .fg-grid { grid-template-columns: repeat(3, 1fr); }
}
</style>
