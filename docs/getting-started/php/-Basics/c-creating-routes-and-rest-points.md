# Creating Routes and REST points


## Basic GET route

The following is an example of a basic GET end point which returns an array of cars.  The response variable is always required if you want to let Tina4 create the correct response headers.

```php
\Tina4\Get::add("/api/cars", function(\Tina4\Response $response) {
    $cars = ["BMW", "Honda", "Toyota"];

    return $response($cars);
});
```

You could also do the following:

```php
\Tina4\Get::add("/api1/cars", function() {
    $cars = ["BMW", "Honda", "Toyota"];

    echo json_encode($cars);
});
```

Notice that you have to encode the `$cars` variable to get the same result and the headers will probably not be correct.
In order to test these routes or end points, create a file under `src/routes` called `cars.php` and paste the above code in that file:

**cars.php**
```php
<?php
\Tina4\Get::add("/api/cars", function(\Tina4\Response $response) {
    $cars = ["BMW", "Honda", "Toyota"];

    return $response($cars);
});

\Tina4\Get::add("/api1/cars", function() {
    $cars = ["BMW", "Honda", "Toyota"];

    echo json_encode($cars);
});
```
Test both end points by navigating the routes below

- [/api/cars](http://127.0.0.1:7145/api/cars)
- [/api1/cars](http://127.0.0.1:7145/api1/cars)

Notice that the first end point has the correct headers and displays the JSON data correctly in the browser.

## Basic POST route

The following POST route responds with the posted data.  You will need to post a form token to this route to get the response otherwise you will get a 403 forbidden response.

```php
\Tina4\Post::add("/sign-up", function(\Tina4\Response $response, \Tina4\Request $request) {
    
    return $response($request);
});
```

You can use the `sign-up.twig` form in [Html forms and tokens](/getting-started/php/-Basics/b-html-forms-and-tokens/) to test the POST route

## Routes with inline parameters

Routes are very useful if you can pass "data" to them in a request. Inline parameters are described by using `{}` braces.

Consider the following route declaration:

```php
\Tina4\Get::add("/api/members/{id}", function($id, \Tina4\Response $response, \Tina4\Request $request) {
    
    return $response("Looking for member {$id}");
});
```

The `{id}` is the inline param. For example a person calling the end point as `/api/members/10` would result in the `$id` variable being populated with `10`.

!!! tip "Hot Tips"
    - Response objects take three variable inputs, content, response code and content type.
    - Look at advanced topics for dynamic route examples.
