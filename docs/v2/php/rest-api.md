# Rest API interactions
::: tip 🔥 Hot Tips
- Use `Tina4\Api` to effectively build a CURL request without ever having to dive into CURL code.
- Control over security, curl options and data to be sent.
- Make use of the `$_ENV` super global for storing keys.
  :::
## Simple GET request
Getting data from a public api is as simple as one line of code.
```php
$api = (new \Tina4\Api("https://api.example.com"))->sendRequest("/my-route", "GET");
```

## Sending Data

```php
$body = json_encode(["test"=>"This is a test","another-test"=>"Another test"]);
$api = (new \Tina4\Api("https://api.example.com"))
            ->sendRequest("/my-route", "POST", $body, "application/json");
```
## Adding security
If you need to add an auth header, it is useful to do it at a top level, which is then set for all subsequent calls.
```php
$baseUrl = "https://api.example.com";
$authHeader = "Authorization: Bearer 1234";
$api = new \Tina4\Api($baseUrl, $authHeader);
$simpleResponse = $api->sendRequest("/simple-route", "GET");
$complicatedResponse = $api->sendRequest("/complicated-route", "GET");
```
## Custom headers
Some api services require multiple headers to either instruct responses or for added security. Use the `$customHeaders` array for that purpose.
The custom headers can also be used to set the auth header, if it has not been set at top level.
```php
$customHeaders = [
    "Authorization: Bearer " . $_ENV["TOKEN"],
    "ApiKey: " . $_ENV["TINA4_API_KEY"]
    ];
$body = json_encode(["test"=>"This is a test","another-test"=>"Another test"]);
$api = (new \Tina4\Api("https://api.example.com"))
            ->sendRequest("/my-route", "POST", $body, "application/json", $customHeaders);
```

## Curl options
The numerous custom curl options can be added using the `$curlOptions` array.
```php
// Forcing all transactions to use SSL
$curlOptions = [CURLUSESSL_ALL];
$api = (new \Tina4\Api("https://api.example.com"))
            ->sendRequest("/my-route", "POST", null, null, [], $curlOptions);
```