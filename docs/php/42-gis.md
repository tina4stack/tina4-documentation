# GIS and PostGIS

Tina4 stores geographic points in PostGIS, queries distance in metres, and returns map-ready GeoJSON. Coordinates are always `[longitude, latitude]`.

```php
use Tina4\Point;
$site->location = new Point(18.4241, -33.9249);
$site->save();

$nearby = ChargePoint::query()
    ->withinDistance('location', [18.42, -33.92], 5000)
    ->selectDistance('location', [18.42, -33.92])
    ->orderByDistance('location', [18.42, -33.92])
    ->get();

$feature = $site->toFeature();
```

Declare the model field with `public ?Point $location = null` and add
`'location' => ['srid' => 4326, 'spatialIndex' => true]` to the model's
`$pointFields` map. Tina4 then creates `geography(Point,4326)` and a GiST index.
Unsupported database engines fail clearly. `Point::parse()` accepts coordinate
pairs, WKT/EWKT, GeoJSON, or WKB/EWKB; `geoJson()` returns the standard geometry.
