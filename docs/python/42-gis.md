# GIS and PostGIS

Tina4's GIS support stores geographic points in PostGIS, queries distance in metres, and serializes map-ready GeoJSON. Coordinates are always `(longitude, latitude)`.

## Define a point field

```python
from tina4_python.orm import ORM, IntegerField, StringField, PointField, Point, feature_collection

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

`PointField()` creates a `geography(Point,4326)` column and a GiST index. Tina4 fails clearly on an unsupported database instead of pretending a text column is spatial.

## Query by distance

```python
nearby = (
    ChargePoint.query()
    .within_distance("location", (18.42, -33.92), 5_000)
    .select_distance("location", (18.42, -33.92))
    .order_by_distance("location", (18.42, -33.92))
    .get()
)
```

Radius and returned distance are metres. Spatial values remain parameters; column and alias names are validated identifiers.

## Return GeoJSON

```python
feature = site.to_feature()
collection = feature_collection([site])
```

A `Point` also exposes `.wkt`, `.ewkt`, `.geojson`, `.lon`, `.lat`, and `.srid`. `Point.parse()` accepts a coordinate pair, WKT/EWKT, GeoJSON, or WKB/EWKB without guessing coordinate order.
