# Chapter 25: WSDL / SOAP

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
  service_name "CalculatorService"
  namespace    "http://example.com/calculator"
  description  "Basic arithmetic operations"

  wsdl_operation :add,
    params: { a: :integer, b: :integer },
    returns: :integer do |params|
    params[:a] + params[:b]
  end

  wsdl_operation :subtract,
    params: { a: :integer, b: :integer },
    returns: :integer do |params|
    params[:a] - params[:b]
  end

  wsdl_operation :multiply,
    params: { a: :float, b: :float },
    returns: :float do |params|
    params[:a] * params[:b]
  end

  wsdl_operation :divide,
    params: { a: :float, b: :float },
    returns: :float do |params|
    raise "Division by zero" if params[:b] == 0
    params[:a] / params[:b]
  end
end
```

---

## 4. Mounting the Service

Mount the WSDL service at a path using the router.

```ruby
# src/routes/soap.rb
Tina4::Router.mount_wsdl("/soap/calculator", CalculatorService)
```

This creates two endpoints:

- `GET /soap/calculator?wsdl` -- serves the generated WSDL XML document
- `POST /soap/calculator` -- handles incoming SOAP requests

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
  targetNamespace="http://example.com/calculator"
  xmlns="http://schemas.xmlsoap.org/wsdl/"
  xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
  xmlns:tns="http://example.com/calculator"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema">

  <message name="addRequest">
    <part name="a" type="xsd:integer"/>
    <part name="b" type="xsd:integer"/>
  </message>
  <message name="addResponse">
    <part name="result" type="xsd:integer"/>
  </message>

  <portType name="CalculatorServicePortType">
    <operation name="add">
      <input message="tns:addRequest"/>
      <output message="tns:addResponse"/>
    </operation>
    <!-- ... -->
  </portType>
  <!-- binding and service elements follow -->
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

## 8. Complex Types

Operations can use nested types for richer request and response shapes.

```ruby
class OrderService < Tina4::WSDL
  service_name "OrderService"
  namespace    "http://example.com/orders"

  wsdl_type :Address do
    field :street, :string
    field :city,   :string
    field :zip,    :string
    field :country, :string
  end

  wsdl_type :OrderResult do
    field :order_id,    :string
    field :status,      :string
    field :total,       :float
  end

  wsdl_operation :place_order,
    params: { customer_email: :string, shipping_address: :Address, total: :float },
    returns: :OrderResult do |params|
    {
      order_id: SecureRandom.uuid,
      status:   "pending",
      total:    params[:total]
    }
  end
end
```

---

## 9. Error Handling in Operations

Raise a standard Ruby exception to return a SOAP fault.

```ruby
wsdl_operation :divide,
  params: { a: :float, b: :float },
  returns: :float do |params|
  raise ArgumentError, "Divisor cannot be zero" if params[:b] == 0
  params[:a] / params[:b]
end
```

The caller receives:

```xml
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <soap:Fault>
      <faultcode>soap:Server</faultcode>
      <faultstring>Divisor cannot be zero</faultstring>
    </soap:Fault>
  </soap:Body>
</soap:Envelope>
```

---

## 10. Gotchas

### 1. WSDL caching in production

The remote WSDL client caches the WSDL after the first fetch. If the remote service updates its WSDL, restart your app or call `client.reload_wsdl` to force a refresh.

### 2. Character encoding

SOAP envelopes must be UTF-8. If your operation returns strings with special characters, ensure they are UTF-8 encoded before returning.

### 3. Namespace conflicts

Each WSDL service must have a unique namespace. Duplicate namespaces across mounted services cause client-side parsing errors.

### 4. SOAP is not REST

SOAP uses `POST` for every operation, including reads. Do not expect `GET` requests to trigger SOAP operations -- only the `?wsdl` query param uses `GET`.
