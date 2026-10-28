# WSDL / SOAP

## 1. When the World Still Uses SOAP

REST gets all the attention. But banks, government portals, insurance systems, and ERP platforms built in the 2000s still speak SOAP. You need to call a mortgage calculation service. Your payment processor publishes a WSDL. Your government tax API requires SOAP envelopes.

Tina4's WSDL module lets you expose your own operations as a SOAP service and call remote WSDL services from Ruby.

---

## 2. What SOAP and WSDL Are

**SOAP** (Simple Object Access Protocol) sends XML envelopes over HTTP. A request wraps parameters in XML. The response wraps results in XML.

**WSDL** (Web Services Description Language) is the machine-readable contract that describes what operations a SOAP service exposes, what parameters each operation accepts, and what it returns. Clients parse the WSDL to know how to call the service.

A WSDL service call looks like this at the wire level:

```xml
POST /soap/calculator HTTP/1.1
Content-Type: text/xml

<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <Add>
      <a>14</a>
      <b>28</b>
    </Add>
  </soap:Body>
</soap:Envelope>
```

Response:

```xml
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <AddResponse>
      <result>42</result>
    </AddResponse>
  </soap:Body>
</soap:Envelope>
```

Tina4 handles all of this XML generation and parsing for you.

---

## 3. Defining a WSDL Service

Create a WSDL service class that inherits from `Tina4::WSDL` and defines operations.

```ruby
# src/services/calculator_service.rb

class CalculatorService < Tina4::WSDL
  wsdl_operation output: { result: :int }
  def add(a, b)
    { result: a.to_i + b.to_i }
  end

  wsdl_operation output: { result: :int }
  def subtract(a, b)
    { result: a.to_i - b.to_i }
  end

  wsdl_operation output: { result: :float }
  def multiply(a, b)
    { result: a.to_f * b.to_f }
  end

  wsdl_operation output: { result: :float }
  def divide(a, b)
    raise "Division by zero" if b.to_f.zero?
    { result: a.to_f / b.to_f }
  end
end
```

`wsdl_operation output:` marks the method defined next as a SOAP operation and declares the fields of its response. The operation name is the method name, and the method's parameters become the request fields, in order. Parameter values arrive as strings, so convert them before doing arithmetic. The method returns a hash whose keys match `output:`. The service is named after the class.

---

## 4. Mounting the Service

`src/services/` is not auto-loaded, so require the service from a route file and mount it on a path:

```ruby
# src/routes/soap.rb
require_relative "../services/calculator_service"

Tina4::Router.get("/soap/calculator") do |request, response|
  response.xml(CalculatorService.new(request).handle)
end

Tina4::Router.post("/soap/calculator") do |request, response|
  response.xml(CalculatorService.new(request).handle)
end.no_auth
```

`handle` looks at the request, so the same call answers both endpoints:

- `GET /soap/calculator?wsdl` -- serves the generated WSDL XML document
- `POST /soap/calculator` -- handles incoming SOAP requests

`.no_auth` opens the `POST` route to SOAP clients, which do not send a bearer token.

---

## 5. Auto-Generated WSDL

Visit `/soap/calculator?wsdl` in a browser or curl:

```bash
curl "http://localhost:7147/soap/calculator?wsdl"
```

Tina4 generates the full WSDL document from your operation definitions:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions name="CalculatorService"
  targetNamespace="urn:CalculatorService"
  xmlns:tns="urn:CalculatorService"
  xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns="http://schemas.xmlsoap.org/wsdl/">

  <types>
    <xsd:schema targetNamespace="urn:CalculatorService">
      <xsd:element name="add">
        <xsd:complexType>
          <xsd:sequence>
            <xsd:element name="a" type="xsd:string"/>
            <xsd:element name="b" type="xsd:string"/>
          </xsd:sequence>
        </xsd:complexType>
      </xsd:element>
      <xsd:element name="addResponse">
        <xsd:complexType>
          <xsd:sequence>
            <xsd:element name="result" type="xsd:int"/>
          </xsd:sequence>
        </xsd:complexType>
      </xsd:element>
      <!-- ... -->
    </xsd:schema>
  </types>

  <portType name="CalculatorServicePortType">
    <operation name="add">
      <input message="tns:addInput"/>
      <output message="tns:addOutput"/>
    </operation>
    <!-- ... -->
  </portType>
  <!-- messages, binding and service elements follow -->
