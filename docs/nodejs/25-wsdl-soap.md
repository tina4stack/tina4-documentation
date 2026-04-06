# Chapter 24: WSDL / SOAP

## 1. Legacy Services Are Still Services

SOAP is not new. It is also not gone. Banks, government agencies, ERP systems, and healthcare providers expose SOAP APIs. If you integrate with any of them, you need to speak SOAP.

WSDL (Web Services Description Language) is the schema for SOAP services. It defines operations, input types, and output types in XML. You call an operation, you get XML back, you parse it.

Tina4 provides a `WSDL` class that both consumes external SOAP services and publishes your own. You write normal TypeScript functions. Tina4 generates the WSDL document and handles the XML envelope plumbing.

---

## 2. Consuming an External SOAP Service

### Loading the WSDL

```typescript
import { WSDL } from "tina4-nodejs";

const client = await WSDL.load("https://www.dataaccess.com/webservicesserver/NumberConversion.wso?WSDL");
```

`WSDL.load()` fetches the WSDL document, parses it, and returns a client object. Operations defined in the WSDL become methods on the client.

### Calling an Operation

```typescript
const result = await client.call("NumberToWords", {
    ubiNum: 42
});

console.log(result);
// "forty two "
```

`call(operationName, params)` builds the SOAP envelope, sends the request, parses the XML response, and returns the unwrapped value.

### Handling Errors

```typescript
try {
    const result = await client.call("NumberToWords", { ubiNum: -1 });
    console.log(result);
} catch (err) {
    if (err instanceof SOAPFault) {
        console.error("SOAP fault:", err.faultString, err.detail);
    } else {
        console.error("Network error:", err.message);
    }
}
```

---

## 3. wsdl_operation Decorator

When exposing your own functions as SOAP operations, use the `wsdl_operation` decorator to describe the input and output types:

```typescript
import { wsdl_operation } from "tina4-nodejs";

@wsdl_operation({
    name: "GetProductPrice",
    input: {
        productId: "string"
    },
    output: {
        price: "decimal",
        currency: "string",
        available: "boolean"
    },
    description: "Returns the current price for a product by ID"
})
async function GetProductPrice(params: { productId: string }) {
    const price = await lookupPrice(params.productId);
    return {
        price: price.amount,
        currency: price.currency,
        available: price.inStock
    };
}
```

The decorator registers the function as a SOAP operation and provides type information for WSDL generation.

---

## 4. Publishing a SOAP Service

Register your operations and mount the SOAP endpoint:

```typescript
import { Router, WSDL, wsdl_operation } from "tina4-nodejs";

// Define operations
@wsdl_operation({
    name: "ConvertCurrency",
    input: { amount: "decimal", from: "string", to: "string" },
    output: { result: "decimal", rate: "decimal" }
})
async function ConvertCurrency(params: { amount: number; from: string; to: string }) {
    // Simulate a conversion
    const rate = params.from === "USD" && params.to === "EUR" ? 0.92 : 1.0;
    return {
        result: parseFloat((params.amount * rate).toFixed(2)),
        rate
    };
}

@wsdl_operation({
    name: "GetExchangeRate",
    input: { from: "string", to: "string" },
    output: { rate: "decimal", timestamp: "string" }
})
async function GetExchangeRate(params: { from: string; to: string }) {
    return {
        rate: params.from === "USD" && params.to === "EUR" ? 0.92 : 1.0,
        timestamp: new Date().toISOString()
    };
}

// Mount the SOAP endpoint
const service = new WSDL({
    name: "CurrencyService",
    namespace: "urn:currency-service",
    operations: [ConvertCurrency, GetExchangeRate]
});

Router.all("/soap/currency", service.handler());
Router.get("/soap/currency?wsdl", service.wsdlDocument());
```

### Auto WSDL

The WSDL document is generated automatically from your operation decorators:

```bash
curl "http://localhost:7145/soap/currency?wsdl"
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions name="CurrencyService"
  targetNamespace="urn:currency-service"
  xmlns="http://schemas.xmlsoap.org/wsdl/"
  xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
  xmlns:tns="urn:currency-service"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema">

  <message name="ConvertCurrencyRequest">
    <part name="amount" type="xsd:decimal"/>
    <part name="from" type="xsd:string"/>
    <part name="to" type="xsd:string"/>
  </message>

  <message name="ConvertCurrencyResponse">
    <part name="result" type="xsd:decimal"/>
    <part name="rate" type="xsd:decimal"/>
  </message>

  <portType name="CurrencyServicePortType">
    <operation name="ConvertCurrency">
      <input message="tns:ConvertCurrencyRequest"/>
      <output message="tns:ConvertCurrencyResponse"/>
    </operation>
  </portType>

  ...
</definitions>
```

