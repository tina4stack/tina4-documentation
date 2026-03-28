# Chapter 7: WebSockets

## Real-Time Without Polling

Your Delphi application displays a dashboard with live metrics. The user stares at the numbers. Nothing moves. They click refresh. The numbers update. They stare again. They click refresh again.

This is HTTP. You ask, the server answers, the connection closes. If you want fresh data, you ask again. Polling every 5 seconds works, but it is wasteful -- 90% of those requests return the same data. It hammers the server. It wastes bandwidth. And the user still sees data that is up to 5 seconds stale.

WebSocket is the fix. One connection opens. It stays open. The server pushes data the instant it changes. The client pushes messages back. No request/response cycle. No polling interval. No stale data.

TTina4WebSocketClient brings WebSocket to your Delphi FMX applications with RFC 6455 compliance, automatic reconnection, ping/pong keepalive, and event-driven message handling. Drop it on a form, set a URL, connect, and start receiving real-time data.

---

## 1. TTina4WebSocketClient Overview

The WebSocket client handles the full RFC 6455 protocol:

- **Full-duplex communication** -- send and receive simultaneously over a single TCP connection
- **Auto-reconnect** -- configurable reconnection with backoff when the connection drops
- **Ping/pong keepalive** -- automatic heartbeat to detect dead connections
- **Text and binary messages** -- handle both message types
- **Event-driven** -- OnConnected, OnMessage, OnDisconnected, OnError callbacks

### Component Setup

Drop a `TTina4WebSocketClient` on your form from the Tina4 palette, or create it at runtime:

```pascal
uses
  Tina4WebSocketClient;

var
  WSClient: TTina4WebSocketClient;
begin
  WSClient := TTina4WebSocketClient.Create(Self);
  WSClient.URL := 'wss://api.example.com/ws';
end;
```

---

## 2. Basic Connection

### Design-Time Configuration

Set properties in the Object Inspector:

| Property | Value |
|---|---|
| `URL` | `wss://api.example.com/ws` |
| `AutoReconnect` | `True` |
| `ReconnectInterval` | `5000` (ms) |
| `PingInterval` | `30000` (ms) |

### Runtime Connection

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  Tina4WebSocket1.URL := 'wss://api.example.com/ws';
  Tina4WebSocket1.AutoReconnect := True;
  Tina4WebSocket1.ReconnectInterval := 5000;

  Tina4WebSocket1.OnConnected := WebSocketConnected;
  Tina4WebSocket1.OnMessage := WebSocketMessage;
  Tina4WebSocket1.OnDisconnected := WebSocketDisconnected;
  Tina4WebSocket1.OnError := WebSocketError;

  Tina4WebSocket1.Connect;
end;
```

### Event Handlers

```pascal
procedure TForm1.WebSocketConnected(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    LabelStatus.Text := 'Connected';
    LabelStatus.TextSettings.FontColor := TAlphaColorRec.Green;
  end);
end;

procedure TForm1.WebSocketMessage(Sender: TObject; const AMessage: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    MemoMessages.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' ' + AMessage);
  end);
end;

procedure TForm1.WebSocketDisconnected(Sender: TObject; const ACode: Integer;
  const AReason: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    LabelStatus.Text := 'Disconnected: ' + AReason;
    LabelStatus.TextSettings.FontColor := TAlphaColorRec.Red;
  end);
end;

procedure TForm1.WebSocketError(Sender: TObject; const AError: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    MemoMessages.Lines.Add('ERROR: ' + AError);
  end);
end;
```

---

## 3. Sending Messages

### Send Text

```pascal
procedure TForm1.ButtonSendClick(Sender: TObject);
begin
  Tina4WebSocket1.Send(EditMessage.Text);
  EditMessage.Text := '';
end;
```

### Send JSON

```pascal
procedure TForm1.SendJSON;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('type', 'subscribe');
    Obj.AddPair('channel', 'notifications');
    Obj.AddPair('userId', TJSONNumber.Create(1001));

    Tina4WebSocket1.Send(Obj.ToString);
  finally
    Obj.Free;
  end;
end;
```

### Check Connection Before Sending

```pascal
procedure TForm1.SafeSend(const AMessage: string);
begin
  if Tina4WebSocket1.IsConnected then
    Tina4WebSocket1.Send(AMessage)
  else
    ShowMessage('Not connected to server');
