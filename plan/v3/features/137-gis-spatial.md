# Feature 137: GIS spatial points and queries

**Outcome:** Declare a location once, store it in PostGIS, query it in metres, and return
GeoJSON through the same application shape in Python, PHP, Ruby and Node.js.

## Identity and status

- Matrix identity: 137 - GIS spatial points and queries
- Audit state: accepted; implementation verified for 3.13.104
- Dependencies: Features 3-7 (database and query builder), 15 (migrations), 17-18
  (ORM and fields), 30 (response types)
- Dependants: IoT telemetry, asset tracking, station lookup, mapping and future OCPP/OCPI
- Decisions: ADR-0004, ADR-0008, ADR-0044, ADR-0057
- Shared fixture: `gis_contract.json`
- Release line: `feature/release3.13.104` -> `v3`

## Why this feature exists

A location is not two ordinary numbers. Its coordinate order, reference system, distance
unit, index and null behavior all carry meaning. An application that gets one rule wrong
can return a convincing but false result: the wrong city, the long route around the
antimeridian, or every unknown location plotted at Null Island.

Tina4 must own those rules once. Developers should declare a point, ask for nearby rows,
and send valid GeoJSON. They should not write PostGIS functions in every route.

## Boundary

Feature 137 owns the Point value, PointField, PostGIS field/index DDL, query-builder
spatial predicates, distance expressions, hydration and GeoJSON serialization.

It does not own maps, tiles, address lookup, routing, telemetry storage, geofence events,
coordinate reprojection, raster data or persisted line/polygon fields. MQTT remains
Feature 94. GPS describes a source of coordinates, not this feature.

## Existing evidence

The implementation is on the 3.13.104 release branch in all four frameworks. Each
baseline runner loads the byte-identical fixture and exercises its native Point, ORM,
SQL translator and QueryBuilder against the same real PostGIS 16 / PostGIS 3.4 service.
The twelve adversarial invariant groups remain owed until every named case and mutation
witness is wired in all four runners.

## Public contract

### Point value

- Default SRID: 4326.
- Coordinate order: longitude, then latitude.
- Longitude range: -180 through 180. Latitude range: -90 through 90.
- Reject booleans, non-numbers, NaN, infinity, malformed WKT/WKB/GeoJSON and SRID
  conflicts.
- Preserve at least seven decimal places through write and hydration.
- Native absence remains SQL NULL. `(0, 0)` remains a real point.

Accepted forms:

```text
Point(lon, lat)
[lon, lat]
POINT(lon lat)
SRID=4326;POINT(lon lat)
{"type":"Point","coordinates":[lon,lat]}
WKB or EWKB bytes/hex
```

### Storage and DDL

- PostGIS field: `geography(Point, <srid>)`.
- Default index: idempotent GiST index; `spatial_index=false` disables only the index.
- A missing PostGIS extension or unsupported engine raises an actionable error.
- Identifiers are validated; values stay bound.

### Query builder

- `within_distance(column, point, metres)` includes rows whose spheroid distance is at
  most the non-negative radius.
- `select_distance(column, point, alias)` adds a bound distance expression in metres.
- `order_by_distance(column, point, descending=false, tie_break=...)` orders by distance
  and then a stable key.
- `intersects(column, geometry)` accepts bound WKT/EWKT or GeoJSON query geometry.
- `bbox(column, min_lon, min_lat, max_lon, max_lat)` rejects inverted/out-of-range boxes.
- `count()` drops select-only expressions and their parameters.

### Serialization

- A Point field serializes as RFC 7946 GeoJSON geometry.
- A model can produce `Feature`; the point leaves the properties object.
- A collection produces `FeatureCollection` and preserves query order.
- A null point produces a Feature with `geometry: null`, never coordinates `[0, 0]`.

## Failure and security contract

- Every malformed coordinate fails before database execution.
- Every query value is a bound parameter.
- A mismatched SRID fails; Tina4 does not reproject behind the caller's back.
- Unsupported engines fail loudly; no degree-based distance approximation is allowed.
- Distance order is deterministic when distances tie.
- Errors may name the engine, field and expected input. They must not include database
  credentials.

## Unified fixture

`fixtures/gis_contract.json` is the only answer key. Each runner must read that exact
file and execute its cases against real PostGIS. Copying fixture values into native test
files does not count.

