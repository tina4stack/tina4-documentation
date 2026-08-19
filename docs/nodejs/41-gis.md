# GIS and PostGIS

Tina4 stores geographic points in PostGIS, measures distance in metres, and
returns map-ready GeoJSON. Coordinates always use longitude first. GPS may
supply coordinates, but GIS is the feature.

## Define a point field

Enable PostGIS with `CREATE EXTENSION IF NOT EXISTS postgis;`.

```typescript
import { BaseModel, Point } from "tina4-nodejs/orm";

class ChargePoint extends BaseModel {
  static tableName = "charge_point";
  static fields = {
    location: { type: "point", srid: 4326, spatialIndex: true },
  };
}

site.location = new Point(18.4241, -33.9249);
await site.save();
```

Tina4 creates `geography(Point,4326)` and an idempotent GiST index. Unsupported
database engines and PostgreSQL without PostGIS fail clearly. `Point.parse()`
accepts a Point, number pair, WKT or EWKT, GeoJSON Point or Feature, and WKB or
EWKB. It rejects invalid ranges, non-finite numbers, non-point geometry, and
conflicting SRIDs before SQL runs.

## Query and return GeoJSON

```typescript
const nearby = await ChargePoint.query()
  .withinDistance("location", [18.42, -33.92], 5_000)
  .selectDistance("location", [18.42, -33.92], "metres")
  .orderByDistance("location", [18.42, -33.92])
  .get();

const feature = site.toFeature();
const collection = BaseModel.featureCollection(nearby);
```

The query builder also provides `intersects()` for bound WKT, EWKT, or GeoJSON
geometry and `bbox()` for a validated bounding box. Spatial values use bound
parameters. Column and alias names are validated as identifiers.

`toFeature()` moves the chosen Point into `geometry` and keeps other selected
fields in `properties`. A null point creates `"geometry": null`.
`featureCollection()` preserves query order. Supply a geometry field for models
with several Point fields and an include list to limit properties.

Version 3.13.104 persists Point fields only. It does not persist lines,
polygons, rasters, tiles, geocoding results, or routes. `intersects()` may accept
a polygon as query geometry. PostGIS is the only storage provider.
