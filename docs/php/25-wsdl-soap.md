# Chapter 25: WSDL / SOAP

## 1. When You Need SOAP

Most new APIs use REST and JSON. But enterprise systems (banks, insurers, government portals, ERP platforms) often expose SOAP services. You need to interoperate. Sometimes you are also required to expose a SOAP interface for an existing client that cannot change.

Tina4 provides a `WSDL` base class. Extend it. Annotate methods with the `#[WSDLOperation([...])]` PHP attribute. The WSDL document is generated automatically and served at `?wsdl`. Your service handles both SOAP 1.1 and SOAP 1.2.

---

## 2. Creating a SOAP Service

Extend `Tina4\WSDL`. Each public method marked with the `#[WSDLOperation([...])]` attribute becomes a SOAP operation. The attribute's array declares the response shape, a map of field names to XSD types.

```php
<?php
use Tina4\WSDL;
use Tina4\WSDLOperation;

class CalculatorService extends WSDL
{
    protected string $serviceName = 'Calculator';

    #[WSDLOperation(['Result' => 'float'])]
    public function Add(float $a, float $b): array
    {
        return ['Result' => $a + $b];
    }

    #[WSDLOperation(['Result' => 'float'])]
    public function Subtract(float $a, float $b): array
    {
        return ['Result' => $a - $b];
    }

    #[WSDLOperation(['Result' => 'float'])]
    public function Multiply(float $a, float $b): array
    {
        return ['Result' => $a * $b];
    }

    #[WSDLOperation(['Result' => 'float'])]
    public function Divide(float $a, float $b): array
    {
        if ($b == 0) {
            throw new \RuntimeException('Division by zero is not allowed');
        }
        return ['Result' => $a / $b];
    }
}
```

Each operation is a public method on the subclass. The `#[WSDLOperation([...])]` PHP attribute declares the response shape, a map of field names to XSD types. The method returns an associative array whose keys match the attribute's spec. Parameter types come from PHP's native type hints (`float`, `int`, `string`, `bool`).

---

## 3. Registering the Service

Mount the service on a URL path. The same handler answers both the WSDL document request (`GET ?wsdl`) and SOAP invocations (`POST`): `(new CalculatorService($request))->handle()` inspects the request and returns the right thing.

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::any('/calculator', function (Request $request, Response $response) {
    $service = new CalculatorService($request);
    return $service->handle();
});
```

The service is now live at:

- `POST /calculator` - accepts SOAP envelopes, dispatches to the matching `#[WSDLOperation]` method
- `GET /calculator?wsdl` - returns the auto-generated WSDL document

---

## 4. Accessing the Auto-Generated WSDL

```bash
curl http://localhost:7145/calculator?wsdl
```

Response:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<wsdl:definitions
    name="CalculatorService"
    targetNamespace="http://localhost:7145/calculator"
    xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
    xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
    xmlns:tns="http://localhost:7145/calculator"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">

  <wsdl:types>
    <xsd:schema targetNamespace="http://localhost:7145/calculator">
      <xsd:element name="Add">
        <xsd:complexType>
          <xsd:sequence>
            <xsd:element name="a" type="xsd:float"/>
            <xsd:element name="b" type="xsd:float"/>
          </xsd:sequence>
        </xsd:complexType>
      </xsd:element>
      <!-- ... other operations ... -->
    </xsd:schema>
  </wsdl:types>

  <wsdl:portType name="CalculatorServicePortType">
    <wsdl:operation name="Add">
      <wsdl:documentation>Add two numbers together.</wsdl:documentation>
      <wsdl:input message="tns:AddSoapIn"/>
      <wsdl:output message="tns:AddSoapOut"/>
    </wsdl:operation>
    <!-- ... -->
  </wsdl:portType>

  <!-- binding, service, port elements follow -->
</wsdl:definitions>
```

The WSDL is derived from your PHP type hints and docblock comments. You write PHP. Tina4 writes the WSDL.

---

## 5. Calling the Service with PHP SoapClient

Test your service using PHP's built-in `SoapClient`:

```php
<?php

$client = new SoapClient('http://localhost:7145/calculator?wsdl', [
    'trace'      => true,
    'exceptions' => true
]);

// Add
$result = $client->Add(['a' => 10.5, 'b' => 4.5]);
echo $result->AddResult;   // 15.0

// Subtract
$result = $client->Subtract(['a' => 100, 'b' => 37]);
echo $result->SubtractResult;   // 63.0

// Multiply
$result = $client->Multiply(['a' => 6, 'b' => 7]);
echo $result->MultiplyResult;   // 42.0

// Divide
$result = $client->Divide(['a' => 22, 'b' => 7]);
echo $result->DivideResult;     // 3.142857...

// SOAP Fault on divide by zero
try {
    $client->Divide(['a' => 1, 'b' => 0]);
} catch (\SoapFault $e) {
    echo $e->getMessage();  // Division by zero is not allowed
}
```

---

## 6. A Real-World Service: Currency Conversion

```php
<?php
use Tina4\WSDL;

class CurrencyService extends WSDL
{
    private array $rates = [
        'USD' => 1.0,
        'EUR' => 0.92,
        'GBP' => 0.79,
        'JPY' => 149.50,
        'AUD' => 1.54
    ];

