# Chapter 11: Claude Code Integration

## Let AI Write Your Delphi

You describe a form. Claude writes the Pascal. It compiles the project. It launches the app. It clicks a button to test the logic. It sees the result on screen. It fixes a bug in the event handler, recompiles, and tests again. You never left the terminal.

This is not theoretical. Tina4 Delphi ships with an MCP server that gives Claude Code direct access to the Free Pascal and Delphi compilers, the ability to generate proper project structures, and tools to interact with running desktop applications. This chapter shows you how to set it up and how to use it effectively.

---

## 1. What Is MCP

MCP stands for Model Context Protocol. It is an open standard that lets AI assistants like Claude Code interact with external tools. Instead of just reading and writing files, Claude can call tool functions -- compile code, run programs, take screenshots, click buttons.

Think of MCP as a plugin system. You install an MCP server. Claude discovers the tools it provides. When Claude needs to compile your Pascal code, it calls the `compile_pascal` tool. When it needs to see the running app, it calls the `preview_screenshot` tool. The protocol handles the communication.

Without MCP, Claude can write Delphi code. With MCP, Claude can write, compile, run, see, interact with, and debug Delphi code. The difference is the gap between writing a recipe and cooking the meal.

---

## 2. The claude-pascal-mcp Server

The MCP server ships inside the tina4delphi repository in the `claude-pascal-mcp` directory. It is a Python-based server that exposes Pascal/Delphi development tools to Claude Code.

### What the Server Provides

| Tool | What It Does |
|---|---|
| `compile_pascal` | Compile a single `.pas` file or a full Delphi project (DPR + PAS + DFM) |
| `project_template` | Generate a complete Delphi project structure with components and event handlers |
| `run_program` | Compile and execute a program, capture stdout and stderr |
| `launch_gui` | Compile and run a VCL/FMX application in the background |
| `preview_screenshot` | Capture what the running desktop app looks like via HTTP bridge |
| `click_button` | Enumerate child windows and send click messages to controls |
| `move_window` | Reposition and resize application windows |
| `type_text` | Enter text into the focused control |
| `send_keys` | Send keyboard shortcuts (Ctrl+S, Alt+F4, etc.) |
| `parse_form` | Read `.dfm`, `.fmx`, or `.lfm` files and return component structure |
| `detect_compilers` | Find Free Pascal, Delphi 7 (dcc32), and RAD Studio (dcc64) on the system |

### Installation

The server uses `uv`, a fast Python package manager. If you do not have `uv` installed:

```bash
# Install uv (macOS/Linux)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install uv (Windows)
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Then install the MCP server dependencies:

```bash
cd /path/to/tina4delphi/claude-pascal-mcp
uv sync
```

That is it. No virtual environment management, no pip install chains, no requirements.txt conflicts. `uv sync` reads the project file and installs everything.

---

## 3. Configuration

### Project-Level Configuration

Create a `.mcp.json` file in your Delphi project root:

```json
{
  "mcpServers": {
    "pascal-dev": {
      "command": "uv",
      "args": [
        "run",
        "--directory",
        "/path/to/tina4delphi/claude-pascal-mcp",
        "pascal-mcp"
      ]
    }
  }
}
```

Replace `/path/to/tina4delphi` with the actual path where you cloned the tina4delphi repository.

### Global Configuration

To make the MCP server available in all Claude Code sessions, add it to your global Claude settings:

```bash
claude mcp add pascal-dev -- uv run --directory /path/to/tina4delphi/claude-pascal-mcp pascal-mcp
```

### Verifying the Setup

Start Claude Code in your project directory and check that the tools are available:

```bash
cd /path/to/your/delphi-project
claude
```

Claude will show connected MCP servers on startup. You should see `pascal-dev` listed. Ask Claude to detect compilers:

```
What Pascal/Delphi compilers are available on this machine?
```

Claude calls `detect_compilers` and reports what it finds -- Free Pascal, Delphi 7, RAD Studio, or any combination.

---

## 4. Specifying a Compiler

The MCP server auto-detects compilers by scanning common installation paths. On Windows, it checks:

- `C:\FPC\*\bin\*\fpc.exe` for Free Pascal
- `C:\Program Files (x86)\Borland\Delphi7\Bin\dcc32.exe` for Delphi 7
- `C:\Program Files (x86)\Embarcadero\Studio\*\bin\dcc64.exe` for RAD Studio

If your compiler is installed in a non-standard location, tell Claude:

```
Compile my project using the compiler at D:\Tools\FPC\3.2.2\bin\x86_64-win64\fpc.exe
```

Claude passes the path directly to the `compile_pascal` tool. No configuration file needed.

---

## 5. Preview Bridge Setup

The preview bridge lets Claude see your running desktop application through its built-in preview panel. It works by capturing screenshots of the app window and serving them over HTTP.

Create `.claude/launch.json` in your project root:

```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "pascal-preview",
      "runtimeExecutable": "/path/to/tina4delphi/claude-pascal-mcp/.venv/Scripts/pythonw.exe",
      "runtimeArgs": ["-m", "pascal_mcp.preview_bridge"],
      "port": 18080,
      "autoPort": true
    }
  ]
}
```

On macOS or Linux, use the Python path from the virtual environment:

```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "pascal-preview",
      "runtimeExecutable": "/path/to/tina4delphi/claude-pascal-mcp/.venv/bin/python",
      "runtimeArgs": ["-m", "pascal_mcp.preview_bridge"],
      "port": 18080,
      "autoPort": true
    }
  ]
}
```

When Claude launches a GUI application, it starts the preview bridge automatically. The bridge captures screenshots of the running app and serves them at `http://localhost:18080`. Claude sees these screenshots in its preview panel and can make decisions based on what the UI looks like.

