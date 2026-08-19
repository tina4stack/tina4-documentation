# GIS and PostGIS

Tina4 stores geographic points in PostGIS, measures distance in metres, and
returns map-ready GeoJSON. Coordinates always use longitude first. GPS may
supply coordinates, but GIS is the feature.

## Define a point field

Enable PostGIS with `CREATE EXTENSION IF NOT EXISTS postgis;`.

```ruby
class ChargePoint < Tina4::ORM
  point_field :location
end

site.location = Tina4::Point.new(18.4241, -33.9249)
site.save
```

Tina4 creates `geography(Point,4326)` and an idempotent GiST index. Unsupported
database engines and PostgreSQL without PostGIS fail clearly.
`Tina4::Point.parse` accepts a Point, number pair, WKT or EWKT, GeoJSON Point or
Feature, and WKB or EWKB. It rejects invalid ranges, non-finite numbers,
non-point geometry, and conflicting SRIDs before SQL runs.

## Query and return GeoJSON

```ruby
nearby = ChargePoint.query
  .within_distance("location", [18.42, -33.92], 5_000)
  .select_distance("location", [18.42, -33.92], alias_name: "metres")
  .order_by_distance("location", [18.42, -33.92])
  .get

feature = site.to_feature
collection = Tina4::ORM.feature_collection(nearby)
```

The query builder also provides `intersects` for bound WKT, EWKT, or GeoJSON
geometry and `bbox` for a validated bounding box. Spatial values use bound
parameters. Column and alias names are validated as identifiers.

`to_feature` moves the chosen Point into `geometry` and keeps other selected
fields in `properties`. A null point creates `"geometry": null`.
`feature_collection` preserves query order. Supply a geometry field for models
with several Point fields and an include list to limit properties.

Version 3.13.104 persists Point fields only. It does not persist lines,
polygons, rasters, tiles, geocoding results, or routes. `intersects` may accept a
polygon as query geometry. PostGIS is the only storage provider.