end;
```

---

## 4. Auto-Reconnect Behavior

When the connection drops, TTina4WebSocketClient automatically attempts to reconnect if `AutoReconnect` is `True`.

### Configuration

```pascal
Tina4WebSocket1.AutoReconnect := True;
Tina4WebSocket1.ReconnectInterval := 5000;  // 5 seconds between attempts
```

### Reconnect Flow

```
Connected -> Connection Lost -> Wait 5s -> Reconnect Attempt 1
  -> Fail -> Wait 5s -> Reconnect Attempt 2
  -> Success -> Connected
```

### Handling Reconnection in Code

```pascal
procedure TForm1.WebSocketConnected(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    LabelStatus.Text := 'Connected';

    // Re-subscribe to channels after reconnection
    var Sub := TJSONObject.Create;
    try
      Sub.AddPair('type', 'subscribe');
      Sub.AddPair('channel', 'updates');
      Tina4WebSocket1.Send(Sub.ToString);
    finally
      Sub.Free;
    end;
  end);
end;
```

The OnConnected event fires every time the connection opens -- including after a reconnect. Use it to re-subscribe to channels or re-authenticate.

---

## 5. Ping/Pong Keepalive

WebSocket connections can silently die -- a router drops the connection, a firewall times it out, the server crashes. Without keepalive, your client thinks it is still connected while the connection is actually dead.

TTina4WebSocketClient sends periodic ping frames. If the server does not respond with a pong within a timeout, the connection is considered dead and reconnection begins.

```pascal
Tina4WebSocket1.PingInterval := 30000;  // Send ping every 30 seconds
```

You do not need to handle pings manually. The component manages the ping/pong protocol internally.

---

## 6. Binary vs Text Messages

WebSocket supports two frame types: text and binary. TTina4WebSocketClient handles both.

### Text Messages

Most WebSocket APIs use text frames with JSON payloads:

```pascal
procedure TForm1.WebSocketMessage(Sender: TObject; const AMessage: string);
var
  JSON: TJSONObject;
begin
  JSON := StrToJSONObject(AMessage);
  if Assigned(JSON) then
  try
    var MsgType := JSON.GetValue<String>('type', '');

    TThread.Synchronize(nil, procedure
    begin
      if MsgType = 'price_update' then
        UpdatePriceDisplay(JSON)
      else if MsgType = 'notification' then
        ShowNotification(JSON)
      else if MsgType = 'error' then
        HandleServerError(JSON);
    end);
  finally
    JSON.Free;
  end;
end;
```

### Binary Messages

For binary data (images, files, protocol buffers), use the binary message event:

```pascal
procedure TForm1.WebSocketBinaryMessage(Sender: TObject; const AData: TBytes);
begin
  TThread.Synchronize(nil, procedure
  begin
    // Save binary data to file
    var Stream := TFileStream.Create('received_data.bin', fmCreate);
    try
      Stream.WriteBuffer(AData[0], Length(AData));
    finally
      Stream.Free;
    end;
  end);
end;
```

---

## 7. Disconnecting

### Graceful Close

```pascal
procedure TForm1.ButtonDisconnectClick(Sender: TObject);
begin
  Tina4WebSocket1.AutoReconnect := False;  // Prevent reconnection
  Tina4WebSocket1.Disconnect;
end;
```

### Cleanup on Form Destroy

```pascal
procedure TForm1.FormDestroy(Sender: TObject);
begin
  Tina4WebSocket1.AutoReconnect := False;
  if Tina4WebSocket1.IsConnected then
    Tina4WebSocket1.Disconnect;
end;
```

---

## 8. Complete Example: Real-Time Chat Client

Build a chat application that connects to a WebSocket server, sends and receives messages, and displays them in an HTML renderer with online status.

### Form Layout

Place these components on your form:

- `TTina4WebSocketClient` (Tina4WebSocket1)
- `TTina4HTMLRender` (HTMLRender1) -- displays chat messages
- `TEdit` (EditMessage) -- message input
- `TButton` (ButtonSend) -- send button
- `TEdit` (EditUsername) -- username input
- `TButton` (ButtonConnect) -- connect/disconnect
- `TLabel` (LabelStatus) -- connection status

### Implementation

```pascal
unit ChatForm;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Memo, FMX.Layouts,
  Tina4WebSocketClient, Tina4HTMLRender, Tina4Core;

