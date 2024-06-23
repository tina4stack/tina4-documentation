# Third party API integrations

Most 3rd party APIs use very similar means of authenticating, the most common use cases call for supporting basic auth or bearer auth.  To this end extending `\Tina4\Api` should have you up and running in minutes not hours.

## Implementing an API

Consider this fun [Cat API](https://cataas.com/doc.html) which we want to implement. Assume the API called for the usual authentication headers we could initialize a class to this end with the following code.

## Authenticating the API

We can put our `CATApi.php` file in the `src/app` folder. We create a `CAT_API_KEY` variable in the .env file and give it a value.
Notice that the `baseURL` has been set to the base API url based on the documentation.

**CATApi.php**
```php
<?php

class CATApi extends \Tina4\Api {

    public function __construct(?string $baseURL="https://cataas.com/api")
    {
        $authHeader = "Authorization: Bearer ".$_ENV["CAT_API_KEY"];
        parent::__construct($baseURL, $authHeader);
    }

}
```

## Getting some cats!

Let's implement a GET request, we can use the built in `sendRequest` method to make the call.
sendRequest returns the following so we can check for an error if returned and retrieve necessary headers:

```php
["error" => $curlError, "info" => $curlInfo, "body" => $response, "httpCode" => $curlInfo['http_code'], "headers" => $headers]
```

Our code will look like this now:

```php
<?php

class CATApi extends \Tina4\Api {

    public function __construct(?string $baseURL="https://cataas.com/api")
    {
        $authHeader = "Authorization: Bearer ".$_ENV["CAT_API_KEY"];
        parent::__construct($baseURL, $authHeader);
    }

    /**
     * Gets some cats
     * @param $limit
     * @param $skip
     * @return array|mixed
     */
    public function getCats($limit, $skip) : array
    {
        $result = $this->sendRequest("/cats?limit={$limit}&skip={$skip}", "GET");
        if (empty($result["error"])) {
            return $result["body"]; //this is the actual response back from the API
        } else {
            return $result;
        }
    }
}
```

## Testing the getCats method

In order to test we can make a quick GET router

Under `src/routes` make a `cats.php` file and add the following code.

```php
<?php

\Tina4\Get::any("/get/cats", function(\Tina4\Response $response) {

    $cats = (new CATApi())->getCats($limit=10, $skip=5);

    return $response ($cats);
});

```

What happens when you hit up [http://localhost:7145/get/cats](http://localhost:7145/get/cats)?

## Hot Tips
>- Extend and use `\Tina4\Api` as all the work to retrieve REST data has already been done for you
>- Data is returned in object form and the data has already been decoded for you so you can use it directly in your code