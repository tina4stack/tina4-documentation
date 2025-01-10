# Dynamic routes

There is a way you can create routes dynamically using code.  The `Route` class is used to create these routes.

```php
$path = "/path/{id}";

Route::get($path, 
    function (\Tina4\Response $response, \Tina4\Request $request)
    {   
        $id = $request->inlineParams[0];
        
        return $response("The is is {$id}");
    }
);
```

This methodology is used in the CRUD router.

## Hot tips
>- Path variables are added to the `$request` object as an array of `inlineParams`