type
  TFormChat = class(TForm)
    Tina4WebSocket1: TTina4WebSocketClient;
    HTMLRender1: TTina4HTMLRender;
    EditMessage: TEdit;
    ButtonSend: TButton;
    EditUsername: TEdit;
    ButtonConnect: TButton;
    LabelStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ButtonConnectClick(Sender: TObject);
    procedure ButtonSendClick(Sender: TObject);
    procedure EditMessageKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
  private
    FChatHistory: TStringList;
    FOnlineUsers: TStringList;
    FIsConnected: Boolean;
    procedure OnWSOpen(Sender: TObject);
    procedure OnWSMessage(Sender: TObject; const AMessage: string);
    procedure OnWSClose(Sender: TObject; const ACode: Integer;
      const AReason: string);
    procedure OnWSError(Sender: TObject; const AError: string);
    procedure AddChatMessage(const AUser, AMessage, ATime: string;
      AIsOwn: Boolean);
    procedure RefreshChatDisplay;
    procedure UpdateOnlineStatus;
  end;

var
  FormChat: TFormChat;

implementation

{$R *.fmx}

procedure TFormChat.FormCreate(Sender: TObject);
begin
  FChatHistory := TStringList.Create;
  FOnlineUsers := TStringList.Create;
  FIsConnected := False;

  Tina4WebSocket1.AutoReconnect := True;
  Tina4WebSocket1.ReconnectInterval := 3000;
  Tina4WebSocket1.PingInterval := 25000;

  Tina4WebSocket1.OnConnected := OnWSOpen;
  Tina4WebSocket1.OnMessage := OnWSMessage;
  Tina4WebSocket1.OnDisconnected := OnWSClose;
  Tina4WebSocket1.OnError := OnWSError;

  ButtonSend.Enabled := False;
  LabelStatus.Text := 'Disconnected';

  // Show empty chat
  RefreshChatDisplay;
end;

procedure TFormChat.FormDestroy(Sender: TObject);
begin
  Tina4WebSocket1.AutoReconnect := False;
  if Tina4WebSocket1.IsConnected then
    Tina4WebSocket1.Disconnect;
  FChatHistory.Free;
  FOnlineUsers.Free;
end;

procedure TFormChat.ButtonConnectClick(Sender: TObject);
begin
  if FIsConnected then
  begin
    Tina4WebSocket1.AutoReconnect := False;
    Tina4WebSocket1.Disconnect;
  end
  else
  begin
    if EditUsername.Text.Trim.IsEmpty then
    begin
      ShowMessage('Please enter a username');
      Exit;
    end;

    Tina4WebSocket1.URL := 'wss://chat.example.com/ws';
    Tina4WebSocket1.AutoReconnect := True;
    Tina4WebSocket1.Connect;
    LabelStatus.Text := 'Connecting...';
  end;
end;

procedure TFormChat.OnWSOpen(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    FIsConnected := True;
    LabelStatus.Text := 'Connected';
    ButtonConnect.Text := 'Disconnect';
    ButtonSend.Enabled := True;
    EditUsername.Enabled := False;

    // Send join message
    var JoinMsg := TJSONObject.Create;
    try
      JoinMsg.AddPair('type', 'join');
      JoinMsg.AddPair('username', EditUsername.Text);
      Tina4WebSocket1.Send(JoinMsg.ToString);
    finally
      JoinMsg.Free;
    end;
  end);
end;

procedure TFormChat.OnWSMessage(Sender: TObject; const AMessage: string);
begin
  TThread.Synchronize(nil, procedure
  var
    JSON: TJSONObject;
  begin
    JSON := StrToJSONObject(AMessage);
    if not Assigned(JSON) then Exit;
    try
      var MsgType := JSON.GetValue<String>('type', '');

      if MsgType = 'chat' then
      begin
        var User := JSON.GetValue<String>('username', 'Unknown');
        var Text := JSON.GetValue<String>('message', '');
        var Time := JSON.GetValue<String>('time', FormatDateTime('hh:nn', Now));
        var IsOwn := (User = EditUsername.Text);

        AddChatMessage(User, Text, Time, IsOwn);
      end
      else if MsgType = 'user_list' then
      begin
        FOnlineUsers.Clear;
        var Users := JSON.GetValue<TJSONArray>('users');
        if Assigned(Users) then
          for var I := 0 to Users.Count - 1 do
            FOnlineUsers.Add(Users.Items[I].Value);
        UpdateOnlineStatus;
      end
      else if MsgType = 'user_joined' then
      begin
        var User := JSON.GetValue<String>('username', '');
        if not FOnlineUsers.Contains(User) then
          FOnlineUsers.Add(User);
        AddChatMessage('System', User + ' joined the chat', '', False);
        UpdateOnlineStatus;
      end
      else if MsgType = 'user_left' then
      begin
        var User := JSON.GetValue<String>('username', '');
        var Idx := FOnlineUsers.IndexOf(User);
        if Idx >= 0 then
          FOnlineUsers.Delete(Idx);
        AddChatMessage('System', User + ' left the chat', '', False);
        UpdateOnlineStatus;
      end;
    finally
      JSON.Free;
    end;
  end);