---

## 6. What Claude Can Do

### Compile Single Files

Claude can compile a standalone Pascal program:

```pascal
// hello.pas
program Hello;
begin
  WriteLn('Hello from Claude!');
end.
```

Ask Claude: "Compile and run hello.pas." Claude calls `compile_pascal` with the file path, then `run_program` to execute it. You see the output in the conversation.

### Compile Full Delphi Projects

Claude understands the Delphi project structure. Given a `.dpr` file, it compiles the entire project with all units, forms, and resources:

```pascal
// MyApp.dpr
program MyApp;

uses
  FMX.Forms,
  MainUnit in 'MainUnit.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
```

Claude resolves unit dependencies, includes form files, and passes the correct compiler flags.

### Generate Project Templates

When you ask Claude to create a new application, it uses the `project_template` tool to generate the correct project structure:

```
Create a new FMX application with a form that has a TTina4HTMLRender and a TTina4REST component.
```

Claude generates:

```
MyNewApp/
  MyNewApp.dpr          -- Project file
  MyNewApp.dproj        -- IDE project file
  MainUnit.pas          -- Main form unit
  MainUnit.fmx          -- FMX form file
```

The generated `.fmx` form includes the components you requested, correctly parented and configured. The `.pas` unit includes the corresponding field declarations and event handler stubs.

### Launch GUI Applications

Claude can compile and run GUI applications in the background:

```pascal
// MainUnit.pas
unit MainUnit;

interface

uses
  System.SysUtils, System.Classes, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.StdCtrls, FMX.Layouts;

type
  TMainForm = class(TForm)
    Button1: TButton;
    Label1: TLabel;
    procedure Button1Click(Sender: TObject);
  private
    FClickCount: Integer;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.Button1Click(Sender: TObject);
begin
  Inc(FClickCount);
  Label1.Text := 'Clicked ' + FClickCount.ToString + ' times';
end;

end.
```

Claude compiles this, launches the app, and confirms it is running. With the preview bridge active, Claude can see the window.

### Interact with Running Applications

This is where the MCP server becomes powerful. Claude does not just launch your app -- it uses it:

```
Claude, click Button1 in the running app and tell me what happens.
```

Claude calls `click_button` to find and click the button. It takes a screenshot to see the result. It reads the label text. It reports back: "The label now shows 'Clicked 1 times'."

Claude can also type into text fields:

```
Type "admin@example.com" into the email input field.
```

And send keyboard shortcuts:

```
Press Ctrl+S to trigger the save action.
```

### Parse Form Files

