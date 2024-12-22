# How to get JWT tokens and create a custom authentication

## Tokens with payloads

JWT tokens are great because they can carry a payload of data which can be validated and used on the server side.
We have support for these type of tokens out of the box on Tina4. Our form tokens are generated this way and the payload is generally the form name.

This code will get you a token
```php
$payload = ["name" => "Tina4", "age" => 16];
$token = (new \Tina4\Auth())->getToken($payload);
```

## Validating the token

Tokens can be validated and their payload extracted.  The payload can be returned with their expiry time or not.

```php
$token = "...";
//Return without the expires value
$payload = (new \Tina4\Auth())->getPayload($token);

//Return with the expires value
$payload = (new \Tina4\Auth())->getPayload($token, true);
```

## Hot Tips
>- Tokens do expire! So even if the payload is valid it may be the token is not valid.
>- Increase the time tokens are valid for by using the `TINA4_TOKEN_MINUTES` variable in your `.env` file.
