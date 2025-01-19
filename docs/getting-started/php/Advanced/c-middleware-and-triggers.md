# Middleware and Triggers

Middleware routines can be used to modify the input from the web server.

```php title="src/routes/example.php"

\Tina4\Middleware::add("hello", function(\Tina4\Request &$request){

    //print_r ($request->data);
    $request->data = ["OK"];
});

\Tina4\Middleware::add("world", function(\Tina4\Request &$request){

    //print_r ($request->data);
    $request->data = array_merge(["OK2"], [$request->data]);
});

/**
 * @middleware hello,world
 */
\Tina4\Get::add("/api1/cars", function(\Tina4\Response $response, \Tina4\Request $request) {
    $cars = ["BMW", "Honda", "Toyota"];

    print_r ($request->data);

    echo json_encode($cars);
});


```