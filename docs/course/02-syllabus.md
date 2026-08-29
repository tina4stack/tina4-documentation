# Chapter 2: The Syllabus

Thirty-six modules across three levels. Every module names the practice it teaches and the
source that practice comes from, shows the same practice in another stack, and states the
case against it.

The column that matters most is the last one. Knowing a rule makes you employable. Knowing
where the rule breaks makes you senior.

---

## Level 1: Make It Work

**Entry requirement:** none. You have never written code.

**Exit standard:** you can build a small web application, explain every line, and read a
stack trace without panic.

**Weighting:** comprehension 70, working code 30.

### 1. The Request and the Answer

The client-server model. What a program is, what a server is, what actually travels over
the wire. You write one route and get an answer in a browser.

- **Principle:** HTTP as a contract. Methods, status codes and their meanings (RFC 9110).
- **Elsewhere:** Flask `@app.route`, Express `app.get`, Rails `routes.rb`.
- **When not to:** HTTP is a poor fit for long-lived bidirectional state. Recognise when
  you want a socket instead of a request.

### 2. Naming Things and Holding Them

Variables, values, types. The first hard problem in computing, met on day two.

- **Principle:** names as design. Intention-revealing identifiers (Martin, *Clean Code*, ch.2).
- **Elsewhere:** PEP 8, Ruby style guide, Google style guides. Every language has one and
  they mostly agree.
- **When not to:** short scopes tolerate short names. `for i in range(10)` needs no essay.

### 3. Doing One Thing

Functions, parameters, return values. The unit of reuse and the unit of thought.

- **Principle:** single responsibility (Martin, SOLID). Pure functions and why they are
  easy to test.
- **Elsewhere:** identical in every language you will ever touch.
- **When not to:** splitting a ten-line function into five two-line functions makes it
  harder to read, not easier. Cohesion beats brevity.

### 4. Choosing

Conditionals, truthiness, guard clauses, the arrow anti-pattern.

- **Principle:** guard clauses and early return. Cyclomatic complexity as a measurable
  warning (McCabe, 1976). Tina4's metrics command puts a number on it.
- **Elsewhere:** linters everywhere flag the same shape.
- **When not to:** a guard clause per branch scatters logic. Sometimes the nested version
  tells the story better.

### 5. Repeating

Loops, iteration, collections.

- **Principle:** iterate over sets, not indexes. First sight of the N+1 problem, which will
  return to hurt you in Level 3.
- **Elsewhere:** comprehensions, `map`, `each`, streams.
- **When not to:** a loop that hits the network per item is not a loop, it is an outage.

### 6. Shapes of Data

Lists, dictionaries, JSON. The shape of an answer.

- **Principle:** data contracts. JSON as interchange (RFC 8259). Shape stability as a
  promise to whoever consumes you.
- **Elsewhere:** every API you will ever call.
- **When not to:** JSON is not a database, and deeply nested JSON is a schema you refused
  to design.

### 7. Where Things Go

Project structure. Tina4 auto-discovers `src/routes`, `src/orm`, `src/templates`. You learn
why a framework would decide that for you.

- **Principle:** convention over configuration (Rails doctrine, Heinemeier Hansson). The
  cost of a decision is not the decision, it is making it five hundred times.
- **Elsewhere:** Rails, Next.js file routing, Laravel. Contrast with Spring's explicit
  wiring and Express's freeform structure.
- **When not to:** convention hides behaviour. When the magic breaks, an explicit codebase
  is faster to debug. Know which trade you took.

### 8. Showing It to People

Templates with Frond, HTML, auto-escaping.

- **Principle:** separation of presentation and logic. Output encoding as the fix for
  cross-site scripting (OWASP A03).
- **Elsewhere:** Twig, Jinja2, ERB, Blade. Frond is Twig-compatible on purpose.
- **When not to:** a JSON API has no view layer. Do not render HTML for a machine.

### 9. Remembering

Databases, tables, rows, SQL you write by hand before any ORM touches it.

- **Principle:** the relational model (Codd, 1970). Declarative queries: say what you want,
  not how to fetch it.
- **Elsewhere:** SQL is SQL. This module is the most portable thing in the course.
- **When not to:** not every piece of state deserves a table. A cache is not a database.

### 10. When It Goes Wrong

Errors, exceptions, stack traces, structured logging.

- **Principle:** fail fast (Shore, 2004). Errors that surface beat errors that hide.
- **Elsewhere:** every runtime. Reading a trace is a career skill.
- **When not to:** failing fast at a user-facing boundary is just a 500. Degrade at the
  edge, fail loudly inside.

### 11. Proving It Works

First tests, using Tina4's in-process test client against the real front controller.

- **Principle:** arrange, act, assert. The test pyramid (Cohn, 2009), and the regression
  test as a lock on fixed behaviour.
- **Elsewhere:** pytest, RSpec, PHPUnit, Jest.
- **When not to:** a test that asserts the framework works tests nothing. Test your
  decisions, not your dependencies.

### 12. Level 1 Capstone

Build a working application end to end. Defend it in writing.

---