end;

procedure TFormChat.OnWSClose(Sender: TObject; const ACode: Integer;
  const AReason: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    FIsConnected := False;
    LabelStatus.Text := 'Disconnected';
    ButtonConnect.Text := 'Connect';
    ButtonSend.Enabled := False;
    EditUsername.Enabled := True;
    FOnlineUsers.Clear;
    UpdateOnlineStatus;
  end);
end;

procedure TFormChat.OnWSError(Sender: TObject; const AError: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    AddChatMessage('System', 'Error: ' + AError, '', False);
  end);
end;

procedure TFormChat.ButtonSendClick(Sender: TObject);
begin
  if EditMessage.Text.Trim.IsEmpty then Exit;
  if not Tina4WebSocket1.IsConnected then Exit;

  var Msg := TJSONObject.Create;
  try
    Msg.AddPair('type', 'chat');
    Msg.AddPair('message', EditMessage.Text.Trim);
    Tina4WebSocket1.Send(Msg.ToString);
  finally
    Msg.Free;
  end;

  EditMessage.Text := '';
  EditMessage.SetFocus;
end;

procedure TFormChat.EditMessageKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
    ButtonSendClick(Sender);
end;

procedure TFormChat.AddChatMessage(const AUser, AMessage, ATime: string;
  AIsOwn: Boolean);
var
  Alignment, BgColor, TextColor: string;
begin
  if AIsOwn then
  begin
    Alignment := 'right';
    BgColor := '#1abc9c';
    TextColor := 'white';
  end
  else if AUser = 'System' then
  begin
    Alignment := 'center';
    BgColor := '#f0f0f0';
    TextColor := '#666';
  end
  else
  begin
    Alignment := 'left';
    BgColor := '#ecf0f1';
    TextColor := '#333';
  end;

  FChatHistory.Add(Format(
    '<div style="text-align: %s; margin: 5px 0;">' +
    '  <div style="display: inline-block; background: %s; color: %s; ' +
    '    padding: 8px 12px; border-radius: 12px; max-width: 70%%;">' +
    '    <small><strong>%s</strong> %s</small><br>%s' +
    '  </div>' +
    '</div>',
    [Alignment, BgColor, TextColor, AUser, ATime, AMessage]));

  RefreshChatDisplay;
end;

procedure TFormChat.RefreshChatDisplay;
begin
  HTMLRender1.HTML.Text :=
    '<div style="font-family: Arial, sans-serif; padding: 10px;">' +
    '<h3 style="color: #2c3e50; border-bottom: 1px solid #eee; padding-bottom: 5px;">Chat</h3>' +
    FChatHistory.Text +
    '</div>';
end;

procedure TFormChat.UpdateOnlineStatus;
begin
  // Update status label with online user count
  if FOnlineUsers.Count > 0 then
    LabelStatus.Text := Format('Connected (%d online)', [FOnlineUsers.Count])
  else if FIsConnected then
    LabelStatus.Text := 'Connected'
  else
    LabelStatus.Text := 'Disconnected';
end;

end.
```

---

## 9. Complete Example: Live Data Feed

Build a real-time price feed that connects to a WebSocket server, receives price updates, and displays them with color-coded changes.

### Implementation

```pascal
unit PriceFeedForm;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.JSON,
  System.Generics.Collections, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.StdCtrls, FMX.Layouts,
  Tina4WebSocketClient, Tina4HTMLRender, Tina4Core;

type
  TPriceInfo = record
    Symbol: string;
    Price: Double;
    PrevPrice: Double;
    Change: Double;
    ChangePercent: Double;
    LastUpdate: TDateTime;
  end;

  TFormPriceFeed = class(TForm)
    Tina4WebSocket1: TTina4WebSocketClient;
    HTMLRender1: TTina4HTMLRender;
    ButtonConnect: TButton;
    LabelStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ButtonConnectClick(Sender: TObject);
  private
    FPrices: TDictionary<string, TPriceInfo>;
    procedure OnWSOpen(Sender: TObject);
    procedure OnWSMessage(Sender: TObject; const AMessage: string);
    procedure OnWSClose(Sender: TObject; const ACode: Integer;
      const AReason: string);
    procedure OnWSError(Sender: TObject; const AError: string);
    procedure UpdatePriceDisplay;
    function GetChangeColor(AChange: Double): string;
    function GetChangeArrow(AChange: Double): string;
  end;

var
  FormPriceFeed: TFormPriceFeed;

implementation

{$R *.fmx}

