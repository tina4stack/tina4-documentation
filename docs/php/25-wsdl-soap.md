# Chapter 24: WSDL / SOAP

## 1. When You Need SOAP

Most new APIs use REST and JSON. But enterprise systems — banks, insurers, government portals, ERP platforms — often expose SOAP services. You need to interoperate. Sometimes you are also required to expose a SOAP interface for an existing client that cannot change.

Tina4 provides a `WSDL` base class. Extend it. Annotate methods with `@wsdl_operation`. The WSDL document is generated automatically and served at `?wsdl`. Your service handles both SOAP 1.1 and SOAP 1.2.

---

## 2. Creating a SOAP Service

Extend `Tina4\WSDL`. Each public method annotated with `@wsdl_operation` becomes a SOAP operation.

```php
<?php
use Tina4\WSDL;

class CalculatorService extends WSDL
{
    /**
     * Add two numbers together.
     *
     * @wsdl_operation
     * @param float $a First operand
     * @param float $b Second operand
     * @return float Sum of a and b
     */
    public function Add(float $a, float $b): float
    {
        return $a + $b;
    }

    /**
     * Subtract b from a.
     *
     * @wsdl_operation
     * @param float $a
     * @param float $b
     * @return float
     */
    public function Subtract(float $a, float $b): float
    {
        return $a - $b;
    }

    /**
     * Multiply two numbers.
     *
     * @wsdl_operation
     * @param float $a
     * @param float $b
     * @return float
     */
    public function Multiply(float $a, float $b): float
    {
        return $a * $b;
    }

    /**
     * Divide a by b.
     *
     * @wsdl_operation
     * @param float $a Dividend
     * @param float $b Divisor (must not be zero)
     * @return float Quotient
     */
    public function Divide(float $a, float $b): float
    {
        if ($b == 0) {
            throw new \SoapFault('Receiver', 'Division by zero is not allowed');
        }
        return $a / $b;
    }
}
```

---

## 3. Registering the Service

Mount the service on a URL path. Tina4 handles routing, WSDL generation, and request dispatching:

```php
<?php
use Tina4\Router;

Router::soap('/calculator', new CalculatorService());
```

That is the entire registration. The service is now live at:

- `POST /calculator` — accepts SOAP envelopes
- `GET /calculator?wsdl` — returns the auto-generated WSDL document

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

    /**
     * Convert an amount from one currency to another.
     *
     * @wsdl_operation
     * @param float  $amount       Amount to convert
     * @param string $fromCurrency Source currency code (e.g., USD)
     * @param string $toCurrency   Target currency code (e.g., EUR)
     * @return float               Converted amount
     */
    public function Convert(float $amount, string $fromCurrency, string $toCurrency): float
    {
        $from = strtoupper($fromCurrency);
        $to   = strtoupper($toCurrency);

        if (!isset($this->rates[$from])) {
            throw new \SoapFault('Receiver', "Unsupported currency: {$from}");
        }

        if (!isset($this->rates[$to])) {
            throw new \SoapFault('Receiver', "Unsupported currency: {$to}");
        }

        // Convert via USD as the base
        $usdAmount = $amount / $this->rates[$from];
        return round($usdAmount * $this->rates[$to], 2);
    }

    /**
     * List all supported currency codes.
     *
     * @wsdl_operation
     * @return string Comma-separated list of supported currencies
     */
    public function GetSupportedCurrencies(): string
    {
        return implode(',', array_keys($this->rates));
    }

    /**
     * Get the exchange rate from one currency to another.
     *
     * @wsdl_operation
     * @param string $fromCurrency Source currency code
     * @param string $toCurrency   Target currency code
     * @return float               Exchange rate
     */
    public function GetRate(string $fromCurrency, string $toCurrency): float
    {
        return $this->Convert(1.0, $fromCurrency, $toCurrency);
    }
}
```

Register:

```php
Router::soap('/currency', new CurrencyService());
```

Call:

```php
$client = new SoapClient('http://localhost:7145/currency?wsdl');

$converted = $client->Convert(['amount' => 100, 'fromCurrency' => 'USD', 'toCurrency' => 'EUR']);
echo $converted->ConvertResult;    // 92.0

$currencies = $client->GetSupportedCurrencies();
echo $currencies->GetSupportedCurrenciesResult;  // USD,EUR,GBP,JPY,AUD
```

---

## 7. Type Annotations

Tina4 reads PHP 8 type hints to generate XSD types. The mapping is:

| PHP type | WSDL/XSD type |
|----------|---------------|
| `int` | `xsd:integer` |
| `float` | `xsd:float` |
| `string` | `xsd:string` |
| `bool` | `xsd:boolean` |
| `array` | `xsd:anyType` |

Always use explicit PHP 8 type declarations on parameters and return types. Without them, the WSDL generator falls back to `xsd:anyType`.

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
/**
 * @wsdl_operation
 * @param int $userId
 * @return string
 */
public function GetUserEmail(int $userId): string
{
    if ($userId <= 0) {
        throw new \SoapFault('Client', 'User ID must be a positive integer');
    }

    $user = $this->db->fetchOne("SELECT email FROM users WHERE id = ?", [$userId]);

    if ($user === null) {
        throw new \SoapFault('Receiver', "User {$userId} not found");
    }

    return $user['email'];
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

**Cause:** Missing `@wsdl_operation` annotation in the docblock.

**Fix:** Add `@wsdl_operation` to the method's PHPDoc comment. All WSDL-exposed methods must have it.

### 2. Wrong XSD types

**Problem:** The client receives strings instead of numbers, or booleans instead of integers.

**Cause:** PHP type hints are missing. Without them, the generator defaults to `xsd:anyType`.

**Fix:** Always declare explicit parameter and return types using PHP 8 typed properties and return types.

### 3. SOAP Fault not reaching the client

**Problem:** Throwing `SoapFault` inside the service does not produce a proper SOAP fault response. The client receives a generic HTTP 500.

**Cause:** The exception is caught by a top-level error handler before Tina4 can serialize it as a SOAP fault.

**Fix:** Only throw `\SoapFault`. Do not throw generic exceptions. Tina4's SOAP dispatcher catches `SoapFault` and serializes it correctly.

### 4. WSDL URL is wrong in generated document

**Problem:** The generated WSDL contains `localhost` as the service URL. Clients in other environments cannot use it.

**Cause:** The WSDL generator reads the `Host` header from the current request.

**Fix:** Set `TINA4_BASE_URL` in your environment to override the auto-detected host: `TINA4_BASE_URL=https://api.example.com`.