Claude can read and understand Delphi form files:

```
Parse the form file MainUnit.fmx and tell me what components it contains.
```

Claude calls `parse_form` and reports the component tree:

```
TMainForm (TForm)
  +-- Panel1 (TPanel)
  |   +-- Label1 (TLabel) - Text: 'Welcome'
  |   +-- Button1 (TButton) - Text: 'Click Me'
  +-- Tina4HTMLRender1 (TTina4HTMLRender)
  +-- Tina4REST1 (TTina4REST) - BaseUrl: 'https://api.example.com'
```

This lets Claude understand existing projects before modifying them.

---

## 7. Walkthrough: Building a Weather App

Let us walk through a complete vibe coding session. You will ask Claude to build a weather app from scratch, and Claude will do all the work -- writing code, compiling, running, and testing.

### Step 1: Describe What You Want

```
Build an FMX application that shows the current weather for a city.
Use TTina4HTMLRender to display the weather data as styled HTML.
Use TTina4REST to fetch data from wttr.in (a free weather API).
Add a text input for the city name and a button to fetch the weather.
```

### Step 2: Claude Generates the Project

Claude creates the project structure and writes the code:

```pascal
// WeatherApp.dpr
program WeatherApp;

uses
  FMX.Forms,
  WeatherMain in 'WeatherMain.pas' {FormWeather};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormWeather, FormWeather);
  Application.Run;
end.
```

```pascal
// WeatherMain.pas
unit WeatherMain;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls,
  FMX.Edit, FMX.Layouts,
  Tina4REST, Tina4HTMLRender;

type
  TFormWeather = class(TForm)
    LayoutTop: TLayout;
    EditCity: TEdit;
    ButtonFetch: TButton;
    Tina4REST1: TTina4REST;
    Tina4HTMLRender1: TTina4HTMLRender;
    procedure FormCreate(Sender: TObject);
    procedure ButtonFetchClick(Sender: TObject);
  private
    procedure ShowWeather(const City, Condition, TempC: string);
    procedure ShowError(const Msg: string);
  end;

var
  FormWeather: TFormWeather;

implementation

{$R *.fmx}

procedure TFormWeather.FormCreate(Sender: TObject);
begin
  Tina4REST1.BaseUrl := 'https://wttr.in';
  EditCity.Text := 'Cape Town';

  Tina4HTMLRender1.HTML.Text :=
    '<div style="padding: 20px; font-family: Arial;">' +
    '  <h2 style="color: #2c3e50;">Enter a city and click Fetch</h2>' +
    '</div>';
end;

procedure TFormWeather.ButtonFetchClick(Sender: TObject);
var
  StatusCode: Integer;
  Response: TJSONObject;
  Current: TJSONObject;
  Condition, TempC: string;
begin
  if EditCity.Text.Trim.IsEmpty then
  begin
    ShowError('Please enter a city name.');
    Exit;
  end;

  Tina4HTMLRender1.HTML.Text :=
    '<div style="padding: 20px; text-align: center;">' +
    '  <p style="color: #7f8c8d;">Loading weather data...</p>' +
    '</div>';

  try
    Response := Tina4REST1.Get(StatusCode,
      '/' + EditCity.Text.Trim + '?format=j1');
    try
      if StatusCode = 200 then
      begin
        Current := Response.GetValue<TJSONObject>('current_condition')
          .GetValue<TJSONObject>(0);
        Condition := Current.GetValue<TJSONArray>('weatherDesc')
          .Items[0].GetValue<string>('value');
        TempC := Current.GetValue<string>('temp_C');
        ShowWeather(EditCity.Text.Trim, Condition, TempC);
      end
      else
        ShowError('City not found. Status: ' + StatusCode.ToString);
    finally
      Response.Free;
    end;
  except
    on E: Exception do
      ShowError('Network error: ' + E.Message);
  end;
end;

procedure TFormWeather.ShowWeather(const City, Condition, TempC: string);
begin
  Tina4HTMLRender1.HTML.Text :=
    '<div style="padding: 20px; font-family: Arial;">' +
    '  <h2 style="color: #2c3e50;">' + City + '</h2>' +
    '  <div style="background: #ecf0f1; border-radius: 8px; ' +
    '    padding: 20px; margin-top: 10px;">' +
    '    <p style="font-size: 48px; margin: 0; color: #2980b9;">' +
    '      ' + TempC + '&deg;C</p>' +
    '    <p style="font-size: 18px; color: #7f8c8d; margin-top: 8px;">' +
    '      ' + Condition + '</p>' +
    '  </div>' +
    '</div>';
end;

procedure TFormWeather.ShowError(const Msg: string);
begin
  Tina4HTMLRender1.HTML.Text :=
    '<div style="padding: 20px; font-family: Arial;">' +
    '  <div style="background: #e74c3c; color: white; ' +
    '    padding: 15px; border-radius: 8px;">' +
    '    <p>' + Msg + '</p>' +
    '  </div>' +
    '</div>';
end;

end.
```

