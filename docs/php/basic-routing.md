# Routing

::: tip 🔥 Hot Tips
- Incoming data is automatically added to the `request` variable
- Path parameters are **auto-injected** in the exact order they appear in the URL
- Save files in a `routes/` folder  → **auto-discovered**, zero config needed
- Care must be taken with dynamic route naming to ensure they do not clash with other routes 
  :::

## Basic Routing {#basic-routing}
Routes are easily declared, available in GET, POST, PUT, PATCH, DELETE and even ANY.
```php
\Tina4\Get::add("/", function (\Tina4\Response $response) {
    
    return $response("<h1>Hello Tina4 PHP</h1>");
});
```
Incoming data is found in the `$request` variable which must be declared in the function declaration.
```php
\Tina4\Get::add("/", function (\Tina4\Response $response, \Tina4\Request $request) {
    // query parameters are found in two places
    $queryParameter = $request->params["incomingData"]
    $queryParameter = $request->data->incomingData
    // The request body is only found in one place
    $requestBody = $request->data->jsonBody
    
    return $response("<h1>Hello Tina4 PHP</h1>");
});

```
## Dynamic Routing {#dynamic-routing}  
Path parameters can be included to provide dynamic routing, included in the order they are listed in the path.
```php
\Tina4\Get::add("/api/catalog/{categoryId}/{productId"}, 
    function ($categoryId, $productId, \Tina4\Response $response) {
    
    return $response("<h1>This is a dynamic route</h1>");
});
```
## Route Response Options {#response-options}
There are generally four response options. It is always good practice to specify both the return code and the return type.
```php
// simple strings
return $response("You can pass a string <b>even with</b> html markup", HTTP_OK, TEXT_HTML);
return $response("The string could be an error message", HTTP_BAD_REQUEST, TEXT_HTML);

// json data packets
return $response($jsonResponse, HTTP_OK, APPLICATION_JSON);

// template rendering placed in the src/template folder
return $response("my-twig-file.twig", HTTP_OK, TEXT_HTML);

// redirects are useful for posts to stop refresh button reposts
return \Tina4\redirect("/welcome");
```
## Route Security
All POST routes require the need to pass security by default. Security can be added to other routes using the `@secure` annotation.
```php
/**
 * This is a secure get route
 * @secure
 */
\Tina4\Get::add("/", function (\Tina4\Response $response) {
    
    return $response("<h1>Hello Tina4 PHP</h1>");
});
```
The security can be extended by adding constants after the annotation, which is then saved in the request object. This can be used to selectively protect a route.
```php
/**
 * This is a secure get route
 * @secure TINA4
 */
\Tina4\Get::add("/", function (\Tina4\Response $response, \Tina4\Request $request) {
    // $secureType will have a value of TINA4
    $secureType = $request->security;
    
    return $response("<h1>Hello Tina4 PHP</h1>");
});
```
## Further reading
The section on [Posting Data](posting-form-data.md) from forms might be useful for certain routes.

[Middleware](middleware.md) can be added to routes to improve functionality, especially around security.

By adding annotations one can create a fully functional [Swagger UI](swagger.md) to document your api.