## Level 2: Make It Right

**Entry requirement:** Level 1, or you can already write working code.

**Exit standard:** you can structure an application another developer maintains without
asking you questions.

**Weighting:** comprehension 75, working code 25.

### 13. Thin Routes, Real Domain

Logic moves out of handlers and into code that knows nothing about HTTP.

- **Principle:** separation of concerns. The service layer (Fowler, *PoEAA*). A fat
  controller is the most common smell in web software.
- **Elsewhere:** Rails service objects, Laravel actions, Spring services.
- **When not to:** a three-line endpoint does not need a service class. Indirection you do
  not need is a cost you pay forever.

### 14. Objects That Mean Something

ORM models. One domain object per file.

- **Principle:** Active Record (Fowler, *PoEAA*) and its limits. Naming from the business
  domain, not the table (Evans, *DDD*).
- **Elsewhere:** Django models, Eloquent, ActiveRecord, Hibernate.
- **When not to:** Active Record couples your domain to your schema. When the domain gets
  complicated, that coupling is the thing that hurts. This is where Data Mapper earns its
  keep.

### 15. Schema as Code

Migrations. Forward-only thinking, rollbacks, why nobody edits the database by hand.

- **Principle:** evolutionary database design (Ambler and Sadalage). Schema changes are
  versioned artifacts, reviewed like code.
- **Elsewhere:** Alembic, Flyway, Liquibase, Rails migrations.
- **When not to:** auto-migrate on startup is a gift in development and a hazard in
  production. Level 3 covers expand and contract.

### 16. Trust Nothing

Validation, injection, parameterised queries, the boundary.

- **Principle:** OWASP Top 10. Validate at the boundary, never build SQL by concatenation,
  treat all input as hostile.
- **Elsewhere:** universal. This module is why you get hired and not sued.
- **When not to:** validating the same value at every layer is theatre. Validate at the
  edge, trust your own core.

### 17. Who Are You

Sessions, cookies, JWT. Tina4 makes writes require auth unless you open them.

- **Principle:** authentication versus authorisation. Secure defaults, deny by default
  (Saltzer and Schroeder, 1975, still the best paper on this).
- **Elsewhere:** Devise, Passport, Spring Security.
- **When not to:** never write your own crypto. Also: JWT is not a session, and using it
  as one gives you logout you cannot perform.

### 18. Configuration and Secrets

Environment variables, the `TINA4_` namespace, secrets that never reach git.

- **Principle:** 12-Factor App, factor III: store config in the environment. Strict
  separation of config from code.
- **Elsewhere:** dotenv everywhere, Vault, AWS Secrets Manager, Kubernetes secrets.
- **When not to:** environment variables are a flat namespace with no types and no
  validation. Large config belongs in a file you validate at boot.

### 19. Talking to Other Systems

The HTTP client. Timeouts, retries, idempotency.

- **Principle:** the network is not reliable (Deutsch, *Fallacies of Distributed
  Computing*). Exponential backoff with jitter. Idempotency keys.
- **Elsewhere:** requests, Faraday, Guzzle, axios.
- **When not to:** retrying a non-idempotent write is how you charge a customer twice.

### 20. Work That Waits

Queues, producers, consumers, visibility timeouts.

- **Principle:** asynchronous messaging. At-least-once delivery and the idempotent consumer
  it forces on you (Hohpe and Woolf, *Enterprise Integration Patterns*).
- **Elsewhere:** Celery, Sidekiq, BullMQ, SQS.
- **When not to:** a queue turns one failure mode into four. If the work takes 50ms, do it
  in the request.

### 21. Speed Without Lies

Caching, ETags, conditional requests, invalidation.

- **Principle:** HTTP caching (RFC 9111). Cache invalidation is genuinely hard and
  pretending otherwise ships stale data.
- **Elsewhere:** Redis, Memcached, CDN edge caching.
- **When not to:** caching a cheap query to hide a slow one is a bandage on a wound you
  have not looked at.

### 22. Contracts

Swagger and OpenAPI. Versioning an API you cannot take back.

- **Principle:** API-first design. Semantic versioning. Consumer-driven contracts (Robinson).
- **Elsewhere:** OpenAPI is the standard everywhere.
- **When not to:** an internal endpoint with one consumer does not need a version scheme.

### 23. Tests That Earn Their Keep

Real dependencies, real databases, regression locks on every fixed bug.

