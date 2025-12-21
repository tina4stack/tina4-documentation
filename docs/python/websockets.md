# Websockets

Websockets enable full-duplex, real-time communication over a single TCP connection, ideal for chat apps, live updates, or interactive features.

::: tip 🔥 Hot Tips
- Use the `Websocket` class from `tina4_python` for handling connections.
- Secure routes with `@secured()` to require authentication.
- Manage topics with a subscriber dictionary for pub/sub patterns.
- Use a tool like `websocat` to test your connections
  :::

## Implementation of a PubSub system

Define a websocket route in `src/routes/websocket.py` to handle connections, subscriptions, and messages:

```python
# src/routes/websocket.py

import json
from collections import defaultdict
from tina4_python import get,secured
from tina4_python.Websocket import Websocket

subscribers = defaultdict(set)

@get("/ws/chat")
@secured()
async def chat_ws(request, response):
    ws = await Websocket(request).connection()
    try:
        while True:
            data = await ws.receive()
            Debug.info('WEBSOCKET', data, ws)
            # actions can be publish, subscribe, unsubscribe
            # data = {"topic": "Simone", "action": "publish", "data": {}}
            try:
                json_data = json.loads(data)
                # establish a session in subscribers so we can publish
                if json_data["action"] == "subscribe":
                    subscribers[json_data["topic"]].add(ws)
                if json_data["action"] == "unsubscribe":
                    subscribers[json_data["topic"]].discard(ws)
                    if not subscribers[json_data["topic"]]:
                        del subscribers[json_data["topic"]]
                if json_data["action"] == "publish":
                    for subscriber in list(subscribers[json_data["topic"]]):
                        try:
                            await subscriber.send(json.dumps(json_data["data"]))
                        except Exception:
                            # Remove stale/closed subscriber
                            subscribers[json_data["topic"]].discard(subscriber)
            except Exception as e:
                await ws.send(f"Echo: {data} {e}")
    finally:
        # Clean up all subscriptions for this ws on disconnect
        for topic in list(subscribers.keys()):
            subscribers[topic].discard(ws)
            if not subscribers[topic]:
                del subscribers[topic]
        if ws is not None:
            await ws.close()

    pass
```

- `@get("/ws/chat")`: Registers the websocket endpoint at `/ws/chat`.
- `Websocket(request).connection()`: Establishes the websocket connection.
- Message handling: Parses JSON for actions like `subscribe`, `unsubscribe`, or `publish` to manage topics and broadcast data.
- Cleanup: Removes disconnected subscribers and closes the connection.

## Client Usage

Connect from a Python client using the `websockets` library and send JSON actions. Include a Bearer token in the Authorization header for secured routes (obtain token via default `API_KEY` in `.env`):

```python
import asyncio
import json
import websockets

async def chat_client():
    uri = "ws://localhost:7145/ws/chat"
    token = "your_bearer_token_here"  # Replace with actual token
    headers = {"Authorization": f"Bearer {token}"}
    async with websockets.connect(uri, extra_headers=headers) as websocket:
        # Subscribe to a topic
        subscribe_msg = json.dumps({"action": "subscribe", "topic": "chatroom"})
        await websocket.send(subscribe_msg)
        
        # Publish a message
        publish_msg = json.dumps({"action": "publish", "topic": "chatroom", "data": {"message": "Hello!"}})
        await websocket.send(publish_msg)
        
        # Receive messages
        while True:
            response = await websocket.recv()
            print(f"Received: {response}")

asyncio.run(chat_client())
```

- Subscribe to topics for receiving updates.
- Publish data to broadcast to all subscribers on a topic.

## Debugging

Enable debug logging with `Debug.info()` for incoming messages. Set `TINA4_DEBUG_LEVEL=Info` to control verbosity, as in general setup.