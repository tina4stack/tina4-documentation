# Implementing CRUD

::: tip 🔥 Hot Tips
- Attach CRUD to any DatabaseResult from queries or ORM models.
- Use `to_crud(request)` to auto-register REST routes and render interactive HTML.
- Assumes lightweight ORM support; define models extending a base for `select()`.
  :::

## Example Usage

Define a route to fetch data and generate CRUD:

```python
from tina4_python import get

@get("/users/dashboard")
async def dashboard(request, response):
    users = User().select("id, name, email")  # ORM query returning DatabaseResult
    return response.render("users/dashboard.twig", {"crud": users.to_crud(request)})
```

Render in Twig template (`users/dashboard.twig`):

```twig
{{ crud }}  {# Outputs full CRUD HTML: table, search, pagination #}
```

## How It Works

- `User().select(...)`: Executes query via ORM, returns DatabaseResult with `.crud` property.
- `to_crud(request)`:
    - Detects table ("users").
    - Registers routes: GET/POST/DELETE under `/users/dashboard/users`.
    - Renders `src/templates/crud/users.twig` with data (auto-copies default if missing).
- Twig: `{{ crud }}` inserts the generated HTML interface.
- AJAX/JSON: Handles `?search=...&limit=...&offset=...` for data refresh.

## Customization

- Pass options: `to_crud(request, {"primary_key": "user_id", "limit": 50})`.
- Edit `crud/users.twig` for table-specific UI tweaks.