# JSON Adapter

::: tip
TTina4JSONAdapter populates a `TFDMemTable` from static JSON data or automatically from a TTina4RESTRequest master source.
:::

## From Static JSON {#static}

```pascal
// Design-time: set MemTable, DataKey, JSONData in Object Inspector
// Runtime:
Tina4JSONAdapter1.MemTable := FDMemTable1;
Tina4JSONAdapter1.DataKey := 'products';
Tina4JSONAdapter1.JSONData.Text := '{"products": [{"id": "1", "name": "Widget"}, {"id": "2", "name": "Gadget"}]}';
Tina4JSONAdapter1.Execute;
```

## From MasterSource {#master-source}

When linked to a `TTina4RESTRequest`, the adapter auto-executes whenever the master's `OnExecuteDone` fires.

```pascal
Tina4JSONAdapter1.MasterSource := Tina4RESTRequest1;
Tina4JSONAdapter1.DataKey := 'categories';
Tina4JSONAdapter1.MemTable := FDMemTableCategories;
// Automatically populates when Tina4RESTRequest1 completes
```

## Sync Mode {#sync-mode}

```pascal
Tina4JSONAdapter1.SyncMode := TTina4RestSyncMode.Sync;
Tina4JSONAdapter1.IndexFieldNames := 'id';
// Existing records matched by 'id' are updated; new ones are inserted
```

| Sync Mode | Behavior |
|---|---|
| `Clear` (default) | Empties the table first, then appends all records |
| `Sync` | Matches records by `IndexFieldNames` and updates existing rows or inserts new ones |
