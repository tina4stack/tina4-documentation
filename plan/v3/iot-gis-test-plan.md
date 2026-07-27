# Test Plan: process / store / retrieve for IoT + GIS data

Companion to `iot-and-ev-charging.md`. Author: maintainer agent, 2026-07-21.

## Principles
- **No mocks, ever.** Real PostGIS container, real Mosquitto broker, real DB writes. A test
  that stands in a fake for the spatial engine or the broker proves nothing - the bugs in this
  domain live in the engine's semantics, not in our call sites.
- **Every test names the bug it can fail for.** A test that cannot articulate its failure mode
  is decoration. Each case below states the bug it catches.
- **Known-answer fixtures, pinned not guessed.** Compute each expected distance ONCE from an
  authoritative source (PostGIS itself, or a reference geodesic calculator), commit the number
  in the fixture file with a comment naming the source, then assert within a tolerance
  (+/- 0.5%). Do NOT hardcode a half-remembered kilometre figure in an assertion.
- **Positive AND negative, and the negative must bite** against the pre-fix/naive
  implementation.

## Fixtures
Four real points, chosen so the classic errors produce dramatic, unmistakable failures:
`CPT` Cape Town (lon 18.4241, lat -33.9249) - `JNB` Johannesburg (lon 28.0473, lat -26.2041)
`DUR` Durban (lon 31.0218, lat -29.8587) - `PLZ` Port Elizabeth (lon 25.6022, lat -33.9608)
Plus edge fixtures: `ANTI_E` (lon 179.9, lat 0), `ANTI_W` (lon -179.9, lat 0),
`POLE_N` (lon 0, lat 89.999), `NULL_ISLAND` (lon 0, lat 0).

---

## A. PROCESS (ingest)

**A1. lat/lon swap is caught, not stored.** THE canonical GIS bug: WKT and GeoJSON are
`(lon, lat)` but humans say "lat, long". Ingest CPT with the pair swapped and assert the stored
point is NOT within 1000 km of the correct CPT. Swapped CPT lands in the Gulf of Guinea, so
this needs no precision to be decisive.
*Catches:* the single most common spatial defect in existence.

**A2. Out-of-range coordinates fail loud.** lat 91, lat -91, lon 181, NaN, Infinity -> clear
error naming the offending value. Must NOT store and must NOT silently clamp.
*Catches:* garbage-in-garbage-stored, and clamping that hides a unit bug.

**A3. Malformed WKT / GeoJSON is rejected, not coerced.** `POINT(18.4241)`, `POINT()`,
`{"type":"Polygon"...}` into a PointField, `"18.4241,-33.9249"` (a bare CSV string).
*Catches:* silent partial parses that store a wrong-but-valid point.

**A4. Coordinate values cannot inject SQL.** Feed `POINT(0 0)'); DROP TABLE devices;--` and a
tuple whose members are SQL fragments. Assert the table still exists and the value was
parameterised.
*Catches:* WKT is a string; naive builders interpolate it. Hard security requirement.

**A5. Duplicate delivery is idempotent.** MQTT QoS 1 is at-least-once. Publish the SAME
(device_id, device_timestamp, payload) twice; assert exactly ONE stored sample.
*Catches:* double-counted energy/mileage - the bug that makes billing wrong.

**A6. Late/out-of-order samples do not corrupt latest-state.** Ingest sample at T+10, then a
buffered sample at T+5. Assert the history holds both AND that "latest reading" still reports
the T+10 value.
*Catches:* offline devices dumping their buffer and rewriting current state backwards.

**A7. Device clock skew is preserved, not trusted.** Store BOTH `device_time` and
`received_at`. Ingest a sample whose device clock is 3 days off; assert both timestamps are
retained and queries can use either.
*Catches:* using a lying device clock as the only time axis - unrecoverable once stored.

**A8. Everything is UTC.** Ingest with `+02:00` offset, naive, and `Z`; assert all three
normalise to the same UTC instant.
*Catches:* naive-datetime drift, the bug that appears twice a year.

**A9. Payload shape drift does not crash ingest.** Device firmware adds an unknown field,
sends a string where a number was, omits an optional field. Assert ingest survives and
records the anomaly rather than 500-ing the whole batch.
*Catches:* one bad device taking down the fleet's ingest path.

**A10. Monotonic counter regression is flagged.** Energy meters only increase. Feed
1000 kWh then 5 kWh. Assert this is detected as a rollover/meter-swap, NOT stored as
negative consumption.
*Catches:* negative energy on a bill.

**A11. Implausible movement is flagged.** Two GPS points 500 km apart 10 seconds apart
(1.8e5 km/h). Assert flagged as jitter/spoof, not silently accepted as distance travelled.
*Catches:* phantom mileage from GPS glitches.

---

## B. STORE

**B1. Round-trip fidelity at full precision.** Store 7-decimal coordinates via tuple, WKT, and
GeoJSON; reload; assert lon/lat identical to the input (within double precision).
*Catches:* float truncation, and a text round-trip that loses digits.

**B2. Spatial column and index actually exist.** After `create_table()`, introspect the real
schema: assert the column type is `geography(Point,4326)` on PostGIS AND that a GiST index
exists on it.
*Catches:* a migration that creates the column but silently skips the index - works in dev,
dies at scale.