### Step 3: Claude Compiles and Runs

Claude compiles the project. If there are errors, it reads them, fixes the code, and recompiles. Once compilation succeeds, it launches the app.

### Step 4: Claude Tests the App

Claude types "London" into the city field, clicks Fetch, takes a screenshot, and reports: "The app shows London at 14 degrees Celsius, Partly Cloudy."

If the label layout is off or the button does not respond, Claude sees the problem, edits the code, recompiles, and tests again.

### Step 5: Iterate

```
Make the temperature larger and add a humidity reading.
Also add a dropdown with preset cities: Cape Town, London, Tokyo, New York.
```

Claude modifies the code, recompiles, relaunches, and verifies. Each iteration takes seconds.

---

## 8. Walkthrough: Modifying an Existing Form

You have an existing project. You want Claude to add features without breaking what works.

### Step 1: Let Claude Understand the Project

```
Read the form file MainUnit.fmx and the unit MainUnit.pas.
Tell me what the app currently does.
```

Claude parses both files and gives you a summary: which components exist, what events are wired, what the app does when you click each button.

### Step 2: Request a Change

```
Add a new button called ButtonExport that exports the MemTable data to a CSV file.
Wire up the click event. The file should be saved to the user's Documents folder.
```

### Step 3: Claude Modifies the Files

Claude edits the `.fmx` form to add the button component:

```
object ButtonExport: TButton
  Position.X = 220.000000000000000000
  Position.Y = 10.000000000000000000
  Width = 120.000000000000000000
  Height = 32.000000000000000000
  Text = 'Export CSV'
  OnClick = ButtonExportClick
end
```

Claude edits the `.pas` unit to add the field declaration and event handler:

```pascal
procedure TMainForm.ButtonExportClick(Sender: TObject);
var
  FileName: string;
  SL: TStringList;
  I, J: Integer;
begin
  FileName := TPath.Combine(TPath.GetDocumentsPath, 'export.csv');
  SL := TStringList.Create;
  try
    // Header row
    var Header := '';
    for I := 0 to FDMemTable1.FieldCount - 1 do
    begin
      if I > 0 then Header := Header + ',';
      Header := Header + FDMemTable1.Fields[I].FieldName;
    end;
    SL.Add(Header);

    // Data rows
    FDMemTable1.First;
    while not FDMemTable1.Eof do
    begin
      var Row := '';
      for J := 0 to FDMemTable1.FieldCount - 1 do
      begin
        if J > 0 then Row := Row + ',';
        Row := Row + '"' + FDMemTable1.Fields[J].AsString.Replace('"', '""') + '"';
      end;
      SL.Add(Row);
      FDMemTable1.Next;
    end;

    SL.SaveToFile(FileName);
    ShowMessage('Exported to ' + FileName);
  finally
    SL.Free;
  end;
end;
```

### Step 4: Claude Compiles and Tests

Claude compiles the modified project. It launches the app, loads some data, clicks the Export button, and confirms the CSV file was created.

---

## 9. Tips for Effective AI-Assisted Delphi Development

### Be Specific About Components

Bad prompt:
```
Make a form that shows data.
```

Good prompt:
```
Create an FMX form with TTina4REST connected to https://api.example.com.
Add a TTina4RESTRequest that fetches /products into an FDMemTable.
Display the data in a TTina4HTMLRender using a Twig template
with a table showing name, price, and category columns.
```

