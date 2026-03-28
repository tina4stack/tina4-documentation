# Chapter 8: Socket Server

## Raw TCP Without the Ceremony

Sometimes WebSocket is too much. You don't need HTTP upgrade handshakes, frame masking, or RFC 6455 compliance. You need a raw TCP socket that listens on a port and handles bytes. A hardware device sends telemetry. A legacy system speaks a custom protocol. A game server needs low-latency binary messaging.

TTina4SocketServer is the answer. Drop it on a form, set a host and port, flip `Active` to `True`, and handle incoming bytes in the `OnMessage` event. The component manages the listener thread, accepts connections, and dispatches messages -- you focus on your protocol.

---

## 1. TTina4SocketServer Overview

The socket server provides:

- **TCP and UDP support** -- choose the socket type for your use case
- **Async accept loop** -- runs in a background task, never blocks your UI
- **Per-connection processing** -- each client gets its own receive loop
- **Event-driven messages** -- `OnMessage` fires with the client socket and raw bytes
- **Simple lifecycle** -- `Active := True` to start, `Active := False` to stop

### Component Setup

Drop a `TTina4SocketServer` from the Tina4Delphi palette onto your form, or create it at runtime:

```pascal
uses
  Tina4SocketServer, System.Net.Socket;

var
  Server: TTina4SocketServer;
begin
  Server := TTina4SocketServer.Create(Self);
  Server.Host := '0.0.0.0';
  Server.Port := 9000;
  Server.SocketType := TSocketType.TCP;
  Server.OnMessage := HandleMessage;
  Server.Active := True;
end;
```

---

## 2. Properties

Set these in the Object Inspector or at runtime:

| Property | Type | Default | Description |
|---|---|---|---|
| `Host` | `String` | `''` | Bind address. Use `0.0.0.0` for all interfaces, `127.0.0.1` for localhost only |
| `Port` | `Integer` | `0` | Port number to listen on |
| `SocketType` | `TSocketType` | `TCP` | `TSocketType.TCP` or `TSocketType.UDP` |
| `Active` | `Boolean` | `False` | Set `True` to start listening, `False` to stop |
| `OnMessage` | `TTina4SocketEvent` | `nil` | Event handler fired when data arrives from a client |

### Event Signature

```pascal
type
  TTina4SocketEvent = procedure(const Client: TSocket; Content: TBytes) of object;
```

The `Client` parameter is the connected client's socket -- use it to send responses back. `Content` is the raw bytes received.

---

## 3. Basic TCP Server

### Design-Time Setup

1. Drop `TTina4SocketServer` on your form
2. Set `Host` to `0.0.0.0`
3. Set `Port` to `9000`
4. Set `SocketType` to `TCP`
5. Double-click `OnMessage` to create the event handler
6. Set `Active` to `True`

### Handling Messages

```pascal
procedure TForm1.Tina4SocketServer1Message(const Client: TSocket; Content: TBytes);
var
  Text: string;
  Response: TBytes;
begin
  // Decode incoming bytes to string
  Text := TEncoding.UTF8.GetString(Content);
  Memo1.Lines.Add('Received: ' + Text);

  // Send a response back to the client
  Response := TEncoding.UTF8.GetBytes('ACK: ' + Text);
  Client.Send(Response);
end;
```

### Starting and Stopping

```pascal
procedure TForm1.btnStartClick(Sender: TObject);
begin
  Tina4SocketServer1.Host := '0.0.0.0';
  Tina4SocketServer1.Port := StrToInt(edtPort.Text);
  Tina4SocketServer1.Active := True;
  lblStatus.Text := 'Listening on port ' + edtPort.Text;
end;

procedure TForm1.btnStopClick(Sender: TObject);
begin
  Tina4SocketServer1.Active := False;
  lblStatus.Text := 'Stopped';
end;
```

---

## 4. Practical Examples

### Echo Server

The simplest possible server -- sends back whatever it receives:

```pascal
procedure TForm1.Tina4SocketServer1Message(const Client: TSocket; Content: TBytes);
begin
  Client.Send(Content);
end;
```

### JSON Command Server

Parse incoming JSON commands and respond with JSON:

