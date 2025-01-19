# Security and Custom Auth Helper

Tina4 uses JWT to encrypt tokens for validation. These tokens are not always practical when doing integrations and
one might want to do other versions of verification.  To this end we can extend the `\Tina4\Auth` class and overwrite 
the core methods.

## Declaring the custom authentication class

A custom authentication has the following layout:

**ExampleAuth.php**
```php
<?php

class ExampleAuth extends \Tina4\Auth
{

    final public function validToken(string $token, string $publicKey = "", string $encryption = \Nowakowskir\JWT\JWT::ALGORITHM_RS256): bool
    {
        //Some custom auth validation, maybe checking the token from the database, the token passed through is either formToken or Authorization header
        $token = str_replace("Bearer", "",  $token);
        if (trim($token) === "ABC") 
        {
            return true; //token is valid
        }
        
        return parent::validToken($token, $publicKey, $encryption);
    }
}
```

## Instantiating or activating the custom authentication class

The auth helper needs to be instantiated in `index.php`

**index.php**
```php
<?php

require_once "./vendor/autoload.php";

$config = new \Tina4\Config(static function (\Tina4\Config $config){
    //Your own config initializations

});

//Instantiate the custom auth helper
$config->setAuthentication((new ExampleAuth()));

echo new \Tina4\Tina4Php($config);

```

!!! tip "Hot Tips"
    - You can also check the token payload if you use a JWT token
    - If want a quick authentication mechanism use the `API_KEY` global in `.env` to create a quick bearer auth mechanism.
