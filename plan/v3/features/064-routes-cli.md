# Feature 064: `tina4 routes` CLI

## Identity and status

- Matrix identity: 64 - list the effective route table
- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-08-01, previously hidden in the 11/12/79 bundle
- Dependency: Feature 6 router/dispatch and Feature 79 route groups
- Existing decision: ADR-0015 follow-on for visible resolution order

Feature 64 owns application boot/discovery for inspection, human and machine
output, route registration order, middleware/auth visibility and consistent CLI
exit behavior. Route matching and group composition belong to Features 6 and
79.

## Historical evidence retained

| Port | Historical source | Boots app | Preserves order | `--json` |
| --- | --- | --- | --- | --- |
| Python | `Router.get_routes()` after importing `app` | partial | yes | no |
| PHP | nonexistent `Router::list()` | attempted | no | no |
| Ruby | `Tina4::Router.routes` after `initialize!` | yes | yes | no |
| Node | filesystem scan of `src/routes` | no | no | no |

The PHP command fatally called a method that did not exist. Python omitted
auto-discovered route files, Node omitted programmatic routes and sorted by path
instead of resolution order, and none displayed middleware. No port had a
behavioral command test; manifest checks proved only that the command name
existed.

The standalone audit must define one route-table record, exact order, boot
failure behavior, `--json` report and real generated/programmatic/grouped route
fixtures before this feature can be final.