**B3. Unsupported engine fails loud.** Same model against SQLite: assert a clear error naming
the engine and the alternative. Never a silently-created TEXT column.
*Catches:* the framework quietly degrading to a fake spatial column.

**B4. SRID is stored and enforced.** Store with SRID 4326; assert a mismatched-SRID insert is
rejected rather than silently reprojected.
*Catches:* mixed-SRID tables, where every later distance is wrong.

**B5. NULL geometry is distinct from (0,0).** A device with no fix yet must store NULL, and a
radius query must not treat it as Null Island.
*Catches:* the classic "all my no-fix devices are in the Gulf of Guinea" bug.

**B6. Burst write integrity.** Push 10,000 samples through the real ingest path; assert count,
no duplicates, no lost rows, and the transaction boundary behaved.
*Catches:* backpressure losing data silently.

**B7. Telemetry rollups preserve the right aggregate per metric type.** Downsample a counter
(energy) and a gauge (temperature) over the same window. Assert counter rolls up as
delta/last, gauge as min/avg/max. Averaging a counter is WRONG.
*Catches:* rollups that quietly destroy billing data.

**B8. Backend parity.** Run the identical store/retrieve contract against every configured
telemetry backend (`database`, `mongodb`, and any TSDB). Assert identical results.
*Catches:* a backend that passes its own tests but disagrees with the others.

---

## C. RETRIEVE (query)

**C1. Radius returns metres, not degrees.** THE killer. `within_distance(CPT, 500_000)` must
include PLZ and exclude JNB/DUR. On `geometry` instead of `geography`, ST_Distance returns
DEGREES and this silently over/under-selects by a factor of ~111,000.
*Catches:* the highest-impact spatial bug after lat/lon swap.

**C2. Circle, not bounding box.** Place a point just inside the radius' bbox CORNER but outside
the circle. Assert it is EXCLUDED.
*Catches:* a "radius" implemented as a cheap bbox - passes naive tests, wrong in production.

**C3. Distance ordering is correct and deterministic.** `order_by_distance(CPT)` over
CPT/PLZ/JNB/DUR returns the pinned expected order; equidistant points break ties on a stable
secondary key so pagination cannot loop or skip.
*Catches:* non-deterministic ordering, which quietly breaks paging.

**C4. Antimeridian is not the long way round.** `ANTI_E` to `ANTI_W` is ~22 km, not ~40,000 km.
*Catches:* naive planar maths; a real bug for anyone operating across the Pacific.

**C5. Polar points do not blow up.** Distance and radius near lat 89.999 return finite,
sensible values.
*Catches:* divide-by-zero / projection blowup at the poles.

**C6. Empty result is empty, not everything.** A radius of 0, and a radius around a point with
nothing near it, return zero rows - not the whole table (the classic "missing WHERE" failure).
*Catches:* a predicate that silently no-ops.

**C7. The spatial index is actually used.** Run EXPLAIN on the radius query against a table
with enough rows and assert an index scan on the GiST index, not a sequential scan.
*Catches:* a predicate written so the planner cannot use the index - correct results, terrible
performance, invisible to every functional test.

**C8. GeoJSON output is valid and correctly ordered.** Assert `coordinates` is `[lon, lat]`
(GeoJSON order), the structure is a valid Feature/FeatureCollection, and it round-trips back
through ingest to the same point.
*Catches:* emitting `[lat, lon]`, which silently breaks every map client.

**C9. Time-range retrieval is inclusive/exclusive as documented.** Query a window whose bounds
land exactly on stored sample timestamps; assert the boundary samples appear per the documented
contract.
*Catches:* off-by-one at window edges - double-counted or missing samples at rollup joins.

---

## D. COMBINED IoT + GIS

**D1. Geofence enter/exit fires exactly once each.** Feed a track that crosses a polygon
boundary. Assert exactly one enter and one exit event, and that a point ON the boundary
resolves per the documented inclusive/exclusive rule.
*Catches:* boundary flapping - dozens of spurious events per crossing.

**D2. Stationary drift accumulates no mileage.** A parked vehicle jittering +/- 5 m for an hour
must report ~0 distance travelled, not kilometres.
*Catches:* phantom trip distance, which corrupts fleet reporting and billing.

**D3. Nearest-charger-to-moving-vehicle is time-correct.** Assert the query resolves against
the vehicle's position AT the requested instant, not its latest position.
*Catches:* silently using latest-state for a historical question.

**D4. Charge session ties to a location.** A completed session (start -> meter values -> stop)
resolves to the right site geometry, and its kWh maps to a Carbonah gCO2e figure.
*Catches:* orphaned sessions and the energy-to-carbon unit slip (Wh vs kWh).

---

## E. Non-functional gates
- **E1.** Reconnect: kill the real broker mid-publish; assert QoS 1 messages are not lost.
- **E2.** Retained message + last-will observed by a second REAL subscriber after a device dies.
- **E3.** Carbon/perf: ingest+query path measured under Carbonah so this subsystem does not
  quietly regress the A+ rating.

---

## The discriminating five
If only five of these ever get written, write these - they catch the bugs that actually ship:
1. **C1** metres-not-degrees (radius off by ~111,000x)
2. **A1** lat/lon swap
3. **C2** circle-not-bbox
4. **A5** duplicate delivery idempotency (double-billed energy)
5. **C7** spatial index actually used (the invisible one)