```pascal
uses
  JSON;

procedure TForm1.Tina4SocketServer1Message(const Client: TSocket; Content: TBytes);
var
  Request, Response: TJSONObject;
  Command: string;
begin
  try
    Request := TJSONObject.ParseJSONValue(Content, 0, Length(Content)) as TJSONObject;
    try
      Command := Request.GetValue<string>('command');

      Response := TJSONObject.Create;
      try
        if Command = 'ping' then
        begin
          Response.AddPair('status', 'pong');
          Response.AddPair('timestamp', DateTimeToStr(Now));
        end
        else if Command = 'status' then
        begin
          Response.AddPair('status', 'ok');
          Response.AddPair('clients', TJSONNumber.Create(1));
          Response.AddPair('uptime', FormatDateTime('hh:nn:ss', Now - FStartTime));
        end
        else
          Response.AddPair('error', 'unknown command: ' + Command);

        Client.Send(TEncoding.UTF8.GetBytes(Response.ToJSON));
      finally
        Response.Free;
      end;
    finally
      Request.Free;
    end;
  except
    on E: Exception do
      Client.Send(TEncoding.UTF8.GetBytes('{"error":"' + E.Message + '"}'));
  end;
end;
```

### Telemetry Receiver

Receive fixed-size binary packets from a hardware device:

```pascal
type
  TTelemetryPacket = packed record
    DeviceID: UInt16;
    Temperature: Single;
    Humidity: Single;
    BatteryPct: Byte;
  end;

procedure TForm1.Tina4SocketServer1Message(const Client: TSocket; Content: TBytes);
var
  Packet: TTelemetryPacket;
begin
  if Length(Content) >= SizeOf(TTelemetryPacket) then
  begin
    Move(Content[0], Packet, SizeOf(TTelemetryPacket));

    TThread.Synchronize(nil,
      procedure
      begin
        Memo1.Lines.Add(Format('Device %d: %.1f C, %.1f%% humidity, %d%% battery',
          [Packet.DeviceID, Packet.Temperature, Packet.Humidity, Packet.BatteryPct]));
      end);

    // Acknowledge receipt
    Client.Send(TEncoding.UTF8.GetBytes('OK'));
  end;
end;
```

---

## 5. Thread Safety

The `OnMessage` event fires on a background thread, not the main UI thread. To update UI controls, use `TThread.Synchronize` or `TThread.Queue`:

```pascal
procedure TForm1.Tina4SocketServer1Message(const Client: TSocket; Content: TBytes);
var
  Text: string;
begin
  Text := TEncoding.UTF8.GetString(Content);

  // Safe UI update from background thread
  TThread.Queue(nil,
    procedure
    begin
      Memo1.Lines.Add(Text);
    end);
end;
```

**`Synchronize`** blocks the background thread until the UI update completes -- use it when you need the result before sending a response. **`Queue`** is fire-and-forget -- use it for logging and display updates where you don't need to wait.

---

## 6. Lifecycle

The server lifecycle is controlled entirely by the `Active` property:

```
Active := True
  -> Creates TSocket with configured SocketType
  -> Calls Listen(Host, '', Port)
  -> Starts background TTask
  -> BeginAccept loop runs until stopped
  -> Each accepted client gets its own receive loop

Active := False
  -> Sets CanRun := False
  -> Cancels the background task
  -> Client connections close on next receive cycle
```

The component cleans up automatically. Setting `Active := False` stops the accept loop, and each client connection closes when its receive loop detects the shutdown flag.

---

## 7. When to Use Socket Server vs WebSocket Client

| Use Case | Component |
|---|---|
| Connect TO a WebSocket service | `TTina4WebSocketClient` |
| Accept raw TCP/UDP connections | `TTina4SocketServer` |
| Hardware device telemetry | `TTina4SocketServer` |
| Chat/notification from a web backend | `TTina4WebSocketClient` |
| Custom binary protocol | `TTina4SocketServer` |
| Browser-compatible real-time | `TTina4WebSocketClient` |

TTina4WebSocketClient is a **client** that connects outward to a WebSocket server. TTina4SocketServer is a **server** that listens for incoming TCP or UDP connections. They solve different problems and can be used together in the same application.

---

## 8. Gotchas

1. **Thread safety** -- `OnMessage` fires on a background thread. Always use `TThread.Synchronize` or `TThread.Queue` for UI updates. Forgetting this causes access violations.

2. **Blocking receive loop** -- Each client connection runs a `Sleep(1000)` receive loop. This means message latency can be up to 1 second. For sub-second requirements, consider the WebSocket client instead.

3. **No TLS** -- The raw socket server does not support TLS/SSL. For encrypted connections, terminate TLS at a reverse proxy or use the WebSocket client which supports `wss://`.

4. **Port conflicts** -- Ensure your chosen port is not already in use. On mobile platforms (Android/iOS), binding to low ports (below 1024) may require special permissions.

5. **Firewall** -- When deploying, ensure the server port is open in the OS firewall and any network firewalls between client and server.
