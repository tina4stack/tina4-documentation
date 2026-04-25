# Chapter 24: WSDL / SOAP

## 1. SOAP Is Not Dead

Banks. Governments. Insurance companies. Logistics providers. Decades of enterprise software runs on SOAP. If you integrate with any of them, you speak SOAP. Tina4 makes it bearable.

The `WSDL` class exposes your Python functions as SOAP 1.1 operations. It auto-generates the WSDL document at `?wsdl`. You write normal Python functions with type annotations. Tina4 handles the XML envelope, the SOAP headers, and the schema generation.

---

## 2. Your First SOAP Service

```python
from tina4_python.wsdl import WSDL, wsdl_operation

wsdl = WSDL(
    service_name="CalculatorService",
    namespace="http://example.com/calculator",
    endpoint="/api/soap/calculator"
)

@wsdl_operation(wsdl, name="Add", description="Add two integers")
def add(a: int, b: int) -> int:
    return a + b

@wsdl_operation(wsdl, name="Multiply", description="Multiply two integers")
def multiply(a: int, b: int) -> int:
    return a * b
```

Register the service with the router:

```python
from tina4_python.core.router import get, post

@get("/api/soap/calculator")
async def calculator_wsdl(request, response):
    return wsdl.handle_wsdl(request, response)

@post("/api/soap/calculator")
async def calculator_soap(request, response):
    return await wsdl.handle_request(request, response)
```

Visit `http://localhost:7146/api/soap/calculator?wsdl` to see the generated WSDL document. POST a SOAP envelope to the same URL to invoke an operation.

---

## 3. The @wsdl_operation Decorator

`@wsdl_operation` registers a function as a SOAP operation on the given `WSDL` instance.

| Parameter | Type | Description |
|-----------|------|-------------|
| `wsdl` | `WSDL` | The WSDL instance to register on |
| `name` | `str` | Operation name as it appears in the WSDL |
| `description` | `str` | Optional human-readable description |

Type annotations on the function parameters become the SOAP message schema. Supported types: `str`, `int`, `float`, `bool`.

```python
@wsdl_operation(wsdl, name="GetProductPrice")
def get_product_price(product_id: str, currency: str) -> float:
    prices = {"USD": 79.99, "EUR": 73.99, "GBP": 62.99}
    return prices.get(currency, prices["USD"])
```

---

## 4. Auto WSDL Generation at ?wsdl

Tina4 generates the WSDL document from your type annotations. When a SOAP client sends a GET request with the `?wsdl` query string, the handler returns the XML document automatically.

```bash
curl "http://localhost:7146/api/soap/calculator?wsdl"
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions name="CalculatorService"
  targetNamespace="http://example.com/calculator"
  xmlns="http://schemas.xmlsoap.org/wsdl/"
  xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
  xmlns:tns="http://example.com/calculator"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema">

  <types>
    <xsd:schema targetNamespace="http://example.com/calculator">
      <xsd:element name="AddRequest">
        <xsd:complexType>
          <xsd:sequence>
            <xsd:element name="a" type="xsd:int"/>
            <xsd:element name="b" type="xsd:int"/>
          </xsd:sequence>
        </xsd:complexType>
      </xsd:element>
      <xsd:element name="AddResponse">
        <xsd:complexType>
          <xsd:sequence>
            <xsd:element name="result" type="xsd:int"/>
          </xsd:sequence>
        </xsd:complexType>
      </xsd:element>
      <!-- Multiply types... -->
    </xsd:schema>
  </types>

  <!-- Bindings, ports, and service definition... -->
</definitions>
```

Most SOAP clients (SOAPUI, Java's JAX-WS, .NET's `wsdl.exe`) can import this URL directly and generate client stubs.

---

## 5. Calling the Service

A raw SOAP request with curl:

```bash
curl -X POST http://localhost:7146/api/soap/calculator \
  -H "Content-Type: text/xml; charset=utf-8" \
  -H "SOAPAction: \"Add\"" \
  -d '<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:tns="http://example.com/calculator">
  <soap:Body>
    <tns:AddRequest>
      <tns:a>15</tns:a>
      <tns:b>27</tns:b>
    </tns:AddRequest>
  </soap:Body>
</soap:Envelope>'
```

Response:

```xml
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <AddResponse xmlns="http://example.com/calculator">
      <result>42</result>
    </AddResponse>
  </soap:Body>
</soap:Envelope>
```

---

## 6. Lifecycle Hooks: on_request and on_result

Inspect or modify the SOAP request before the operation runs, and modify the response before it is serialised.

```python
from tina4_python.wsdl import WSDL, wsdl_operation
from tina4_python.debug import Log

wsdl = WSDL(
    service_name="OrderService",
    namespace="http://example.com/orders",
    endpoint="/api/soap/orders"
)

def on_request(operation_name, params):
    Log.info("SOAP request received", operation=operation_name, params=params)
    # Return modified params or None to pass through unchanged
    return params

def on_result(operation_name, result):
    Log.info("SOAP operation completed", operation=operation_name, result=result)
    # Return modified result or None to pass through unchanged
    return result

wsdl.on_request = on_request
wsdl.on_result = on_result
```

Use `on_request` for:
- Authentication / API key validation from SOAP headers
- Input sanitisation
- Request logging and audit trails

Use `on_result` for:
- Response transformation
- Stripping internal fields before returning
- Result logging

---

## 7. Complex Types with Dataclasses

For operations that accept or return structured data, use Python dataclasses:

