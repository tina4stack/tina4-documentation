# OpenAPI and Swagger UI {#config}

::: tip 🔥 Hot Tips
- Use @tags to group endpoints
- Add query parameters using @params
- Add expected request and response structure using @examples
  :::

## Configuration
Swagger is available at the `/swagger` route, even if no routes have been annotated to be included in Swagger. The following
entries would probably have been added to your `.env` file on project initialization. Change these values to suit your project
```
[Open API]
SWAGGER_TITLE=Tina4 Project
SWAGGER_DESCRIPTION=Edit your .env file to change this description
SWAGGER_VERSION=1.0.0
```
## Annotations {#annotations}
The following annotations are used to create the swagger page
| Annotation | Description |
|------------|-------------|
| @summary | Short form description that remains visible even when collapsed |
| @description | Long form description that is only visible when expanded |
| @secure | Secures the route, which forces authentication to use the swagger endpoint |
| @tags | Groups endpoints together. If not used endpoints will be collected into the `default` group |
| @params | Adds query parameters for use |
| @example | Used as default response data |
| @example_request | Used to indicate expected incoming data for POST, PATCH and PUT |
| @example_response | Used to indicate expected response data |

## Usage {#usage}

### @summary and @description
These annotations are simple string inputs. The summary should be a tagline. The description, an explanation giving the user
enough information to decide to use the endpoint.
```php
/**
 * @summary A short form tag line
 * @description A long form explanation of the endpoint
 */
```

### @secure
The use of this is discussed in detail in the [routing section](basic-routing.md#route-security), and this is recommended reading.
For the purposes of swagger, secure routes will need authorization to be able to use them.

### @tags
Endpoints can be grouped into a single level of categories
```php
/**
 * @tags User
 */

/**
 * @tags Product
 */
```
### @params

Path parameters are automatically included in the swagger output like `$id`.
```php
\Tina4\Get::add("/api/user/{id}", function($id, \Tina4\Request $request, \Tina4\Response $response)
```
Query parameters should be included in the `@params` annotation as a comma separated string.
```php
/**
 * @params my-variable,another-variable
 */
```

### @example, @example_response
`@example` is the default response schema, and will be replaced by `@example_response` if supplied. It is good practice 
to use `@example_response` with `@example` used for historical projects.

The schema can be supplied by using an ORM object
```php
/**
 * @example_response User
 */
```
It can also be supplied by a simple array, outlining what fields are expected. 
```php
/**
 * @example_response ["email", "password"]
 */
```
Should the response have been limited from the original ORM, or you actually want show the response values then a JSON response is available
```php
/**
 * @example_response {"email":"get@nowhere.com","name":"John Smith"}
 */
```

### @example_request
For POST, PUT and PATCH endpoints `@example_request` is available, to show what the expected data body should be, to use the endpoint appropriately.
```php
/**
 * @example_request {"email":"get@nowhere.com","name":"John Smith"}
 */
```
The ORM object, array style or json style data formats can be used for `@example_request`