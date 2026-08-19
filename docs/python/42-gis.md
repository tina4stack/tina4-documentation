# GIS and PostGIS

Tina4 stores geographic points in PostGIS, measures distance in metres, and
returns map-ready GeoJSON. Public coordinates always use longitude first:
`(longitude, latitude)`.

GIS describes the spatial model and queries. GPS may supply coordinates, but it
does not define this feature.

## Prepare PostGIS

The first GIS provider is PostgreSQL with PostGIS:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

Point fields fail with a clear error on SQLite, MySQL, SQL Server, Firebird, or
PostgreSQL without PostGIS. Tina4 does not replace a spatial query with an
approximation over two numeric columns.

## Define a point field

```python
from tina4_python.orm import ORM, IntegerField, StringField, PointField, Point

class ChargePoint(ORM):
    id = IntegerField(primary_key=True, auto_increment=True)
    name = StringField()
    location = PointField()

site = ChargePoint({
    "name": "V&A Waterfront",
    "location": Point(18.4241, -33.9249),
})
site.save()
```

`PointField()` creates `geography(Point,4326)` and an idempotent GiST index.
Set `spatial_index=False` only when another migration owns the index.

## Point values

`Point.parse()` accepts a `Point`, a two-number pair, WKT or EWKT, GeoJSON Point
or Feature, and WKB or EWKB. It rejects booleans, NaN, infinity, invalid ranges,
non-point geometry, and conflicting SRIDs before SQL runs.

```python
Point.parse([18.4241, -33.9249])
Point.parse("POINT(18.4241 -33.9249)")
Point.parse("SRID=4326;POINT(18.4241 -33.9249)")
Point.parse({"type": "Point", "coordinates": [18.4241, -33.9249]})
```

| Property | Value |
| --- | --- |
| `.lon`, `.lat`, `.srid` | Validated point coordinates and reference id. |
| `.wkt` | `POINT(lon lat)` |
| `.ewkt` | `SRID=4326;POINT(lon lat)` |
| `.geojson` | RFC 7946 Point geometry. |
| `.to_tuple()` | `(longitude, latitude)` |

SQL `NULL` remains `None`. `(0, 0)` remains a real point.

## Query by distance

```python
nearby = (
    ChargePoint.query()
    .within_distance("location", (18.42, -33.92), 5_000)
    .select_distance("location", (18.42, -33.92), alias="metres")
    .order_by_distance("location", (18.42, -33.92))
    .get()
)
```

| Query method | Meaning |
| --- | --- |
| `within_distance(column, point, metres)` | Keep rows within the non-negative spheroid radius. |
| `select_distance(column, point, alias="metres")` | Add the distance in metres to each row. |
| `order_by_distance(column, point, descending=False)` | Sort by distance with a stable primary-key tie-break. |
| `intersects(column, geometry)` | Match a bound WKT, EWKT, or GeoJSON query geometry. |
| `bbox(column, min_lon, min_lat, max_lon, max_lat)` | Match a validated bounding box. |

Spatial values use bound parameters. Tina4 validates column and alias names as
identifiers. A bounding box rejects inverted or out-of-range coordinates.

## Return GeoJSON

```python
from tina4_python.orm import feature_collection

feature = site.to_feature()
collection = feature_collection(nearby)
return response.json(collection)
```

`to_feature()` moves the chosen Point field into `geometry` and keeps the other
selected fields in `properties`. A null point produces `"geometry": null`, not
coordinates at Null Island. `feature_collection()` preserves query order.

Pass `geometry_field` when a model has more than one Point field. Pass `include`
to select the properties that leave the application.

## Limits in 3.13.104

Tina4 persists Point fields only. It does not persist lines, polygons, rasters,
tiles, geocoding results, or routes. `intersects()` may still accept a polygon as
bound query geometry. PostGIS is the only supported storage provider in this
release.