</definitions>
```

The WSDL is generated dynamically. It always reflects the current operation definitions.

---

## 6. Calling the SOAP Service

```bash
curl -X POST http://localhost:7147/soap/calculator \
  -H "Content-Type: text/xml" \
  -d '
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <add>
      <a>14</a>
      <b>28</b>
    </add>
  </soap:Body>
</soap:Envelope>'
```

Response:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
<addResponse>
<result>42</result>
</addResponse>
</soap:Body>
</soap:Envelope>
```

---

## 7. Calling a Remote WSDL Service

Tina4 provides the SOAP **server** side (`Tina4::WSDL` and the `Tina4::WSDL::Service` builder). It does not ship a SOAP client. To call an external SOAP service, send the SOAP envelope yourself with the standard library or a dedicated gem.

```ruby
require "net/http"
require "uri"

uri  = URI("https://www.w3schools.com/xml/tempconvert.asmx")
body = <<~XML
  <?xml version="1.0" encoding="utf-8"?>
  <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
      <CelsiusToFahrenheit xmlns="https://www.w3schools.com/xml/">
        <Celsius>100</Celsius>
      </CelsiusToFahrenheit>
    </soap:Body>
  </soap:Envelope>
XML

response = Net::HTTP.post(
  uri, body,
  "Content-Type" => "text/xml; charset=utf-8",
  "SOAPAction"   => "https://www.w3schools.com/xml/CelsiusToFahrenheit"
)

puts response.body # parse the SOAP envelope for <CelsiusToFahrenheitResult>
```

For richer client features (WSDL parsing, type coercion), use a gem such as `savon`.

---

## 8. Several Fields and Lists

An operation can take any number of parameters and return any number of fields. Each key of the returned hash becomes an element of the response, and an Array value repeats its element once per item.

```ruby
# src/services/order_service.rb
require "securerandom"

class OrderService < Tina4::WSDL
  wsdl_operation output: { order_id: :string, status: :string, total: :float }
  def place_order(customer_email, city, total)
    {
      order_id: SecureRandom.uuid,
      status:   "pending",
      total:    total.to_f
    }
  end

  wsdl_operation output: { sku: :string }
  def list_skus(category)
    { sku: %w[KB-001 HUB-002] }
  end
end
```

Fields are flat: there are no nested complex types. Send a structure such as an address as separate parameters, the way `place_order` takes `city`.

---

## 9. Error Handling in Operations

Raise a standard Ruby exception to return a SOAP fault.

```ruby
# src/services/safe_calculator_service.rb

class SafeCalculatorService < Tina4::WSDL
  wsdl_operation output: { result: :float }
  def divide(a, b)
    raise ArgumentError, "Divisor cannot be zero" if b.to_f.zero?
    { result: a.to_f / b.to_f }
  end
end
```

The caller receives:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <soap:Fault>
      <faultcode>Server</faultcode>
      <faultstring>Internal server error</faultstring>
    </soap:Fault>
  </soap:Body>
</soap:Envelope>
```

The exception message is written to the log. It reaches the caller as the `faultstring` only when `TINA4_DEBUG=true`, so internal details stay out of production responses.

---

## 10. Gotchas

### 1. Parameters arrive as strings

**Problem:** `add` with `a = 14` and `b = 28` returns `1428`.

**Fix:** Every request field reaches your method as a String. Convert it with `to_i` or `to_f` before using it.

### 2. Character encoding

SOAP envelopes must be UTF-8, in both directions. A request body in UTF-16, or with bytes that aren't valid UTF-8, will get a `Client` fault reading "Malformed XML" before any operation runs, and so will a body that uses an entity other than the five XML defines (`&lt;` `&gt;` `&amp;` `&quot;` `&apos;`) or declares a DOCTYPE. The Python version answers the same bodies the same way. If your operation returns strings with special characters, make sure they're UTF-8 before returning.

### 3. Namespace conflicts

A service's namespace is `urn:` followed by its class name. Give each service class a unique name, or clients see duplicate namespaces and fail to parse them.

### 4. SOAP is not REST

SOAP uses `POST` for every operation, including reads. Do not expect `GET` requests to trigger SOAP operations -- only the `?wsdl` query param uses `GET`.
