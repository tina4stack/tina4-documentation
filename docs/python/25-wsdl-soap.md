# Chapter 24: WSDL / SOAP

## 1. SOAP Is Not Dead

Banks. Governments. Insurance companies. Logistics providers. Decades of enterprise software runs on SOAP. If you integrate with any of them, you speak SOAP. Tina4 makes it bearable.

The `WSDL` class exposes your Python functions as SOAP 1.1 operations. It auto-generates the WSDL document at `?wsdl`. You write normal Python functions with type annotations. Tina4 handles the XML envelope, the SOAP headers, and the schema generation.

---

## 2. Your First SOAP Service

Tina4's WSDL service is a class you subclass. Methods marked with `@wsdl_operation` become SOAP operations. Each operation declares its response schema as a dict mapping field names to Python types.

```python
from tina4_python.wsdl import WSDL, wsdl_operation
from tina4_python.core.router import get, post


class Calculator(WSDL):
    @wsdl_operation({"Result": int})
    def Add(self, a: int, b: int):
        return {"Result": a + b}

    @wsdl_operation({"Result": int})
    def Multiply(self, a: int, b: int):
        return {"Result": a * b}
```

Mount it on a route. The same handler answers both the WSDL definition and SOAP invocations — `Calculator(request).handle()` inspects the request and returns the right thing.

```python
@get("/api/soap/calculator")
@post("/api/soap/calculator")
async def calculator(request, response):
    service = Calculator(request)
    return response(service.handle())
```

Visit `http://localhost:7146/api/soap/calculator?wsdl` to see the generated WSDL document. POST a SOAP envelope to the same URL to invoke an operation.

---

## 3. The @wsdl_operation Decorator

`@wsdl_operation` marks a method on a `WSDL` subclass as a SOAP operation. The single argument is the response schema — a dict mapping each output field name to its Python type.

```python
class PriceService(WSDL):
    @wsdl_operation({"Price": float, "Currency": str})
    def GetProductPrice(self, product_id: str, currency: str):
        prices = {"USD": 79.99, "EUR": 73.99, "GBP": 62.99}
        return {"Price": prices.get(currency, prices["USD"]), "Currency": currency}
```

Method-parameter type annotations become the request-message schema. The operation name is the method name. Supported types: `str`, `int`, `float`, `bool`, plus `List[T]` and `Optional[T]` for collections and nullable fields.

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

Override `on_request` and `on_result` in your subclass to inspect or modify the SOAP envelope before invocation and the result before serialisation.

```python
from tina4_python.wsdl import WSDL, wsdl_operation
from tina4_python.debug import Log


class OrderService(WSDL):
    def on_request(self, request):
        """Runs before each operation. Validate auth, audit, etc."""
        Log.info("SOAP request received", path=getattr(request, "path", ""))

    def on_result(self, result):
        """Transform or strip fields before serialisation."""
        Log.info("SOAP operation completed")
        return result

    @wsdl_operation({"OrderId": str})
    def CreateOrder(self, customer_id: str, product_id: str, quantity: int):
        return {"OrderId": f"ORD-{customer_id}-{product_id}"}
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

## 7. Complex Types and Lists

When an operation needs to return structured records or collections, describe the shape in the `@wsdl_operation` response schema. Use `List[T]` for collections and `Optional[T]` for nullable fields.

```python
from typing import List, Optional
from tina4_python.wsdl import WSDL, wsdl_operation


class ProductService(WSDL):
    @wsdl_operation({
        "Id": str,
        "Name": str,
        "Price": float,
        "InStock": bool,
        "Error": Optional[str],
    })
    def GetProduct(self, product_id: str):
        catalog = {
            "KB-001": {"Id": "KB-001", "Name": "Wireless Keyboard", "Price": 79.99, "InStock": True, "Error": None},
            "HUB-002": {"Id": "HUB-002", "Name": "USB-C Hub", "Price": 49.99, "InStock": False, "Error": None},
        }
        return catalog.get(product_id, {"Id": "", "Name": "", "Price": 0.0, "InStock": False, "Error": "not found"})

    @wsdl_operation({"Total": int, "Average": float, "Error": Optional[str]})
    def SumList(self, Numbers: List[int]):
        if not Numbers:
            return {"Total": 0, "Average": 0.0, "Error": "Empty list"}
        return {"Total": sum(Numbers), "Average": sum(Numbers) / len(Numbers), "Error": None}
```

The dict you return must match the declared schema keys. Tina4 generates the WSDL `<complexType>` definitions from the schema dict and the method's parameter annotations.

---

## 8. Error Handling

Raise a Python exception inside an operation to return a SOAP fault:

```python
class OrderService(WSDL):
    @wsdl_operation({"OrderId": str})
    def CreateOrder(self, customer_id: str, product_id: str, quantity: int):
        if quantity <= 0:
            raise ValueError("Quantity must be greater than zero")

        if not check_stock(product_id, quantity):
            raise RuntimeError(f"Insufficient stock for {product_id}")

        return {"OrderId": f"ORD-{customer_id}-{product_id}"}
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


class CurrencyService(WSDL):
    def on_request(self, request):
        Log.info("SOAP currency request received")

    def _lookup_rate(self, from_currency: str, to_currency: str) -> float:
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

    @wsdl_operation({"Rate": float})
    def GetRate(self, from_currency: str, to_currency: str):
        return {"Rate": self._lookup_rate(from_currency, to_currency)}

    @wsdl_operation({"Amount": float, "Rate": float})
    def Convert(self, amount: float, from_currency: str, to_currency: str):
        rate = self._lookup_rate(from_currency, to_currency)
        return {"Amount": round(amount * rate, 2), "Rate": rate}


@get("/api/soap/currency")
@post("/api/soap/currency")
async def currency(request, response):
    return response(CurrencyService(request).handle())
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
