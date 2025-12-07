# Swagger Annotations

Tina4 Python integrates Swagger for OpenAPI 3.0.3 compliant API documentation. The `/swagger` endpoint serves an interactive UI, and `/swagger.json` provides the JSON spec. Annotations via decorators add metadata to routes for enhanced docs.

### Configuration

Set environment variables for OpenAPI info:

- `SWAGGER_TITLE` (default: "Tina4 Python API")
- `SWAGGER_DESCRIPTION` (default: "Auto-generated API documentation")
- `SWAGGER_VERSION` (default: "1.0.0")
- `SWAGGER_CONTACT_TEAM` (default: "Tina4 Team")
- `SWAGGER_CONTACT_URL` (default: "https://tina4.com")
- `SWAGGER_CONTACT_EMAIL` (default: "support@tina4.com")
- `HOST_NAME` (default: "localhost:8000")
- `BASE_URL` (default: "")

Servers include current host and local dev. Security schemes: Bearer (JWT) and Basic for secure routes.

### Import and Usage

Import decorators directly for cleaner usage without prefix:

```python
from tina4_python import get  # Example router import
from tina4_python import description, summary, secure, tags, example, example_response, params, describe
```

Apply above routes:

```python
@get("/example")
@description("Example route")
async def example_route(request):
    return {"message": "Hello"}
```

Path params auto-detected; request bodies for POST/PUT/PATCH if examples given.

### Decorators

- **`@description(text: str)`**: Operation description.
- **`@summary(text: str)`**: Short summary.
- **`@secure()`**: Adds auth (Bearer JWT, Basic; 401 response).
- **`@tags(tags: list[str] | str)`**: Grouping tags.
- **`@example(example_data: Any)`**: Request example (POST/PUT/PATCH).
- **`@example_response(example_data: Any)`**: 200 response example.
- **`@params(params_list: list[str] | dict[str, str])`**: Query params (e.g., `["page=1"]` or `{"limit": "10"}`).
- **`@describe(...)`**: Multi-annotation (args: `description`, `summary`, `tags`, `params`, `example`, `example_response`, `secure: bool`).

Routes without annotations skipped. Responses: 200 (with example), 400, 404; 401 if secure. Operation IDs auto-generated (e.g., `get_users` for GET `/users`). See `swagger.py` for generation details.

::: tip 🔥 Hot Tips 
- You can change the Swagger endpoint by setting the environment variable `SWAGGER_ROUTE` eg. `/my-swagger`
  :::