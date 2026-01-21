# Middleware
::: tip 🔥 Hot Tips
- Middleware runs before the route is activated
- Middleware can be stacked on a route
- Middleware, both single and stacked will work on dynamic routes.
- Variables do not persist between Middleware, except for the `$request` variable.
  :::
## Basic Middleware {#declare}
Declaration of Middleware, looks very much like the routes that they interact with.
```php
// This middleware adds a parameter "test" to the incoming request variable
\Tina4\Middleware::add("MyMiddleware", function (\Tina4\Request $request) {

    $request->params["test"] =  "This is the middleware";

});
```
## Linking to Routes {#routes}
Linking the middleware to the routes can be done in two ways
Firstly as a chained static function of the Route object
```php
\Tina4\Get::add("/another-route", function (\Tina4\Response $response, \Tina4\Request $request) {

    $data = "This is another route. " . $request->params["test"];

    return $response($data);
})::middleware(["MyMiddleware"]);
```
Or as a php docs annotation
```php
/**
 * @middleware MyMiddleware
 */
\Tina4\Get::add("/another-route", function (\Tina4\Response $response, \Tina4\Request $request) {

    $data = "This is another route. " . $request->params["test"];

    return $response($data);
});
```
## Middleware chaining {#chaining}
Middleware can be chained with them being run in order as listed
```php
\Tina4\Get::add("/another-route", function (\Tina4\Response $response, \Tina4\Request $request) {

    $data = "This is another route. " . $request->params["test"] . ". " . $request->params["anotherTest"];

    return $response($data);
})::middleware(["MyMiddleware", "AnotherMiddleware"]);

/**
 * @middleware MyMiddleware, AnotherMiddleware
 */
\Tina4\Get::add("/this-route", function (\Tina4\Response $response, \Tina4\Request $request) {

    $data = "This is another route. " . $request->params["test"];

    return $response($data);
});
```
## Middleware with Dynamic Routes {#dynamic}
Dynamic route variables can be passed to middleware provided they are declared in the middleware. The same is true for chained middleware functions.
```php
\Tina4\Middleware::add("AnotherMiddleware", function ($id, \Tina4\Request $request) {

    $request->params["test"] =  "$id";

});

\Tina4\Get::add("/variable-route/{id}", function ($id, \Tina4\Response $response, \Tina4\Request $request) {

    $data = "This is the passed variable. " . $request->params["test"];

    return $response($data);
})::middleware(["AnotherMiddleware"]);
```
However these values are passed by value and not by reference, so any changes to the dynamic route variables will not be saved outside the function. If you need to persist variables, then add them to the `$request` variable which does persist.