- **Principle:** test doubles and their cost (Fowler, *Mocks Aren't Stubs*). A mock asserts
  your assumption, not reality. A test that passes against a mock and fails in production
  was never a test.
- **Elsewhere:** testcontainers, factory patterns, fixtures.
- **When not to:** you cannot integration-test a payment provider's failure modes on every
  commit. Know exactly what you gave up when you faked it.

### 24. Level 2 Capstone

Take a working but badly structured application and make it maintainable. Justify every
change.

---

## Level 3: Make It Last

**Entry requirement:** Level 2, or professional experience.

**Exit standard:** you can make an architectural decision, record it, and defend it under
disagreement.

**Weighting:** comprehension 85, working code 15.

### 25. Deciding on Purpose

Architecture decision records. Trade-off analysis in writing.

- **Principle:** ADRs (Nygard, 2011). One-way versus two-way doors (Bezos). Reversible
  decisions get made fast, irreversible ones get written down.
- **Elsewhere:** the Tina4 project keeps its own ADR log. You will read real ones.
- **When not to:** an ADR for every choice buries the choices that mattered.

### 26. When Not to Abstract

Premature abstraction, YAGNI, the rule of three.

- **Principle:** "Duplication is far cheaper than the wrong abstraction" (Metz, 2016).
  YAGNI (Jeffries). DRY is about knowledge, not characters (Hunt and Thomas).
- **Elsewhere:** the most expensive mistakes in most codebases live here.
- **When not to:** the inverse failure is real too. Copy-paste across six services is not
  humility, it is debt.

### 27. Boundaries

Modules, coupling, cohesion, dependency direction.

- **Principle:** coupling and cohesion (Constantine and Yourdon). Dependency inversion
  (SOLID). Ports and adapters (Cockburn).
- **Elsewhere:** hexagonal architecture, clean architecture, and their overuse.
- **When not to:** a hexagonal architecture around a CRUD app is ceremony. Layers cost
  navigation.

### 28. Data Under Load

Indexes, query plans, N+1, connection pools.

- **Principle:** measure before optimising (Knuth, 1974, and the quote is usually
  misused). Read a query plan before you touch a query.
- **Elsewhere:** `EXPLAIN` in every relational database.
- **When not to:** an index on every column makes writes slow and the planner confused.

### 29. Failure Is Normal

Timeouts, circuit breakers, bulkheads, graceful degradation.

- **Principle:** stability patterns (Nygard, *Release It!*). Every integration point is a
  failure waiting for traffic.
- **Elsewhere:** Hystrix, Resilience4j, Envoy, service meshes.
- **When not to:** a circuit breaker on a call that cannot fail independently just adds a
  failure mode.

### 30. Observability

Structured logs, metrics, traces, service level objectives.

- **Principle:** the golden signals (Google SRE Book). Structured logging as queryable
  data, not prose.
- **Elsewhere:** OpenTelemetry, Prometheus, Grafana.
- **When not to:** logging everything at debug in production costs money and hides the
  line that mattered.

### 31. Security in Depth

Threat modelling, least privilege, supply chain.

- **Principle:** STRIDE. Defence in depth. Supply chain integrity (SLSA, SBOM). This is
  where Tina4's zero-dependency stance stops being a slogan and becomes a threat model
  you can draw.
- **Elsewhere:** Dependabot, Snyk, and the incidents that made them necessary.
- **When not to:** security controls that make the safe path slow get routed around by
  your own team.

### 32. Concurrency and State

Async, races, transactions, isolation levels.

- **Principle:** ACID and what each letter actually guarantees. At-least-once versus
  exactly-once, and why exactly-once is mostly a marketing claim.
- **Elsewhere:** every database, every queue.
- **When not to:** serialisable isolation everywhere trades correctness you had for
  throughput you needed.

### 33. Shipping Safely

CI/CD, migrations against live traffic, feature flags, rollback.

- **Principle:** continuous delivery (Humble and Farley). Expand and contract migrations.
  A deploy you cannot roll back is not a deploy, it is a commitment.
- **Elsewhere:** GitHub Actions, blue-green, canary releases.
- **When not to:** feature flags left in the codebase become permanent branching nobody
  understands.

### 34. Performance and Cost

Honest benchmarking. Energy and carbon as engineering constraints, measured with Carbonah.

- **Principle:** measure, do not guess. Single-sample benchmarks lie. Efficiency is a cost
  lever and a carbon lever at the same time.
- **Elsewhere:** the Green Software Foundation's principles.
- **When not to:** optimising a path that runs twice a day is time you stole from the path
  that runs a million times.

### 35. Working With AI

Grounding, review discipline, and the code you should not accept.

- **Principle:** AI writes plausible code, and plausible is not correct. Ground the model
  in current API, then review as if a stranger wrote it, because one did.
- **Elsewhere:** every team you join will be arguing about this.
- **When not to:** generated code you cannot explain does not go in. That rule is the whole
  course in one sentence.

### 36. Level 3 Capstone

Design a system, ship it, and write the decision records. Defend the design against a
reviewer who disagrees with you.

---

## Assessment Summary

| Level | Modules | Code gate | Comprehension gate | Pass mark |
|-------|---------|-----------|--------------------|-----------|
| 1 Make It Work | 1 to 12 | 30 | 70 | 60 |
| 2 Make It Right | 13 to 24 | 25 | 75 | 65 |
| 3 Make It Last | 25 to 36 | 15 | 85 | 70 |

The comprehension gate scores four dimensions: Explain, Predict, Diagnose, Judge. Level 1
weights Explain heaviest. Level 3 weights Judge heaviest. The examiner is instructed to
score restated documentation at zero, which means the student who memorises the chapter
fails and the student who understood it passes.

Working code with no understanding cannot reach the pass mark at any level. That is the
design.