```python
from dataclasses import dataclass
from tina4_python.wsdl import WSDL, wsdl_operation

wsdl = WSDL(
    service_name="ProductService",
    namespace="http://example.com/products",
    endpoint="/api/soap/products"
)

@dataclass
class Product:
    id: str
    name: str
    price: float
    in_stock: bool

@wsdl_operation(wsdl, name="GetProduct")
def get_product(product_id: str) -> Product:
    catalog = {
        "KB-001": Product(id="KB-001", name="Wireless Keyboard", price=79.99, in_stock=True),
        "HUB-002": Product(id="HUB-002", name="USB-C Hub", price=49.99, in_stock=False)
    }
    result = catalog.get(product_id)
    if result is None:
        raise ValueError(f"Product {product_id} not found")
    return result
```

Tina4 introspects the dataclass fields and generates the corresponding WSDL complex types automatically.

---

## 8. Error Handling

Raise a Python exception to return a SOAP fault:

```python
@wsdl_operation(wsdl, name="CreateOrder")
def create_order(customer_id: str, product_id: str, quantity: int) -> str:
    if quantity <= 0:
        raise ValueError("Quantity must be greater than zero")

    if not check_stock(product_id, quantity):
        raise RuntimeError(f"Insufficient stock for {product_id}")

    order_id = f"ORD-{customer_id}-{product_id}"
    return order_id
```

Any raised exception becomes a SOAP fault response:

```xml
<soap:Body>
  <soap:Fault>
    <faultcode>soap:Server</faultcode>
    <faultstring>Quantity must be greater than zero</faultstring>
  </soap:Fault>
</soap:Body>
```

---

## 9. Exercise: Build a Currency Conversion SOAP Service

Create a SOAP service that converts amounts between currencies.

### Requirements

1. Create a `WSDL` instance for a `CurrencyService` at `/api/soap/currency`
2. Implement two operations:
   - `Convert(amount: float, from_currency: str, to_currency: str) -> float`
   - `GetRate(from_currency: str, to_currency: str) -> float`
3. Add `on_request` logging
4. Raise `ValueError` for unknown currency codes

### Test with:

```bash
# Get the WSDL
curl "http://localhost:7146/api/soap/currency?wsdl"

# Convert $100 USD to EUR
curl -X POST http://localhost:7146/api/soap/currency \
  -H "Content-Type: text/xml" \
  -H "SOAPAction: \"Convert\"" \
  -d '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                   xmlns:tns="http://example.com/currency">
    <soap:Body>
      <tns:ConvertRequest>
        <tns:amount>100.0</tns:amount>
        <tns:from_currency>USD</tns:from_currency>
        <tns:to_currency>EUR</tns:to_currency>
      </tns:ConvertRequest>
    </soap:Body>
  </soap:Envelope>'
```

---

## 10. Solution

Create `src/routes/currency_soap.py`:

```python
from tina4_python.core.router import get, post
from tina4_python.wsdl import WSDL, wsdl_operation
from tina4_python.debug import Log

RATES = {
    ("USD", "EUR"): 0.92,
    ("USD", "GBP"): 0.79,
    ("USD", "JPY"): 149.50,
    ("EUR", "USD"): 1.09,
    ("EUR", "GBP"): 0.86,
    ("GBP", "USD"): 1.27,
    ("GBP", "EUR"): 1.17,
}
SUPPORTED = {"USD", "EUR", "GBP", "JPY"}

wsdl = WSDL(
    service_name="CurrencyService",
    namespace="http://example.com/currency",
    endpoint="/api/soap/currency"
)

def on_request(operation_name, params):
    Log.info("SOAP currency request", operation=operation_name, params=str(params))
    return params

wsdl.on_request = on_request


@wsdl_operation(wsdl, name="GetRate", description="Get exchange rate between two currencies")
def get_rate(from_currency: str, to_currency: str) -> float:
    from_currency = from_currency.upper()
    to_currency = to_currency.upper()

    if from_currency not in SUPPORTED:
        raise ValueError(f"Unknown currency: {from_currency}")
    if to_currency not in SUPPORTED:
        raise ValueError(f"Unknown currency: {to_currency}")
    if from_currency == to_currency:
        return 1.0

    rate = RATES.get((from_currency, to_currency))
    if rate is None:
        raise ValueError(f"No rate available for {from_currency} -> {to_currency}")
    return rate


@wsdl_operation(wsdl, name="Convert", description="Convert an amount between currencies")
def convert(amount: float, from_currency: str, to_currency: str) -> float:
    rate = get_rate(from_currency, to_currency)
    return round(amount * rate, 2)


@get("/api/soap/currency")
async def currency_wsdl(request, response):
    return wsdl.handle_wsdl(request, response)


@post("/api/soap/currency")
async def currency_soap(request, response):
    return await wsdl.handle_request(request, response)
```

---

## 11. Gotchas

### 1. Missing SOAPAction header

**Problem:** The SOAP request returns a fault saying the operation was not found.

**Fix:** Include the `SOAPAction` header in every POST request. Its value must match the operation name, wrapped in quotes: `SOAPAction: "Add"`.

### 2. Namespace mismatch

**Problem:** The WSDL is generated with namespace `http://example.com/calculator` but the request body uses a different namespace. The operation is not matched.

**Fix:** Copy the `targetNamespace` from the WSDL document exactly into the request body's `xmlns:tns` attribute. SOAP is namespace-strict.

### 3. Type annotations missing

**Problem:** A parameter with no type annotation causes an error during WSDL generation.

**Fix:** All parameters and return types must be annotated. Supported types: `str`, `int`, `float`, `bool`, and dataclasses whose fields use those types.

### 4. Forgetting the ?wsdl route

**Problem:** The SOAP client cannot import the WSDL because the GET handler is missing.

**Fix:** Register both a `@get` handler (for `?wsdl`) and a `@post` handler (for SOAP operations) on the same path.
