# Tina4 Python – Built-in SOAP 1.1 / WSDL 1.0 Service

::: tip 🔥 Hot Tips
- Zero-configuration SOAP with auto-WSDL on `?wsdl`.
- Supports str, int, float, bool, List[T], Optional[T].
- Document/literal wrapped style; auto ArrayOfX types.
- Respects X-Forwarded-* headers; optional SERVICE_URL override.
- Hooks: on_request/on_result for custom logic.
  :::

## Initialization

Extend WSDL and define methods as operations:

```python
from tina4_python.WSDL import WSDL, wsdl_operation
from typing import List, Optional

class Calculator(WSDL):
    SERVICE_URL = "https://example.com/soap/calculator"  # Optional override

    @wsdl_operation({"Result": int})
    def Add(self, a: int, b: int):
        return {"Result": a + b}

    @wsdl_operation({
        "Numbers": List[int],
        "Total": int,
        "Error": Optional[str]
    })
    def SumList(self, Numbers: List[int]):
        return {
            "Numbers": Numbers,
            "Total": sum(Numbers),
            "Error": None
        }

    def on_request(self, request):
        # Optional: Pre-process request
        pass

    def on_result(self, result):
        # Optional: Post-process result
        return result
```

- `wsdl_operation(schema)`: Declares response structure; generates complex types.
- `SERVICE_URL`: Static override for endpoint (e.g., behind proxy).
- Methods: Public, non-underscore; auto-discovered as operations.

## Routing

Register with Tina4 decorator; handles SOAP requests and WSDL:

```python
from tina4_python.router import wsdl

@wsdl("/calculator")  # Serves /calculator?wsdl and SOAP POSTs
async def calculator_wsdl(request, response):
    return response.wsdl(Calculator(request))
```

- `wsdl(path)`: Decorator for SOAP endpoint.
- `response.wsdl(instance)`: Processes request via WSDL.handle().

## WSDL Generation

Access `http://localhost:7145/calculator?wsdl` for auto-generated XML.

- Includes types, messages, portType, binding, service.
- Registers ArrayOfX for lists; minOccurs=0/nillable for Optional.

## SOAP Requests

POST XML to endpoint; auto-converts params, handles nil.

Example Add request:

```xml
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://tempuri.org/calculator">
   <soapenv:Body>
      <tns:Add>
         <a>5</a>
         <b>3</b>
      </tns:Add>
   </soapenv:Body>
</soapenv:Envelope>
```

Response:

```xml
<?xml version='1.0' encoding='utf-8'?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://tempuri.org/calculator">
   <soapenv:Body>
      <AddResponse>
         <AddResult>
            <Result>8</Result>
         </AddResult>
      </AddResponse>
   </soapenv:Body>
</soapenv:Envelope>
```

- Lists: Repeat tags (e.g., <Numbers><item>1</item><item>2</item></Numbers>).
- Faults: Returns SOAP Fault on errors.

## Utilities

- `get_operations()`: Lists public methods as operations.
- `soap_fault(message)`: Builds fault XML.