The more specific you are about which Tina4 components to use, the better the generated code.

### Reference Existing Code

```
Look at how CustomerForm.pas uses TTina4RESTRequest and apply
the same pattern to build a ProductForm.
```

Claude reads your existing code and replicates the patterns. Your codebase stays consistent.

### Let Claude Fix Its Own Mistakes

When compilation fails, do not fix it yourself. Paste the error or just say:

```
Fix the compilation errors.
```

Claude reads the compiler output, understands the error, and fixes it. This is faster than you doing it because Claude remembers every line it wrote.

### Use the Preview Bridge for Visual Feedback

With the preview bridge running, Claude can verify visual layout:

```
The stats cards should be in a horizontal row, not stacked vertically.
Fix the layout.
```

Claude takes a screenshot, sees the problem, adjusts the HTML/CSS in the TTina4HTMLRender, recompiles, and checks again.

### Keep Your CLAUDE.md Updated

Create a `CLAUDE.md` in your project root that describes:

- Which compiler to use
- Where your templates live
- What API endpoints your app connects to
- Any project-specific conventions

```markdown
# My Delphi Project

## Build
- Compiler: RAD Studio 12 (dcc64)
- Platform: Win64
- Project file: src/MyApp.dpr

## Conventions
- All REST endpoints are in DataModule1
- HTML templates are in the templates/ directory
- Use TTina4HTMLRender for all UI rendering
- Use Twig templates, not raw HTML strings
```

Claude reads this file first and follows your conventions from the start.

---

## 10. Exercise: Build a Calculator from Scratch

Set up the MCP server and use Claude Code to build a calculator application. Do not write any code yourself. Use only natural language prompts.

### Requirements

1. FMX application with a TTina4HTMLRender for the display
2. HTML buttons for digits 0-9, operators (+, -, *, /), equals, and clear
3. Use `onclick` RTTI calls from HTML buttons to Pascal methods
4. Support chained operations (2 + 3 * 4 should work left-to-right)
5. Display the current expression and result

### Suggested Prompts

Start with:
```
Create a new FMX calculator app. Use TTina4HTMLRender for the entire UI.
Render calculator buttons as an HTML grid. Wire onclick events using
RTTI to call Pascal methods. Show the current expression at the top.
```

Then iterate:
```
The buttons are too small. Make them 60x60 pixels with larger font.
Add a decimal point button.
Handle division by zero gracefully.
```

### Solution

The solution is not code you write. The solution is the conversation with Claude. By the end, you should have:

- A working calculator app compiled and running
- HTML-rendered buttons that call Pascal methods via RTTI
- Clean separation between the UI (HTML/CSS) and logic (Pascal)
- Claude having fixed at least one bug it introduced during development

The exercise is complete when the calculator handles `12.5 + 7.5 = 20` correctly and Claude has verified it by interacting with the running app.

---

## 11. Common MCP Issues

| Problem | Cause | Fix |
|---|---|---|
| Claude does not see pascal-dev tools | `.mcp.json` not in project root | Move `.mcp.json` to the directory where you run `claude` |
| `uv: command not found` | uv not installed or not in PATH | Install uv and restart your terminal |
| Compiler not found | Auto-detect failed | Tell Claude the compiler path explicitly |
| Preview bridge not starting | Wrong Python path in `launch.json` | Use the `.venv` Python, not system Python |
| GUI app launches but Claude cannot see it | Preview bridge not configured | Add `launch.json` configuration as shown in Section 5 |
| Click tool reports "window not found" | App window title changed or app closed | Relaunch the app and try again |
| Compilation fails with missing units | Search path not configured | Tell Claude which directories to include in the search path |

---

## Summary

The MCP server bridges the gap between AI code generation and AI code verification. Claude does not just write Delphi code and hope it works. It compiles, runs, sees, interacts, and iterates. The feedback loop that used to require a human switching between IDE and terminal now happens inside a single conversation.

Set up the MCP server once. Use it on every project. The time you invest in the five-minute setup pays back on the first non-trivial feature Claude builds for you.
