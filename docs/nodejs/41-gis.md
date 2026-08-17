# GIS and PostGIS

Tina4 stores geographic points in PostGIS, queries distance in metres, and returns GeoJSON. Coordinates are always `[longitude, latitude]`.

```typescript
import { Point } from "tina4-nodejs/orm";

site.location = new Point(18.4241, -33.9249);
await site.save();

const nearby = await ChargePoint.query()
  .withinDistance("location", [18.42, -33.92], 5_000)
  .selectDistance("location", [18.42, -33.92])
  .orderByDistance("location", [18.42, -33.92])
  .get();

const feature = site.toFeature();
```

Declare the model field as `location: { type: "point", srid: 4326,
spatialIndex: true }`. Tina4 maps it to `geography(Point,4326)` and creates a
GiST index. Unsupported database engines fail clearly. `Point.parse()` accepts
coordinate pairs, WKT/EWKT, GeoJSON, or WKB/EWKB and never guesses coordinate
order.
