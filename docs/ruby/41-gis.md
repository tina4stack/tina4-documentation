# GIS and PostGIS

Tina4 stores geographic points in PostGIS, queries distance in metres, and returns GeoJSON. Coordinates are always `[longitude, latitude]`.

```ruby
site.location = Tina4::Point.new(18.4241, -33.9249)
site.save

nearby = ChargePoint.query
  .within_distance("location", [18.42, -33.92], 5_000)
  .select_distance("location", [18.42, -33.92])
  .order_by_distance("location", [18.42, -33.92])
  .get

feature = site.to_feature
```

`PointField` maps to `geography(Point,4326)` and creates a GiST index. Unsupported database engines fail clearly. `Tina4::Point.parse` accepts coordinate pairs, WKT/EWKT, GeoJSON, or WKB/EWKB and never guesses coordinate order.
