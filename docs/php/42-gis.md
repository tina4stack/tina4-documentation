# GIS and PostGIS

Tina4 stores geographic points in PostGIS, measures distance in metres, and
returns map-ready GeoJSON. Public coordinates always use longitude first:
`[longitude, latitude]`. GPS may supply coordinates, but GIS is the feature.

## Define a point field

Enable PostGIS first with `CREATE EXTENSION IF NOT EXISTS postgis;`.

```php
use Tina4\ORM;
use Tina4\Point;

class ChargePoint extends ORM
{
    public ?Point $location = null;
    public array $pointFields = [
        'location' => ['srid' => 4326, 'spatialIndex' => true],
    ];
}

$site->location = new Point(18.4241, -33.9249);
$site->save();
```

Tina4 creates `geography(Point,4326)` and an idempotent GiST index. Unsupported
database engines and PostgreSQL without PostGIS fail clearly.

`Point::parse()` accepts a Point, a two-number pair, WKT or EWKT, GeoJSON Point
or Feature, and WKB or EWKB. It rejects invalid ranges, non-finite numbers,
non-point geometry, and conflicting SRIDs before SQL runs. SQL `NULL` remains
`null`; `(0, 0)` remains a real point.

## Query spatial data

```php
$nearby = ChargePoint::query()
    ->withinDistance('location', [18.42, -33.92], 5000)
    ->selectDistance('location', [18.42, -33.92], 'metres')
    ->orderByDistance('location', [18.42, -33.92])
    ->get();
```

| Method | Meaning |
| --- | --- |
| `withinDistance($column, $point, $metres)` | Keep rows inside a non-negative radius. |
| `selectDistance($column, $point, $alias)` | Add distance in metres to each row. |
| `orderByDistance($column, $point, $descending)` | Sort with a stable primary-key tie-break. |
| `intersects($column, $geometry)` | Match bound WKT, EWKT, or GeoJSON geometry. |
| `bbox($column, $minLon, $minLat, $maxLon, $maxLat)` | Match a validated bounding box. |

Spatial values use bound parameters. Column and alias names are validated as
identifiers.

## Return GeoJSON

```php
$feature = $site->toFeature();
$collection = ORM::featureCollection($nearby);
return $response->json($collection);
```

`toFeature()` moves the selected Point into `geometry` and keeps other selected
fields in `properties`. A null point creates `"geometry": null`.
`featureCollection()` preserves query order. Supply a geometry field when a
model has more than one Point field and an include list to limit properties.

Version 3.13.104 persists Point fields only. It does not persist lines,
polygons, rasters, tiles, geocoding results, or routes. `intersects()` may still
accept a polygon as bound query geometry. PostGIS is the only storage provider.