procedure TFormPriceFeed.FormCreate(Sender: TObject);
begin
  FPrices := TDictionary<string, TPriceInfo>.Create;

  Tina4WebSocket1.URL := 'wss://feeds.example.com/prices';
  Tina4WebSocket1.AutoReconnect := True;
  Tina4WebSocket1.ReconnectInterval := 5000;
  Tina4WebSocket1.PingInterval := 20000;

  Tina4WebSocket1.OnConnected := OnWSOpen;
  Tina4WebSocket1.OnMessage := OnWSMessage;
  Tina4WebSocket1.OnDisconnected := OnWSClose;
  Tina4WebSocket1.OnError := OnWSError;

  LabelStatus.Text := 'Disconnected';
  UpdatePriceDisplay;
end;

procedure TFormPriceFeed.FormDestroy(Sender: TObject);
begin
  Tina4WebSocket1.AutoReconnect := False;
  if Tina4WebSocket1.IsConnected then
    Tina4WebSocket1.Disconnect;
  FPrices.Free;
end;

procedure TFormPriceFeed.ButtonConnectClick(Sender: TObject);
begin
  if Tina4WebSocket1.IsConnected then
  begin
    Tina4WebSocket1.AutoReconnect := False;
    Tina4WebSocket1.Disconnect;
    ButtonConnect.Text := 'Connect';
  end
  else
  begin
    Tina4WebSocket1.AutoReconnect := True;
    Tina4WebSocket1.Connect;
    LabelStatus.Text := 'Connecting...';
    ButtonConnect.Text := 'Disconnect';
  end;
end;

procedure TFormPriceFeed.OnWSOpen(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    LabelStatus.Text := 'Connected - Receiving prices';

    // Subscribe to price updates
    var Sub := TJSONObject.Create;
    try
      Sub.AddPair('type', 'subscribe');
      var Symbols := TJSONArray.Create;
      Symbols.Add('BTC-USD');
      Symbols.Add('ETH-USD');
      Symbols.Add('AAPL');
      Symbols.Add('GOOGL');
      Symbols.Add('MSFT');
      Sub.AddPair('symbols', Symbols);
      Tina4WebSocket1.Send(Sub.ToString);
    finally
      Sub.Free;
    end;
  end);
end;

procedure TFormPriceFeed.OnWSMessage(Sender: TObject; const AMessage: string);
begin
  TThread.Synchronize(nil, procedure
  var
    JSON: TJSONObject;
    Info: TPriceInfo;
  begin
    JSON := StrToJSONObject(AMessage);
    if not Assigned(JSON) then Exit;
    try
      var MsgType := JSON.GetValue<String>('type', '');

      if MsgType = 'price' then
      begin
        var Symbol := JSON.GetValue<String>('symbol', '');
        var NewPrice := JSON.GetValue<Double>('price', 0);

        if FPrices.TryGetValue(Symbol, Info) then
        begin
          Info.PrevPrice := Info.Price;
          Info.Price := NewPrice;
          Info.Change := NewPrice - Info.PrevPrice;
          if Info.PrevPrice > 0 then
            Info.ChangePercent := (Info.Change / Info.PrevPrice) * 100
          else
            Info.ChangePercent := 0;
        end
        else
        begin
          Info.Symbol := Symbol;
          Info.Price := NewPrice;
          Info.PrevPrice := NewPrice;
          Info.Change := 0;
          Info.ChangePercent := 0;
        end;

        Info.LastUpdate := Now;
        FPrices.AddOrSetValue(Symbol, Info);
        UpdatePriceDisplay;
      end;
    finally
      JSON.Free;
    end;
  end);
end;

procedure TFormPriceFeed.OnWSClose(Sender: TObject; const ACode: Integer;
  const AReason: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    LabelStatus.Text := 'Disconnected - Reconnecting...';
    ButtonConnect.Text := 'Connect';
  end);
end;

procedure TFormPriceFeed.OnWSError(Sender: TObject; const AError: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    LabelStatus.Text := 'Error: ' + AError;
  end);
end;

function TFormPriceFeed.GetChangeColor(AChange: Double): string;
begin
  if AChange > 0 then
    Result := '#27ae60'
  else if AChange < 0 then
    Result := '#e74c3c'
  else
    Result := '#666';
end;

function TFormPriceFeed.GetChangeArrow(AChange: Double): string;
begin
  if AChange > 0 then
    Result := '&#9650;'  // up triangle
  else if AChange < 0 then
    Result := '&#9660;'  // down triangle
  else
    Result := '&#9644;'; // dash
end;