    #[WSDLOperation(['Converted' => 'float'])]
    public function Convert(float $amount, string $fromCurrency, string $toCurrency): array
    {
        $from = strtoupper($fromCurrency);
        $to   = strtoupper($toCurrency);

        if (!isset($this->rates[$from])) {
            throw new \RuntimeException("Unsupported currency: {$from}");
        }
        if (!isset($this->rates[$to])) {
            throw new \RuntimeException("Unsupported currency: {$to}");
        }

        // Convert via USD as the base
        $usdAmount = $amount / $this->rates[$from];
        return ['Converted' => round($usdAmount * $this->rates[$to], 2)];
    }

    #[WSDLOperation(['Currencies' => 'string'])]
    public function GetSupportedCurrencies(): array
    {
        return ['Currencies' => implode(',', array_keys($this->rates))];
    }

    #[WSDLOperation(['Rate' => 'float'])]
    public function GetRate(string $fromCurrency, string $toCurrency): array
    {
        $result = $this->Convert(1.0, $fromCurrency, $toCurrency);
        return ['Rate' => $result['Converted']];
    }
}
```

Register:

```php
Router::any('/currency', function (Request $request, Response $response) {
    return (new CurrencyService($request))->handle();
});
```

Call:

```php
$client = new SoapClient('http://localhost:7145/currency?wsdl');

$converted = $client->Convert(['amount' => 100, 'fromCurrency' => 'USD', 'toCurrency' => 'EUR']);
echo $converted->Converted;          // 92.0

$currencies = $client->GetSupportedCurrencies();
echo $currencies->Currencies;        // USD,EUR,GBP,JPY,AUD
```

The SOAP response field names mirror the `#[WSDLOperation([...])]` attribute keys.

---

## 7. Type Annotations

Tina4 reads PHP 8 type hints on parameters to generate XSD request types, and the `#[WSDLOperation([fieldName => 'xsd-type'])]` attribute to generate response types. The mapping is:

| PHP type / attribute value | WSDL/XSD type |
|----------|---------------|
| `int` / `'int'` / `'integer'` | `xsd:integer` |
| `float` / `'float'` / `'double'` | `xsd:float` |
| `string` / `'string'` | `xsd:string` |
| `bool` / `'boolean'` | `xsd:boolean` |
| `array` (parameter) | `xsd:anyType` |

Always use explicit PHP 8 type declarations on method parameters. The response field names AND types come from the attribute; the method returns an associative array matching the attribute's spec.

---

## 8. SOAP Faults

Throw `SoapFault` to return a structured SOAP error to the client. The first argument is the fault code, the second is the fault message.

Standard fault codes:

| Code | When to use |
|------|-------------|
| `'Client'` | The request is malformed or missing required data |
| `'Receiver'` | The server encountered an error processing a valid request |
| `'VersionMismatch'` | SOAP version mismatch |

```php
#[WSDLOperation(['Email' => 'string'])]
public function GetUserEmail(int $userId): array
{
    if ($userId <= 0) {
        throw new \SoapFault('Client', 'User ID must be a positive integer');
    }

    $user = $this->db->fetchOne("SELECT email FROM users WHERE id = ?", [$userId]);

    if ($user === null) {
        throw new \SoapFault('Receiver', "User {$userId} not found");
    }

    return ['Email' => $user['email']];
}
```

---

## 9. Testing with curl

Send a raw SOAP envelope to test without a SOAP client:

```bash
curl -X POST http://localhost:7145/calculator \
  -H "Content-Type: text/xml; charset=utf-8" \
  -H "SOAPAction: \"Add\"" \
  -d '<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <Add xmlns="http://localhost:7145/calculator">
      <a>10.5</a>
      <b>4.5</b>
    </Add>
  </soap:Body>
</soap:Envelope>'
```

Response:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <AddResponse xmlns="http://localhost:7145/calculator">
      <AddResult>15</AddResult>
    </AddResponse>
  </soap:Body>
</soap:Envelope>
```

---

## 10. Gotchas

### 1. Method not appearing in WSDL

**Problem:** A method exists on the class but does not appear in the generated WSDL.

**Cause:** Missing `#[WSDLOperation([...])]` PHP attribute on the method.

**Fix:** Add `#[WSDLOperation(['FieldName' => 'xsdType'])]` immediately above the method declaration. All WSDL-exposed methods must have it. Make sure you `use Tina4\WSDLOperation;` at the top of the file.

### 2. Wrong XSD types

**Problem:** The client receives strings instead of numbers, or booleans instead of integers.

**Cause:** PHP type hints are missing on method parameters, OR the `#[WSDLOperation([...])]` response-shape array uses the wrong XSD type name.

**Fix:** Always declare explicit parameter types using PHP 8 type hints (`int`, `float`, `string`, `bool`). For response types, use the XSD names in the attribute array: `'int'`, `'float'`, `'string'`, `'boolean'`.

### 3. SOAP Fault not reaching the client

**Problem:** Throwing `SoapFault` inside the service does not produce a proper SOAP fault response. The client receives a generic HTTP 500.

**Cause:** The exception is caught by a top-level error handler before Tina4 can serialize it as a SOAP fault.

**Fix:** Only throw `\SoapFault`. Do not throw generic exceptions. Tina4's SOAP dispatcher catches `SoapFault` and serializes it correctly.

### 4. WSDL URL is wrong in generated document

**Problem:** The generated WSDL contains `localhost` as the service URL. Clients in other environments cannot use it.

**Cause:** The WSDL generator reads the `Host` header from the current request.

**Fix:** Set `TINA4_HOST_NAME` in your environment to override the auto-detected host: `TINA4_HOST_NAME=https://api.example.com`.
