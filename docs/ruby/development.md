# Development Mode

::: tip 🔥 Hot Tips
- Use `--dev` flag for auto-reload on file changes
- SCSS auto-compilation in dev mode
- Debug logging at maximum verbosity
:::

## Starting in Dev Mode

```bash
tina4 start --dev
```

This enables:
- **Auto-reload**: File watcher restarts the server when route files change
- **SCSS compilation**: `.scss` files in `src/scss/` auto-compile to `public/css/`
- **Verbose logging**: Full debug output

## Interactive Console

Launch an IRB console with Tina4 loaded:

```bash
tina4 console
```

```ruby
irb> Tina4::Router.routes.length
=> 5
irb> User.all.count
=> 42
irb> Tina4.database.fetch("SELECT COUNT(*) FROM users")
```

## Route Inspector

List all registered routes:

```bash
tina4 routes
```

```
Registered Routes:
------------------------------------------------------------
  GET      /
  GET      /api/hello
  POST     /api/users [AUTH]
  GET      /api/users/{id:int}
------------------------------------------------------------
Total: 4 routes
```

## Debug Levels

Set in `.env`:

```env
TINA4_DEBUG_LEVEL=ALL      # Everything (default in dev)
TINA4_DEBUG_LEVEL=Info     # Info and above (recommended for production)
TINA4_DEBUG_LEVEL=Error    # Errors only
```