procedure TFormPriceFeed.UpdatePriceDisplay;
var
  HTML: TStringBuilder;
  Pair: TPair<string, TPriceInfo>;
begin
  HTML := TStringBuilder.Create;
  try
    HTML.AppendLine('<div style="font-family: Arial, sans-serif; padding: 15px;">');
    HTML.AppendLine('<h2 style="color: #2c3e50;">Live Price Feed</h2>');
    HTML.AppendLine('<table style="width: 100%; border-collapse: collapse;">');
    HTML.AppendLine('<thead>');
    HTML.AppendLine('<tr style="background: #2c3e50; color: white;">');
    HTML.AppendLine('  <th style="padding: 10px; text-align: left;">Symbol</th>');
    HTML.AppendLine('  <th style="padding: 10px; text-align: right;">Price</th>');
    HTML.AppendLine('  <th style="padding: 10px; text-align: right;">Change</th>');
    HTML.AppendLine('  <th style="padding: 10px; text-align: right;">%</th>');
    HTML.AppendLine('  <th style="padding: 10px; text-align: right;">Updated</th>');
    HTML.AppendLine('</tr>');
    HTML.AppendLine('</thead>');
    HTML.AppendLine('<tbody>');

    for Pair in FPrices do
    begin
      var Color := GetChangeColor(Pair.Value.Change);
      var Arrow := GetChangeArrow(Pair.Value.Change);

      HTML.AppendFormat(
        '<tr style="border-bottom: 1px solid #eee;">' +
        '  <td style="padding: 10px; font-weight: bold;">%s</td>' +
        '  <td style="padding: 10px; text-align: right; font-size: 1.1em;">$%.2f</td>' +
        '  <td style="padding: 10px; text-align: right; color: %s;">%s %.2f</td>' +
        '  <td style="padding: 10px; text-align: right; color: %s;">%.2f%%</td>' +
        '  <td style="padding: 10px; text-align: right; color: #999; font-size: 0.85em;">%s</td>' +
        '</tr>',
        [Pair.Value.Symbol, Pair.Value.Price, Color, Arrow,
         Abs(Pair.Value.Change), Color, Pair.Value.ChangePercent,
         FormatDateTime('hh:nn:ss', Pair.Value.LastUpdate)]);
    end;

    HTML.AppendLine('</tbody>');
    HTML.AppendLine('</table>');

    if FPrices.Count = 0 then
      HTML.AppendLine('<p style="color: #999; text-align: center; padding: 40px;">Waiting for price data...</p>');

    HTML.AppendLine('</div>');

    HTMLRender1.HTML.Text := HTML.ToString;
  finally
    HTML.Free;
  end;
end;

end.
```

---

## 10. Exercise: Notification System

**Build a notification system** with these requirements:

1. Connect to a WebSocket server at `wss://api.example.com/notifications`
2. Receive notifications as JSON with `id`, `title`, `message`, `type` (info, warning, error), and `timestamp` fields
3. Display notifications as toast-style messages in an HTML renderer
4. Show a badge counter of unread notifications
5. Clicking a notification marks it as read (send `{"type": "mark_read", "id": "..."}` back to the server)
6. Notifications fade out after 10 seconds unless marked as read manually

### Solution

