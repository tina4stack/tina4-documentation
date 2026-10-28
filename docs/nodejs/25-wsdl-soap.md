# WSDL / SOAP

## 1. Legacy Services Are Still Services

SOAP is not new. It is also not gone. Banks, government agencies, ERP systems, and healthcare providers expose SOAP APIs. If you integrate with any of them, you need to speak SOAP.

WSDL (Web Services Description Language) is the schema for SOAP services. It defines operations, input types, and output types in XML. You call an operation, you get XML back, you parse it.

Tina4 provides a `WSDLService` base class that publishes your own SOAP services. You write a class with normal TypeScript methods. Tina4 generates the WSDL document and handles the XML envelope plumbing. It does not ship a SOAP client: to call an external SOAP service, you post the envelope yourself with `fetch`.

---

## 2. Consuming an External SOAP Service

### Calling an Operation

```typescript
const SERVICE_URL = "https://www.dataaccess.com/webservicesserver/NumberConversion.wso";

async function numberToWords(ubiNum: number): Promise<string> {
    const envelope = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <NumberToWords xmlns="http://www.dataaccess.com/webservicesserver/">
      <ubiNum>${ubiNum}</ubiNum>
    </NumberToWords>
  </soap:Body>
</soap:Envelope>`;

    const response = await fetch(SERVICE_URL, {
        method: "POST",
        headers: { "Content-Type": "text/xml; charset=utf-8" },
        body: envelope
    });
    const xml = await response.text();

    const fault = xml.match(/<faultstring>([^<]*)<\/faultstring>/);
    if (fault) {
        throw new Error(`SOAP fault: ${fault[1]}`);
    }
    return xml.match(/<m:NumberToWordsResult>([^<]*)</)?.[1] ?? "";
}

console.log(await numberToWords(42));
// "forty two "
```

You build the SOAP envelope, `POST` it with `Content-Type: text/xml`, and read the value you need out of the XML response. For richer client features (WSDL parsing, typed calls), use a dedicated npm package.

### Handling Errors

```typescript
try {
    console.log(await numberToWords(42));
} catch (err) {
    console.error((err as Error).message);
}
```

A network failure rejects the `fetch`. A SOAP fault comes back as XML with a `<faultstring>`, which `numberToWords` turns into an `Error`.

---

## 3. The @WSDLOperation Decorator

A SOAP service is a class that extends `WSDLService`. Mark each method you want to expose with the `@WSDLOperation` decorator and describe its input and output types:

```typescript
import { WSDLService, WSDLOperation } from "tina4-nodejs";

export class PriceService extends WSDLService {
    serviceName = "PriceService";
    serviceUrl = "/soap/price";

    @WSDLOperation({
        description: "Returns the current price for a product by ID",
        input: { productId: "string" },
        output: { price: "double", currency: "string", available: "boolean" }
    })
    async GetProductPrice(productId: string) {
        const price = await lookupPrice(productId);
        return {
            price: price.amount,
            currency: price.currency,
            available: price.inStock
        };
    }
}
```

The operation name is the method name. `input` lists the parameters in the order the method takes them: each value is read from the child element of the same name and converted to its type. Each key of the object the method returns becomes an element of the response. The types are `string`, `int` / `integer`, `float`, `double` / `number` / `numeric` and `bool` / `boolean`; any other name is published as `xsd:string`.

---

## 4. Publishing a SOAP Service

Define the service in `src/app/CurrencyService.ts`:

```typescript
// src/app/CurrencyService.ts
import { WSDLService, WSDLOperation } from "tina4-nodejs";

export class CurrencyService extends WSDLService {
    serviceName = "CurrencyService";
    serviceUrl = "/soap/currency";

    @WSDLOperation({
        input: { amount: "double", from: "string", to: "string" },
        output: { result: "double", rate: "double" }
    })
    async ConvertCurrency(amount: number, from: string, to: string) {
        // Simulate a conversion
        const rate = from === "USD" && to === "EUR" ? 0.92 : 1.0;
        return {
            result: parseFloat((amount * rate).toFixed(2)),
            rate
        };
    }

    @WSDLOperation({
        input: { from: "string", to: "string" },
        output: { rate: "double", timestamp: "string" }
    })
    async GetExchangeRate(from: string, to: string) {
        return {
            rate: from === "USD" && to === "EUR" ? 0.92 : 1.0,
            timestamp: new Date().toISOString()
        };
    }
}

export const currencyService = new CurrencyService();
```

Then mount it with two route files. `GET` serves the WSDL document, `POST` handles SOAP requests:

```typescript
// src/routes/soap/currency/get.ts
import { currencyService } from "../../../app/CurrencyService";

export default async (req, res) => {
    return res.xml(currencyService.generateWSDL(`http://${req.headers.host}/soap/currency`));
};
```

```typescript
// src/routes/soap/currency/post.ts
import { currencyService } from "../../../app/CurrencyService";

export const secure = false;

