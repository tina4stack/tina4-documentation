# Setting Up a Project

::: tip
Tina4 Delphi is a design-time component library for Delphi 10.4+ (FireMonkey / FMX). Drop components on your form, configure properties in the Object Inspector, and you're ready to go.
:::

## Requirements {#requirements}

- **Delphi 10.4+** (FireMonkey / FMX)
- **FireDAC** components (included with Delphi)
## SSL Setup {#ssl}

For HTTPS support in REST calls, you need OpenSSL DLLs:

- Extract **32-bit** SSL DLLs to `C:\Windows\SysWOW64` (required for the IDE)
- Extract **64-bit** SSL DLLs to `C:\Windows\System32` (required for your compiled applications)

## Installation {#installation}

1. Clone or download the repository:
```bash
git clone https://github.com/tina4stack/tina4delphi.git
```

2. Open the **Tina4DelphiProject** project group in the Delphi IDE

3. Build and install **Tina4Delphi** (the runtime package) first

4. Build and install **Tina4DelphiDesign** (the design-time package)

5. The Tina4 components will appear in the **Tina4** tool palette

## Components {#components}

After installation, these components are available in the Tina4 palette:

| Component | Unit | Description |
|---|---|---|
| `TTina4REST` | Tina4REST | REST client configuration (base URL, auth, headers) |
| `TTina4RESTRequest` | Tina4RESTRequest | Executes REST calls and populates MemTables |
| `TTina4JSONAdapter` | Tina4JSONAdapter | Populates a MemTable from JSON |
| `TTina4HTMLRender` | Tina4HTMLRender | FMX control that renders HTML to canvas |
| `TTina4HTMLPages` | Tina4HTMLPages | Design-time page navigation |
| `TTina4Twig` | Tina4Twig | Twig-style template engine |

## Next Steps

- [REST Client](rest-client.md) -- consume external APIs
- [HTML Renderer](html-render.md) -- render HTML in your FMX app
- [Twig Templates](twig.md) -- dynamic template rendering