The fixture specifies the proof still required for:

1. accepted point forms and precision;
2. invalid coordinate rejection;
3. nullable points and Null Island separation;
4. PostGIS DDL and GiST index;
5. known radius results in metres;
6. circular radius behavior rather than bounding-box behavior;
7. antimeridian and polar distance behavior;
8. stable tied-distance order;
9. SRID enforcement;
10. bound intersection and bounding boxes;
11. Feature and FeatureCollection output;
12. loud unsupported-engine failure.

Each runner also carries a negative control that changes longitude/latitude order and
must make the suite fail. Targeted mutations must remove the range guard, parameter
binding, SRID check, GiST index, distance tie-break and unsupported-engine error one at a
time. Every mutation must turn its named witness red.

## Integration map

- Export Point and PointField through the normal ORM/framework entry point.
- Extend the existing SQL translation layer; do not place engine SQL in route or model
  code.
- Extend the existing QueryBuilder; do not introduce a parallel spatial builder.
- Extend normal ORM hydration and serialization; do not require a special repository.
- Keep the feature lazy: applications without a PointField pay no database or startup
  cost.
- Add commented GIS/PostGIS setup to project examples, the four books and skills.

## Breaking changes and migration

The feature is additive. PHP's existing `SqlTranslation` name is not renamed as part of
GIS; public naming cleanup is a separate breaking decision. The GIS implementation uses
the existing translation hook in each language.

Existing applications with `latitude` and `longitude` columns need an explicit migration
that creates the Point field and populates it with longitude first. Tina4 will not infer
or swap those columns.

## Implementation plan

### Scope

- [x] Establish PostGIS-first Point boundary.
- [x] Accept ADR-0057 and allocate Feature 137.
- [x] Define the unified fixture data and invariant groups.
- [x] Replay the proven Python design onto current 3.13.104.
- [x] Write fixture runners in all four frameworks.
- [x] Port the implementation to PHP, Ruby and Node.js.
- [x] Run targeted GIS suites against real PostGIS on the lab as root.
- [ ] Mutation-prove the six security/correctness witnesses.
- [ ] Run all four full framework suites at release HEAD.
- [x] Publish four GIS chapters.
- [ ] Update the four framework skills with GIS scaffolding guidance.
- [ ] Move fixture groups from owed to proven after every named witness passes.
- [x] Sync the honest owed state into CONTRACT-MAP.

### Parity

| Capability | Python | PHP | Ruby | Node.js |
| --- | --- | --- | --- | --- |
| Point/PointField | ✅ | ✅ | ✅ | ✅ |
| PostGIS DDL/index | ✅ | ✅ | ✅ | ✅ |
| Spatial queries | ✅ | ✅ | ✅ | ✅ |
| GeoJSON | ✅ | ✅ | ✅ | ✅ |
| Baseline shared-fixture runner | ✅ | ✅ | ✅ | ✅ |
| Real PostGIS proof | ✅ | ✅ | ✅ | ✅ |
| Full adversarial fixture | owed | owed | owed | owed |

### Tests: real PostGIS, positive and negative, no mocks

- [x] All runners load `gis_contract.json` at runtime.
- [ ] Every proposed fixture case runs against PostGIS 16 with the PostGIS extension enabled.
- [x] SQLite proves the unsupported-engine error only.
- [x] The lab gate records the PostGIS connection and version.
- [ ] No skipped GIS case may pass the final release gate.

### Bugs

- [ ] Record reproduced defects here and close each with a four-language regression.

### Commits

- (none)

## Porting capsule

Implement an immutable Point value with SRID 4326 and longitude-first validation. Add a
PointField that writes EWKT through a bound parameter, hydrates WKB/EWKB without a spatial
SELECT wrapper, and serializes GeoJSON. Add PostGIS geography DDL and an idempotent GiST
index through the existing SQL translator. Add bound radius, distance, intersection and
bbox expressions to the existing QueryBuilder. Stable distance ordering uses the model
primary key as a secondary key. Add Feature and ordered FeatureCollection serialization.
Fail before SQL for invalid coordinates and fail loudly on unsupported engines. Then run
the shared fixture against real PostGIS. The fixture, not this paragraph, is the oracle.

## Status: Accepted for 3.13.104