---

## 5. Calling Your Published Service

Test with a SOAP client or curl:

```bash
curl -X POST http://localhost:7145/soap/currency \
  -H "Content-Type: text/xml" \
  -H "SOAPAction: ConvertCurrency" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:tns="urn:currency-service">
  <soap:Body>
    <tns:ConvertCurrency>
      <amount>100</amount>
      <from>USD</from>
      <to>EUR</to>
    </tns:ConvertCurrency>
  </soap:Body>
</soap:Envelope>'
```

Response:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <ConvertCurrencyResponse>
      <result>92.00</result>
      <rate>0.92</rate>
    </ConvertCurrencyResponse>
  </soap:Body>
</soap:Envelope>
```

---

## 6. Exercise: Expose a Product Catalogue as a SOAP Service

Build a SOAP service with two operations: `GetProduct` and `ListProducts`.

### Requirements

1. `GetProduct` — takes `productId: string`, returns `id`, `name`, `price`, `inStock`
2. `ListProducts` — takes `category: string`, returns an array of products
3. Mount at `/soap/products` with auto WSDL at `/soap/products?wsdl`

### Test with:

```bash
# Fetch the WSDL
curl "http://localhost:7145/soap/products?wsdl"

# Call GetProduct
curl -X POST http://localhost:7145/soap/products \
  -H "Content-Type: text/xml" \
  -H "SOAPAction: GetProduct" \
  -d '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body><GetProduct><productId>1</productId></GetProduct></soap:Body>
      </soap:Envelope>'
```

---

## 7. Solution

```typescript
import { Router, WSDL, wsdl_operation } from "tina4-nodejs";

const PRODUCTS = [
    { id: "1", name: "Wireless Keyboard", category: "Electronics", price: 79.99, inStock: true },
    { id: "2", name: "Yoga Mat", category: "Fitness", price: 29.99, inStock: true },
    { id: "3", name: "Coffee Grinder", category: "Kitchen", price: 49.99, inStock: false },
    { id: "4", name: "Standing Desk", category: "Electronics", price: 549.99, inStock: true },
];

@wsdl_operation({
    name: "GetProduct",
    input: { productId: "string" },
    output: { id: "string", name: "string", price: "decimal", inStock: "boolean" }
})
async function GetProduct(params: { productId: string }) {
    const product = PRODUCTS.find(p => p.id === params.productId);
    if (!product) {
        throw new Error(`Product ${params.productId} not found`);
    }
    return { id: product.id, name: product.name, price: product.price, inStock: product.inStock };
}

@wsdl_operation({
    name: "ListProducts",
    input: { category: "string" },
    output: { products: "array" }
})
async function ListProducts(params: { category: string }) {
    const filtered = params.category
        ? PRODUCTS.filter(p => p.category.toLowerCase() === params.category.toLowerCase())
        : PRODUCTS;
    return { products: filtered };
}

const service = new WSDL({
    name: "ProductService",
    namespace: "urn:product-service",
    operations: [GetProduct, ListProducts]
});

Router.all("/soap/products", service.handler());
Router.get("/soap/products", service.wsdlDocument());  // ?wsdl returns the schema
```

---

## 8. Gotchas

### 1. SOAP is XML -- whitespace matters in some parsers

Extra whitespace inside element values can cause remote parsers to reject your response.

**Fix:** Tina4's WSDL class generates clean XML without extra whitespace. Do not manually construct SOAP envelopes.

### 2. Namespace mismatches break everything

SOAP parsers are strict about XML namespaces. A mismatch between the namespace in your request and the namespace declared in the WSDL causes a fault.

**Fix:** Always copy the namespace from the generated WSDL document into your client requests. Do not guess namespace URNs.

### 3. WSDL.load() is slow on first call

Fetching and parsing a remote WSDL on every request defeats the purpose of using a client.

**Fix:** Call `WSDL.load()` once at startup and store the result. The client instance is stateless between calls.

### 4. Decimal types lose precision in JavaScript

SOAP `decimal` values are arbitrary precision. JavaScript `number` is IEEE 754 floating point. `0.1 + 0.2 !== 0.3`.

**Fix:** For financial values, use string representation in the SOAP layer and a decimal library internally. Return values as strings formatted to the required precision.