```pascal
unit NotificationForm;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.JSON,
  System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Layouts,
  FMX.Objects,
  Tina4WebSocketClient, Tina4HTMLRender, Tina4Core;

type
  TNotification = record
    ID: string;
    Title: string;
    Message: string;
    NotifType: string;  // info, warning, error
    Timestamp: TDateTime;
    IsRead: Boolean;
  end;

  TFormNotifications = class(TForm)
    Tina4WebSocket1: TTina4WebSocketClient;
    HTMLRender1: TTina4HTMLRender;
    LabelBadge: TLabel;
    LabelStatus: TLabel;
    TimerFade: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TimerFadeTimer(Sender: TObject);
  private
    FNotifications: TList<TNotification>;
    procedure OnWSOpen(Sender: TObject);
    procedure OnWSMessage(Sender: TObject; const AMessage: string);
    procedure OnWSClose(Sender: TObject; const ACode: Integer;
      const AReason: string);
    procedure RefreshDisplay;
    procedure UpdateBadge;
    procedure MarkAsRead(const AID: string);
    function GetTypeColor(const AType: string): string;
    function GetTypeIcon(const AType: string): string;
    function UnreadCount: Integer;
  end;

var
  FormNotifications: TFormNotifications;

implementation

{$R *.fmx}

procedure TFormNotifications.FormCreate(Sender: TObject);
begin
  FNotifications := TList<TNotification>.Create;

  Tina4WebSocket1.URL := 'wss://api.example.com/notifications';
  Tina4WebSocket1.AutoReconnect := True;
  Tina4WebSocket1.ReconnectInterval := 5000;
  Tina4WebSocket1.PingInterval := 30000;
  Tina4WebSocket1.OnConnected := OnWSOpen;
  Tina4WebSocket1.OnMessage := OnWSMessage;
  Tina4WebSocket1.OnDisconnected := OnWSClose;

  // Timer checks for notifications older than 10 seconds
  TimerFade.Interval := 2000;
  TimerFade.Enabled := True;

  // Register click handler for mark-as-read
  HTMLRender1.RegisterObject('Notif', Self);

  Tina4WebSocket1.Connect;
  LabelStatus.Text := 'Connecting...';
  UpdateBadge;
  RefreshDisplay;
end;

procedure TFormNotifications.FormDestroy(Sender: TObject);
begin
  Tina4WebSocket1.AutoReconnect := False;
  if Tina4WebSocket1.IsConnected then
    Tina4WebSocket1.Disconnect;
  FNotifications.Free;
end;

procedure TFormNotifications.OnWSOpen(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    LabelStatus.Text := 'Connected';
  end);
end;

procedure TFormNotifications.OnWSMessage(Sender: TObject; const AMessage: string);
begin
  TThread.Synchronize(nil, procedure
  var
    JSON: TJSONObject;
    Notif: TNotification;
  begin
    JSON := StrToJSONObject(AMessage);
    if not Assigned(JSON) then Exit;
    try
      var MsgType := JSON.GetValue<String>('type', '');

      if (MsgType = 'notification') or (MsgType = 'info') or
         (MsgType = 'warning') or (MsgType = 'error') then
      begin
        Notif.ID := JSON.GetValue<String>('id', GetGUID);
        Notif.Title := JSON.GetValue<String>('title', 'Notification');
        Notif.Message := JSON.GetValue<String>('message', '');
        Notif.NotifType := JSON.GetValue<String>('type', 'info');
        Notif.Timestamp := Now;
        Notif.IsRead := False;

        FNotifications.Insert(0, Notif);  // Newest first
        UpdateBadge;
        RefreshDisplay;
      end;
    finally
      JSON.Free;
    end;
  end);
end;

procedure TFormNotifications.OnWSClose(Sender: TObject; const ACode: Integer;
  const AReason: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    LabelStatus.Text := 'Reconnecting...';
  end);
end;

procedure TFormNotifications.TimerFadeTimer(Sender: TObject);
var
  Changed: Boolean;
  I: Integer;
begin
  Changed := False;

  // Remove unread notifications older than 10 seconds
  for I := FNotifications.Count - 1 downto 0 do
  begin
    var Notif := FNotifications[I];
    if (not Notif.IsRead) and (SecondsBetween(Now, Notif.Timestamp) > 10) then
    begin
      Notif.IsRead := True;
      FNotifications[I] := Notif;
      Changed := True;
    end;
  end;

  if Changed then
  begin
    UpdateBadge;
    RefreshDisplay;
  end;
end;

procedure TFormNotifications.MarkAsRead(const AID: string);
var
  I: Integer;
begin
  for I := 0 to FNotifications.Count - 1 do
  begin
    var Notif := FNotifications[I];
    if Notif.ID = AID then
    begin
      Notif.IsRead := True;
      FNotifications[I] := Notif;

      // Notify the server
      if Tina4WebSocket1.IsConnected then
      begin
        var Msg := TJSONObject.Create;
        try
          Msg.AddPair('type', 'mark_read');
          Msg.AddPair('id', AID);
          Tina4WebSocket1.Send(Msg.ToString);
        finally
          Msg.Free;
        end;
      end;

      UpdateBadge;
      RefreshDisplay;
      Break;
    end;
  end;
end;

function TFormNotifications.UnreadCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FNotifications.Count - 1 do
    if not FNotifications[I].IsRead then
      Inc(Result);
end;

procedure TFormNotifications.UpdateBadge;
var
  Count: Integer;
begin
  Count := UnreadCount;
  if Count > 0 then
  begin
    LabelBadge.Text := Count.ToString;
    LabelBadge.Visible := True;
  end
  else
    LabelBadge.Visible := False;
end;

function TFormNotifications.GetTypeColor(const AType: string): string;
begin
  if AType = 'error' then
    Result := '#e74c3c'
  else if AType = 'warning' then
    Result := '#f39c12'
  else
    Result := '#3498db';
end;

function TFormNotifications.GetTypeIcon(const AType: string): string;
begin
  if AType = 'error' then
    Result := '&#10060;'
  else if AType = 'warning' then
    Result := '&#9888;'
  else
    Result := '&#8505;';
end;

procedure TFormNotifications.RefreshDisplay;
var
  HTML: TStringBuilder;
  Notif: TNotification;
begin
  HTML := TStringBuilder.Create;
  try
    HTML.AppendLine('<div style="font-family: Arial, sans-serif; padding: 10px;">');
    HTML.AppendLine('<h3 style="color: #2c3e50;">Notifications</h3>');

    if FNotifications.Count = 0 then
    begin
      HTML.AppendLine('<p style="color: #999; text-align: center; padding: 30px;">No notifications</p>');
    end
    else
    begin
      for Notif in FNotifications do
      begin
        var Color := GetTypeColor(Notif.NotifType);
        var Icon := GetTypeIcon(Notif.NotifType);
        var Opacity: string;
        if Notif.IsRead then
          Opacity := '0.5'
        else
          Opacity := '1.0';

        HTML.AppendFormat(
          '<div style="border-left: 4px solid %s; padding: 10px 15px; margin: 8px 0; ' +
          '  background: white; border-radius: 0 4px 4px 0; opacity: %s; ' +
          '  box-shadow: 0 1px 3px rgba(0,0,0,0.1); cursor: pointer;" ' +
          '  onclick="Notif:MarkAsRead(''%s'')">' +
          '  <div style="display: flex; justify-content: space-between;">' +
          '    <strong>%s %s</strong>' +
          '    <small style="color: #999;">%s</small>' +
          '  </div>' +
          '  <p style="margin: 5px 0 0; color: #555;">%s</p>' +
          '  %s' +
          '</div>',
          [Color, Opacity, Notif.ID, Icon, Notif.Title,
           FormatDateTime('hh:nn:ss', Notif.Timestamp),
           Notif.Message,
           IfThen(not Notif.IsRead,
             '<small style="color: ' + Color + ';">Click to mark as read</small>', '')]);
      end;
    end;

    HTML.AppendLine('</div>');
    HTMLRender1.HTML.Text := HTML.ToString;
  finally
    HTML.Free;
  end;
end;

end.
```