export default async (req, res) => {
    return res.xml(await currencyService.handle(req.body as string));
};
```

`export const secure = false` opens the `POST` route to SOAP clients, which do not send a bearer token.

### Auto WSDL

The WSDL document is generated automatically from your operation decorators:

```bash
curl "http://localhost:7148/soap/currency?wsdl"
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions name="CurrencyService"
  targetNamespace="urn:CurrencyService"
  xmlns:tns="urn:CurrencyService"
  xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns="http://schemas.xmlsoap.org/wsdl/">

  <types>
    <xsd:schema targetNamespace="urn:CurrencyService">
      <xsd:element name="ConvertCurrency">
        <xsd:complexType>
          <xsd:sequence>
            <xsd:element name="amount" type="xsd:double"/>
            <xsd:element name="from" type="xsd:string"/>
            <xsd:element name="to" type="xsd:string"/>
          </xsd:sequence>
        </xsd:complexType>
      </xsd:element>
      ...
  </types>

  <message name="ConvertCurrencyInput">
    <part name="parameters" element="tns:ConvertCurrency"/>
  </message>
  ...

  <portType name="CurrencyServicePortType">
    <operation name="ConvertCurrency">
      <input message="tns:ConvertCurrencyInput"/>
      <output message="tns:ConvertCurrencyOutput"/>
    </operation>
    ...
  </portType>

  ...
</definitions>
```

The target namespace is `urn:` followed by `serviceName`.

---

## 5. Calling Your Published Service

Test with a SOAP client or curl:

```bash
curl -X POST http://localhost:7148/soap/currency \
  -H "Content-Type: text/xml" \
  -H "SOAPAction: ConvertCurrency" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:tns="urn:CurrencyService">
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
<result>92</result>
<rate>0.92</rate>
</ConvertCurrencyResponse>
</soap:Body>
</soap:Envelope>
```

---

## 6. Exercise: Expose a Product Catalogue as a SOAP Service

Build a SOAP service with two operations: `GetProduct` and `ListProducts`.

### Requirements

1. `GetProduct` - takes `productId: string`, returns `id`, `name`, `price`, `inStock`
2. `ListProducts` - takes `category: string`, returns the IDs of the matching products, one `<productIds>` element each
3. Mount at `/soap/products` with auto WSDL at `/soap/products?wsdl`

### Test with:

```bash
# Fetch the WSDL
curl "http://localhost:7148/soap/products?wsdl"

# Call GetProduct
curl -X POST http://localhost:7148/soap/products \
  -H "Content-Type: text/xml" \
  -H "SOAPAction: GetProduct" \
  -d '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body><GetProduct><productId>1</productId></GetProduct></soap:Body>
      </soap:Envelope>'
```

---

## 7. Solution

```typescript
// src/app/ProductService.ts
import { WSDLService, WSDLOperation } from "tina4-nodejs";

const PRODUCTS = [
    { id: "1", name: "Wireless Keyboard", category: "Electronics", price: 79.99, inStock: true },
    { id: "2", name: "Yoga Mat", category: "Fitness", price: 29.99, inStock: true },
    { id: "3", name: "Coffee Grinder", category: "Kitchen", price: 49.99, inStock: false },
    { id: "4", name: "Standing Desk", category: "Electronics", price: 549.99, inStock: true },
];

export class ProductService extends WSDLService {
    serviceName = "ProductService";
    serviceUrl = "/soap/products";

    @WSDLOperation({
        input: { productId: "string" },
        output: { id: "string", name: "string", price: "double", inStock: "boolean" }
    })
    async GetProduct(productId: string) {
        const product = PRODUCTS.find(p => p.id === productId);
        if (!product) {
            throw new Error(`Product ${productId} not found`);
        }
        return { id: product.id, name: product.name, price: product.price, inStock: product.inStock };
    }

    @WSDLOperation({
        input: { category: "string" },
        output: { productIds: "string" }
    })
    async ListProducts(category: string) {
        const filtered = category
            ? PRODUCTS.filter(p => p.category.toLowerCase() === category.toLowerCase())
            : PRODUCTS;
        return { productIds: filtered.map(p => p.id) };
    }
}

export const productService = new ProductService();
```

```typescript
// src/routes/soap/products/get.ts
import { productService } from "../../../app/ProductService";

export default async (req, res) => {
    return res.xml(productService.generateWSDL(`http://${req.headers.host}/soap/products`));  // ?wsdl returns the schema
};
```

```typescript
// src/routes/soap/products/post.ts
import { productService } from "../../../app/ProductService";

export const secure = false;

export default async (req, res) => {
    return res.xml(await productService.handle(req.body as string));
};
```

An array value is returned as one element per item, so `ListProducts` answers with a `<productIds>` element for each match.

---

## 8. Gotchas

### 1. SOAP is XML -- whitespace matters in some parsers

Extra whitespace inside element values can cause remote parsers to reject your response.

**Fix:** `WSDLService` generates clean XML without extra whitespace. Do not manually construct SOAP envelopes.

### 2. Namespace mismatches break everything

SOAP parsers are strict about XML namespaces. A mismatch between the namespace in your request and the namespace declared in the WSDL causes a fault.

**Fix:** Always copy the namespace from the generated WSDL document into your client requests. Do not guess namespace URNs.

### 3. SOAP requests get a 401

**Problem:** The WSDL loads, but every SOAP call returns `401 Unauthorized`.

**Cause:** `POST` routes require a bearer token by default, and SOAP clients do not send one.

**Fix:** Add `export const secure = false;` to the `post.ts` route file.

### 4. Decimal types lose precision in JavaScript

SOAP `decimal` values are arbitrary precision. JavaScript `number` is IEEE 754 floating point. `0.1 + 0.2 !== 0.3`.

**Fix:** For financial values, use string representation in the SOAP layer and a decimal library internally. Return values as strings formatted to the required precision.
