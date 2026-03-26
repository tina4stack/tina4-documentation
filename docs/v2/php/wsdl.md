# WSDL / SOAP Services {#wsdl}

Tina4 includes a built-in SOAP 1.1 / WSDL 1.0 service with zero-configuration automatic WSDL generation. Extend the `\Tina4\WSDL` abstract class, define your methods, and Tina4 handles the rest.

::: tip Hot tips!
- WSDL is auto-generated from your PHP method signatures — no XML files to maintain
- Supports `string`, `int`, `float`, `bool`, `array<T>`, `?T` (nullable) types
- Works behind reverse proxies with `X-Forwarded-*` header support
- Access `?wsdl` on any SOAP endpoint to get the service definition
:::

## Quick Start {#quick-start}

### 1. Define Your Service

Create a class extending `\Tina4\WSDL` with your SOAP operations as public methods:

```php
class Calculator extends \Tina4\WSDL
{
    protected array $returnSchemas = [
        "Add" => ["Result" => "int"],
        "SumList" => [
            "Numbers" => "array<int>",
            "Total" => "int",
            "Error" => "?string"
        ]
    ];

    public function Add(int $a, int $b): array
    {
        return ["Result" => $a + $b];
    }

    /**
     * @param int[] $Numbers
     */
    public function SumList(array $Numbers): array
    {
        return [
            "Numbers" => $Numbers,
            "Total" => array_sum($Numbers),
            "Error" => null
        ];
    }
}
```

### 2. Register a Route

```php
\Tina4\Any::add("/calculator", function (\Tina4\Request $request, \Tina4\Response $response) {
    $calculator = new Calculator($request);
    $handle = $calculator->handle();
    return $response($handle, HTTP_OK, APPLICATION_XML);
});
```

Now:
- `GET /calculator?wsdl` returns the auto-generated WSDL definition
- `POST /calculator` with a SOAP envelope calls your methods

## Return Schemas {#return-schemas}

The `$returnSchemas` property defines the structure of SOAP responses for each method. Without a schema, methods return a generic array of strings.

```php
protected array $returnSchemas = [
    "MethodName" => [
        "FieldName" => "type",
        // ...
    ]
];
```

### Supported Types

| Type | XSD Equivalent | Description |
|------|----------------|-------------|
| `string` | `xsd:string` | Text values |
| `int` | `xsd:int` | Integer values |
| `float` | `xsd:double` | Floating-point numbers |
| `bool` | `xsd:boolean` | Boolean values |
| `array<T>` or `T[]` | `ArrayOfX` complex type | Arrays of any scalar type |
| `?T` | `minOccurs="0" nillable="true"` | Nullable/optional values |

## Parameter Types {#parameters}

Method parameters are automatically mapped from PHP type hints to XSD types. For array parameters, use PHPDoc annotations:

```php
/**
 * @param string[] $names
 * @param int[] $ids
 */
public function ProcessBatch(array $names, array $ids): array
{
    // $names and $ids are properly typed arrays
    return ["Count" => count($names) + count($ids)];
}
```

## Hooks {#hooks}

Two optional hooks let you intercept requests and modify results:

### onRequest

Called before the SOAP method is invoked:

```php
class MyService extends \Tina4\WSDL
{
    protected function onRequest(\Tina4\Request $request): void
    {
        // Authenticate, log, validate headers, etc.
        $authHeader = $request->headers['Authorization'] ?? '';
        if (empty($authHeader)) {
            throw new \Exception("Authentication required");
        }
    }
}
```

### onResult

Called after the method returns, allowing you to transform the result:

```php
protected function onResult(mixed $result): mixed
{
    // Add metadata, transform, log, etc.
    $result['Timestamp'] = date('c');
    return $result;
}
```

## Service URL Override {#service-url}

Behind a reverse proxy, the auto-detected URL may be incorrect. Override it with a class constant:

```php
class MyService extends \Tina4\WSDL
{
    public const SERVICE_URL = "https://api.example.com/my-service";

    // ... methods
}
```

Without this, Tina4 uses `X-Forwarded-Proto`, `X-Forwarded-Host`, and `REQUEST_URI` to build the URL automatically.

## Nullable Values {#nullable}

Nullable fields use `xsi:nil="true"` in the SOAP response:

```php
protected array $returnSchemas = [
    "GetUser" => [
        "Name" => "string",
        "Email" => "?string",
        "Phone" => "?string"
    ]
];

public function GetUser(int $id): array
{
    return [
        "Name" => "John",
        "Email" => "john@example.com",
        "Phone" => null  // Will render as <Phone xsi:nil="true"/>
    ];
}
```

## Error Handling {#errors}

Exceptions thrown in your methods are automatically wrapped in a SOAP Fault response:

```xml
<Envelope>
  <Body>
    <Fault>
      <faultcode>Server</faultcode>
      <faultstring>Your error message here</faultstring>
    </Fault>
  </Body>
</Envelope>
```

## Complete Example {#example}

```php
class UserService extends \Tina4\WSDL
{
    protected array $returnSchemas = [
        "Login" => [
            "SessionId" => "string",
            "Expires" => "string",
            "Roles" => "array<string>",
            "Error" => "?string"
        ],
        "GetProfile" => [
            "Name" => "string",
            "Email" => "string",
            "Age" => "int"
        ]
    ];

    public function Login(string $username, string $password): array
    {
        if ($username === "admin" && $password === "secret") {
            return [
                "SessionId" => bin2hex(random_bytes(16)),
                "Expires" => date("c", strtotime("+1 hour")),
                "Roles" => ["admin", "user"],
                "Error" => null
            ];
        }
        return [
            "SessionId" => "",
            "Expires" => "",
            "Roles" => [],
            "Error" => "Invalid credentials"
        ];
    }

    public function GetProfile(string $sessionId): array
    {
        return [
            "Name" => "Admin User",
            "Email" => "admin@example.com",
            "Age" => 30
        ];
    }
}

\Tina4\Any::add("/user-service", function (\Tina4\Request $request, \Tina4\Response $response) {
    $service = new UserService($request);
    return $response($service->handle(), HTTP_OK, APPLICATION_XML);
});
```

Access the WSDL at `/user-service?wsdl` and use any SOAP client to call the service.