---

## Common Gotchas

**Connection lifecycle.** The WebSocket connection runs on a background thread. Every event handler fires on that background thread. If you touch any UI control without `TThread.Synchronize`, your application will crash with access violations, or worse, silently corrupt UI state. Always wrap UI updates:

```pascal
// Wrong -- will crash
procedure TForm1.OnWSMessage(Sender: TObject; const AMessage: string);
begin
  Label1.Text := AMessage;  // Access violation!
end;

// Right
procedure TForm1.OnWSMessage(Sender: TObject; const AMessage: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    Label1.Text := AMessage;
  end);
end;
```

**Thread safety with shared data.** If your message handler writes to a `TList` or `TDictionary` that the UI thread also reads, you need synchronization. The simplest approach is to do everything inside `TThread.Synchronize`. For high-frequency messages, consider a thread-safe queue.

**Reconnect re-subscription.** When auto-reconnect opens a new connection, the server does not remember your subscriptions from the previous connection. Always re-subscribe in the `OnConnected` handler:

```pascal
procedure TForm1.OnWSOpen(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    // This runs on every connect, including reconnects
    Tina4WebSocket1.Send('{"type": "subscribe", "channel": "updates"}');
  end);
end;
```

**Memory management with TJSONObject.** Every `TJSONObject` or `TJSONArray` you create from parsing must be freed. In the message handler, parse once, extract what you need, free immediately:

```pascal
procedure TForm1.OnWSMessage(Sender: TObject; const AMessage: string);
var
  JSON: TJSONObject;
begin
  JSON := StrToJSONObject(AMessage);
  if not Assigned(JSON) then Exit;
  try
    // Extract values here
    var Name := JSON.GetValue<String>('name', '');
    // Use the values...
  finally
    JSON.Free;  // Always free
  end;
end;
```

**Disconnect before destroy.** Always disconnect the WebSocket before the form is destroyed. If the background thread tries to fire an event after the form is freed, you get a use-after-free crash:

```pascal
procedure TForm1.FormDestroy(Sender: TObject);
begin
  Tina4WebSocket1.AutoReconnect := False;  // Stop reconnection first
  if Tina4WebSocket1.IsConnected then
    Tina4WebSocket1.Disconnect;
end;
```

**Secure connections (WSS).** For `wss://` URLs, you need the same OpenSSL DLLs required for HTTPS REST calls. Without them, the connection will fail silently. See the Installation chapter for SSL setup details.
