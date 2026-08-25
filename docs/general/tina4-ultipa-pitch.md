# Tina4 + Ultipa: your data has edges

Every application has a network hiding inside it. Users follow users.
Orders belong to customers who share addresses with other customers.
Documents cite documents. Products co-occur in baskets. The
relationships are the interesting part, and a row-and-column database
asks you to squeeze them through JOINs until they lose their shape.

A graph database keeps the shape. Ultipa stores nodes and edges as
first-class data and traverses them at real hardware speed. Its UQL
query language reads back the question you asked: "give me the
friends-of-friends of user 42 who don't already follow 42, ranked by
how many mutual connections they share." That question is the query.
Not a translation of the question. The query.

Tina4 is the web framework you wrap around it.

Zero third-party runtime dependencies. Four languages that mean the
same thing everywhere: Python, PHP, Ruby, Node.js. File-based routes,
native HTTP, Frond templates that render at 2.8x the speed of the
usual alternatives. A skill file that teaches an AI agent to write
correct Tina4 code on the first attempt.

The Ultipa driver family ships alongside. ultipa-python. ultipa-php.
ultipa-ruby. ultipa-nodejs. All four dropped protobuf and grpc at
0.2.1. The wire codec is hand-rolled proto3, roughly 800 lines per
language, no C extensions, no dependency footprint the framework had
to grow to carry. The driver looks and feels like every other Tina4
subsystem: import, connect, query.

## Why the combination fits

The two projects share a philosophy: fewer moving parts, more real
work. Tina4 core is 5000 lines per language. The Ultipa driver is
under 1000 lines per language. Deploy them together and your Docker
image weighs 40MB, not 400. That difference shows up in your build
time, your deploy time, your cold-start latency, and your monthly
bandwidth bill.

The four-language parity matters. Python for research and ML
pipelines. Node.js for the SSR frontend. PHP for the legacy team
that runs your billing. Ruby for the operations tooling. Every one
speaks Ultipa the same way. The UQL you tested in your Python
notebook lands verbatim in the PHP route that ships to production.

The AI-agent story matters too. Tina4 ships with per-language
`tina4-developer` skills that teach a coding agent the framework's
conventions: file-based routes, ORM idioms, Frond template syntax,
JWT auth. Add Ultipa to a Tina4 project and the same skill surface
loads the graph patterns: nodes as data, edges as relationships,
UQL as the query, JSON as the response. An agent reads the skill
once and writes correct graph code every time after.

## What you get in five minutes

    tina4 init python my-graph-app
    cd my-graph-app
    uv add ultipa

Point the Ultipa endpoint at your instance in `.env`, drop a route
file into `src/routes/api/`, write the UQL, return the result. The
framework serialises the graph response to JSON, applies your auth
middleware, logs the request through the structured logger, and
appears in Swagger without a config file. No adapter to write. No
translation layer to maintain. No graph client to shim.

## Where this lands

Recommendation engines. Fraud graphs. Knowledge bases. Social
features. Access-control trees. Supply chains. Anything where a
useful query starts with the phrase "the network of...". A
traditional stack asks you to write a data-access layer that
translates graph questions into JOIN sequences. This one asks you to
write the question and hands you the answer.

Your data has edges. The stack should show them.
