# Websockets

We have integrated websocket functionality directly into our routing environment using the `simple-websockets` package.

## Example of server side

Below is the code for a simple websocket echo server. What ever you send the websocket connection will be sent back to you.

```python
from tina4_python.Router import get
from tina4_python.Websocket import Websocket

@get("/websocket")
async def get_websocket(request, response):
    ws = await Websocket(request).connection()
    try:
        while True:
            data = await ws.receive()
            await ws.send(data)
    except Exception as e:
        pass
    return response("")
```

The above endpoint can be accessed on the same port as your webserver, [ws://localhost:7145/websocket](ws://localhost:7145/websocket)

## Client side

We have included a reconnecting websocket component in the js folder. You can use whatever library or client you want.

```html
<script src="/js/reconnecting-websocket.js"></script>
<script>
    socket = new ReconnectingWebSocket("ws://{{ request.headers.host }}/websocket");
    socket.send("Hello World!");

    // Do something when connected
    socket.addEventListener("open", (event) => {
        console.log("Websocket connected!");
        socket.send("Ping!"); //FYI this will cause an infinite loop of communication because the listener will respond!
    });

    // Listen for messages
    socket.addEventListener("message", (event) => {
        console.log("Message from server ", event.data);
        socket.send('Received!')
    });
</script>

```
