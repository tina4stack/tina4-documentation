# Plan: IoT + EV Charging Support

## Status: APPROVED + UNBLOCKED (owner 2026-07-21: framework capability, no client gating).
## Decisions taken below. Build order: Phase 1a spatial (Python master -> mirror x3), then
## Phase 1 IoT, then Phase 2 OCPP as a separate package. Author: maintainer agent, 2026-07-21.

## Goal
Let a Tina4 developer build (a) an IoT backend that ingests device telemetry and issues
commands, and (b) an EV charging backend that speaks OCPP to real chargers - without
leaving the framework or adding runtime dependencies.

## Origin / driving requirement (2026-07-21)
The request came from a **client whose core business is GIS**. That changes the ordering:
for a GIS shop, charge points and devices are primarily **located** things - stations on a
map, vehicles moving through space, assets inside or outside a zone. The framework's
biggest gap for them is not MQTT or OCPP, it is that **Tina4 has no spatial support at all**
(verified case-sensitively 2026-07-21: zero hits for PostGIS / ST_Distance / ST_DWithin /
geography( / SRID / GeoJSON / GiST across all four frameworks; `orm/fields.py` has only
Field, JSONField, ForeignKeyField + relationship descriptors - no geometry type).
So **spatial lands first (Phase 1a)** - it is the reusable framework primitive, it unblocks
everything else, and it is valuable to every Tina4 user, not just this client.

## Grounding: what we already have (verified in source 2026-07-21)
- **RFC 6455 WebSocket server** + per-route auth (JWT via header / subprotocol / query) +
  Redis/NATS backplane for multi-instance broadcast + idle reaper + origin allow-list.
  **OCPP 1.6J is JSON over WebSocket, so this is a direct fit - the single biggest asset.**
- **Hand-rolled binary wire protocols already in production**: RabbitMQ (AMQP 0-9-1, incl.
  Connection.TuneOk negotiation) and Kafka backends, zero-dependency, all 4 languages.
  Precedent that a hand-rolled MQTT client is normal engineering here, not a stunt.
- **Queue** (file/RabbitMQ/Kafka/Mongo) with reservation + visibility timeout + dead-letter.
- **DocStore** (Mongo-style API, SQLite JSON1 fallback) for device/shadow documents.
- ORM + engine-aware migrations, Auth (JWT/API key), Events, `background()` periodic tasks,
  unified pluggable-backend pattern (cache/session/queue) to copy for telemetry.
- **Nothing exists yet** for mqtt / ocpp / modbus / coap / lwm2m. Green field.

## Architectural position - IT ALL GOES IN CORE (owner call 2026-07-21)
Everything here ships **in the framework**: spatial, MQTT, Modbus, device registry, telemetry
store, AND OCPP/OCPI. Batteries included, one install, zero dependencies.

I initially argued OCPP should be a separate `tina4-ocpp` package. That was wrong and
inconsistent with what Tina4 already is: core ALREADY ships WSDL/SOAP, GraphQL, Swagger,
Queue with RabbitMQ/Kafka/Mongo wire protocols, an MCP server, DocStore, Messenger
(SMTP/IMAP), and realtime WebRTC calls+chat+files. WSDL/SOAP is more niche than OCPP. "One
import, everything works" is principle #2. And a separate package would be a 5th repo per
language with its own release cadence and version skew, sitting OUTSIDE the parity mandate
and the no-mock CI gate - more maintenance liability, not less, as the 3.13.79/80/81
alignment work this week showed.

**The one constraint that must hold** (the legitimate half of the original concern): a user
who never touches charging must not pay for it.
- **Lazy loading / opt-in registration.** OCPP, MQTT, Modbus and the telemetry store are
  imported and wired ONLY when configured (env var present, or the developer registers the
  route/consumer). No import cost, no routes mounted, no background task started otherwise.
  Same philosophy as the approved `TINA4_HEADLESS` flag: capability present, cost absent.
- **Same bar as everything else in core**: 4-language parity, real no-mock tests against a
  real charge-point simulator / real broker, docs that match code, security by default.

## Phases

### Phase 0 - decisions + spike (no shipping)
- [ ] Resolve the 3 Decisions below.
- [ ] Spike: hand-rolled MQTT 3.1.1 CONNECT/PUBLISH/SUBSCRIBE against a real Mosquitto in
      Docker, in Python only. Measure LOC + confirm the packet codec is tractable per language.
- [ ] Spike: minimal OCPP 1.6J BootNotification + Heartbeat over the existing WS route,
      driven by a real open-source charge-point simulator. Proves the WS server carries it.
- [ ] Stand up CI services: Mosquitto (MQTT) and a charge-point simulator container. The
      no-mock rule means these are prerequisites, not nice-to-haves.

### Phase 1a - SPATIAL / GIS core (framework, all 4) - do this FIRST
The GIS client's real gap, and the most reusable thing on this whole plan. Zero new runtime
dependencies: PostGIS is a server-side extension, MySQL and MSSQL have native spatial types,
so this is SQL generation plus a field type - exactly Tina4's shape.
- [x] **`PointField`** DONE Python master (`feature/spatial-gis` e2f0768, 125 real PostGIS
      tests, +125 / zero regressions; verified by main session: diff re-read, tests re-run).
      NOTE: the dialect hook is **`SQLTranslator`** - Python `database/adapter.py:613`, Ruby
      `lib/tina4/sql_translator.rb:18`, Node `packages/orm/src/sqlTranslation.ts:22`. PHP is
      the ODD ONE OUT with `SqlTranslation` (`Tina4/SqlTranslation.php:14`) - drifting on both
      the acronym casing AND the noun. 3 of 4 agree, so **PHP gets renamed to `SQLTranslator`**
      (see the naming-drift task below). My earlier "mirrors use each language's existing
      class" note was wrong - that would have cemented the drift.
      Storage form EWKT; read form (HEX)EWKB parsed client-side so the ORM read path needs NO
      spatial SQL. Full contract in the "PointField contract" section below.
- [ ] **NAMING DRIFT FIX (PHP): `SqlTranslation` -> `SQLTranslator`.** Breaking, no alias
      (per the no-aliases rule: rename the primary, do not add a compatibility shim). PSR-4
      means the file renames too (`Tina4/SqlTranslation.php` -> `Tina4/SQLTranslator.php`).
      Needs a `Breaking:` changelog + migration note. Do NOT rewrite historical release notes -
      they correctly record what shipped under the old name.
- [ ] Mirror `PointField` to PHP / Ruby / Node (WKB reader is the real port cost - port it
      rather than wrapping reads in ST_AsText, which would touch every ORM finder's SQL).
- [x] **`select_distance()` + `_select_params`** DONE Python master
      (`feature/spatial-gis` 4c0a578). `_select_params` binds FIRST in `_all_params()`
      because SELECT is the first clause `to_sql()` emits; `select()` clears it when it
      replaces the column list so an orphaned value can never shift later parameters;
      `count()` drops it with the SELECT list. SQL comes from
      `SQLTranslator.distance_as()`, never from QueryBuilder.
- [x] `intersects()` and `bbox()` DONE Python master (4c0a578), through the SQLTranslator
      (`geometry_literal` / `intersects` / `bbox`). `intersects()` takes WKT/EWKT of any
      geometry type or a GeoJSON geometry/Feature via the new `geometry_binding()` funnel
      in `orm/point.py` - the whole geometry is ONE bound parameter and the engine parses
      it, so there is no hand-rolled WKT writer to port. `bbox()` corners are (lon, lat)
      south-west first, all four bound; inside-out / out-of-range / non-finite boxes are
      refused naming the axis.
- [x] **REAL BUG (4c0a578): `order_by_distance()` was non-deterministic for equidistant
      rows** - distance alone is not a total order and PostgreSQL's sort is not stable, so
      an ordinary UPDATE re-ordered tied rows (measured [1..12] -> [4..12,1,2,3], 20/20
      runs on PostGIS 16) and pagination skipped and repeated rows. Fixed with a stable
      secondary sort key: `ORM.query()` now carries the model PK column into the builder
      (`ORM._get_pk_column()`), `tie_break=` overrides, `tie_break=False` opts out. The
      mirrors MUST carry this - it is a data-correctness bug, not a cosmetic one.
- [x] Real tests for the whole of the above: 278 real-PostGIS tests, no mocks, each one
      proven able to fail via a 12-mutation matrix. Nine previously-untested cases from
      `iot-gis-test-plan.md` now covered: A1, B1b, B4, B5b, C2, C3b, C4, C5, C7. C7
      confirmed the existing `ST_DWithin` predicate ALREADY uses the GiST index (Index
      Scan 1.7 ms vs Seq Scan 145 ms over 5 000 rows) - no predicate change needed.
- [ ] ~~`GeometryField`~~ (polygons/lines) - only if a real need appears; PointField covers
      chargers, devices and vehicle fixes.
- [ ] (superseded) original wording: SRID-aware field accepting WKT, GeoJSON, `(lon, lat)`:
      PostGIS `geography`/`geometry`, MySQL/MSSQL native spatial, SQLite via lat/lon columns
      (SpatiaLite optional, never required).
- [ ] **Engine-aware spatial DDL in migrations**: create the spatial column and its spatial
      index (GiST on PostGIS, SPATIAL INDEX on MySQL) through the existing migration runner.
- [ ] **QueryBuilder spatial predicates**, routed through the existing **`SqlTranslation`**
      dialect layer (the natural hook - it already translates LIMIT/ILIKE/concat per engine):
      `within_distance(point, metres)`, `intersects(geom)`, `bbox(...)`,
      `order_by_distance(point)` -> `ST_DWithin` / `ST_Intersects` / `ST_Distance` etc.
- [ ] **GeoJSON output**: extend the existing `response()` auto-serialisation so a model or
      list of models with a geometry field can emit a GeoJSON Feature / FeatureCollection.
      This is what a GIS front end (or tina4-js on a map) actually consumes.
- [ ] Real tests: a live PostGIS container (add to the 4 CIs alongside the existing PG),
      real inserts, real radius/intersects queries with known-answer fixtures, real GeoJSON.

### Phase 1 - IoT core (framework, all 4, full parity + real tests)
- [ ] **MQTT client**: connect/reconnect, QoS 0/1 (2 only if justified), TLS, last-will,
      topic subscribe with wildcards, retained messages. Zero dependency, per language.
      Env-driven like the queue: `TINA4_MQTT_URL`, `TINA4_MQTT_CLIENT_ID`, credentials.
- [ ] **Wire MQTT as a Queue backend** where semantics allow, so existing `Queue` code paths
      and `background()` consumers work unchanged.
- [ ] **Device registry + shadow state**: `Device` ORM model (id, type, credentials, last_seen,
      metadata JSON) + desired/reported shadow documents via DocStore. Provisioning + rotate.
- [ ] **Pluggable telemetry store** following the cache/session backend pattern:
      `TINA4_TELEMETRY_BACKEND` = `database` (default, SQL + rollups) | `mongodb` |
      `timescale` | `influx`. Write path: append-only; read path: range + downsample.
- [ ] Real tests: live Mosquitto round-trip, real DB writes, reconnect-after-broker-kill.

### Phase 2 - OCPP 1.6J central system (separate `tina4-ocpp` package)
- [ ] Message framing: `[2|3|4, UniqueId, Action, Payload]` CALL/CALLRESULT/CALLERROR over
      the existing WebSocket route, with per-charge-point auth and the backplane for HA.
- [ ] Core profile: BootNotification, Heartbeat, StatusNotification, Authorize,
      StartTransaction, StopTransaction, MeterValues, DataTransfer.
- [ ] Central-initiated: RemoteStart/StopTransaction, Reset, UnlockConnector,
      Change/GetConfiguration, ChangeAvailability, ClearCache.
- [ ] Domain models: ChargePoint, Connector, Transaction, MeterValue, IdTag/AuthList.
- [ ] Real tests against a real charge-point simulator - no mocked chargers, ever.

### Phase 3 - energy + site control
- [ ] Smart charging: SetChargingProfile / ClearChargingProfile / GetCompositeSchedule,
      site-level load balancing across connectors.
- [ ] **Modbus TCP client** (framework) for meters and inverters at the site.
- [ ] **Carbonah tie-in**: kWh delivered -> gCO2e reporting per session/site. On-brand, and a
      genuine differentiator for a framework that already tracks its own carbon.

### Phase 4 - only if the product needs it
- [ ] OCPP 2.0.1 (device model, variables, security profiles, ISO 15118 Plug and Charge
      certificate handling). Materially larger than 1.6J - treat as its own epic.
- [ ] OCPI 2.2.1 roaming (Locations, Sessions, CDRs, Tariffs, Tokens, Commands) for CPO/eMSP.
- [ ] CoAP / LwM2M for constrained devices. OpenADR for demand response.

## Decisions TAKEN (owner 2026-07-21: "make the framework capable" - not client-gated)
No client discovery gates this. We are building framework capability, so these are engineering
calls, made and recorded here:

1. **Two different axes, do not conflate them.**
   - **Language parity is MANDATORY**: everything framework-side ships in Python, PHP, Ruby
     and Node with real no-mock tests. Non-negotiable, per the parity mandate.
   - **DB engine coverage is INCREMENTAL**: spatial lands **PostGIS-first** in all four
     languages, with the `GeometryField` + QueryBuilder API designed so MySQL, MSSQL and
     SQLite slot in later WITHOUT an API change. Spatial across all six engines on day one is
     not a good trade; a stable API plus honest capability reporting is.
2. **Graceful degradation, never a silent lie.** On an engine without spatial support, a
   spatial predicate raises a clear, actionable error naming the engine and the alternative -
   it never silently returns wrong rows. (Same discipline as the loud-not-silent DB contract.)
3. **Design for moving assets from the start.** The telemetry record carries an OPTIONAL
   location, so static station points and per-sample vehicle GPS tracks both work with no
   redesign. Costs almost nothing now; a retrofit would be expensive.
4. **Telemetry store is PLUGGABLE** (`TINA4_TELEMETRY_BACKEND`: `database` default with
   rollups | `mongodb` | `timescale` | `influx`), following the existing cache/session/queue
   backend pattern. This is what removes the need to guess anyone's message rate - scale
   becomes the operator's configuration choice, not our design gamble.
5. **OCPP ships IN CORE** (owner call - see Architectural position; my separate-package
   recommendation was wrong and inconsistent with WSDL/GraphQL/WebRTC already being core).
   Lazily loaded so non-charging users pay nothing. 1.6J core profile first; 2.0.1 is its own
   epic. **OCPI Locations is in scope early** - it is the geospatial charge-point catalogue,
   so it pairs directly with Phase 1a spatial and is the natural GIS-to-charging bridge.
6. **Zero new runtime dependencies**, as always. PostGIS is server-side; MQTT and Modbus are
   hand-rolled codecs, precedented by the shipped AMQP and Kafka backends.

## Risks / honest notes
- **Parity is a 4x multiplier.** Every framework item ships in Python, PHP, Ruby and Node with
  real no-mock tests. MQTT alone is 4 hand-rolled codecs. Phase discipline is what keeps this
  from becoming a year-long stall.
- **No-mock rule needs real infra first** (Mosquitto + charge-point simulator in CI). If that
  is not stood up in Phase 0, everything after it is untestable by our own standard.
- **Do not put OCPP in core.** See Architectural position. This is the decision most likely to
  be regretted later.
- **MQTT QoS 2** is disproportionate effort for the value; default to QoS 0/1 unless a real
  requirement appears.
- Time-series at volume is where hand-rolled SQL hurts. Prefer the pluggable backend so an
  operator can point at Timescale/Influx without forking the framework.

## Tests (real, no mocks - the standard applies from day one)
- [ ] MQTT: publish/subscribe round-trip against live Mosquitto; reconnect after broker kill;
      retained message + last-will observed by a second real client.
- [ ] Telemetry: real writes + range query + downsample per backend.
- [ ] OCPP: real charge-point simulator completing Boot -> Authorize -> Start -> MeterValues ->
      Stop, asserted against real DB rows.
- [ ] Modbus: real modbus server (container) register read.

## Status: SCOPING - awaiting the 3 decisions.
