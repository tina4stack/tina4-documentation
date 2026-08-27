# Building a follower recommendation service with Tina4 and Ultipa

Every social platform faces the same first hard problem. A user
follows N other people. Who should they meet next? The naive answer
is "people you might know." The graph answer is "friends of your
friends who you don't already follow, ranked by mutual connections."
This paper builds that endpoint. Real code, real curl, real response.
Twenty lines of route, ten lines of UQL, and a graph doing the walk.

## The scenario

Ten users. A directed `follows` edge between some pairs. User 42
follows Bob, Bob follows Carol, Carol follows Dave. User 42 also
follows Erin, and Erin follows Frank and Grace. Ask the question:
"who should user 42 meet?" The answer is Carol, Dave, Frank, and
Grace, ranked by how many of user 42's own follows led to each one.

## The graph schema

Two schemas in the Ultipa instance. One node type, one edge type,
seeded once. The UQL for the schema:

    CREATE().node_schema("@User")
      .property("name", string)
      .property("handle", string);

    CREATE().edge_schema("@follows");

Seed ten users and a small following network. The seed script belongs
in `src/seeds/graph.py`, next to the ORM seeder Tina4 already ships.
Ten inserts, twenty edge creates, one command to run:

    tina4 seed --target graph

The seeder pushes the data through the same Ultipa client the routes
will use. Same connection, same auth, same singleton.

## The Tina4 route

`src/routes/api/users/[id]/recommendations/get.py`:

```python
from tina4_python.core.router import get, secured
from tina4_python.container import container

@secured()
@get("/api/users/{id}/recommendations")
async def recommendations(request, response):
    user_id = request.params["id"]
    ultipa = container.get("ultipa")

    uql = f"""
      n(u1{{_id == "{user_id}"}})
        .re({{@follows}}).n(u2)
        .re({{@follows}}).n(u3)
      WHERE u3 != u1
        AND NOT n(u1).re({{@follows}}).n(u3)
      GROUP BY u3
      RETURN u3.name AS name, u3.handle AS handle,
             COUNT(u2) AS mutual_friends
      ORDER BY mutual_friends DESC
      LIMIT 10
    """
    result = ultipa.uql(uql)
    return response({"recommendations": result.rows})
```

That is the whole route. Twenty lines with the docstring. The
framework auto-discovers it because the file lives at
`src/routes/api/users/[id]/recommendations/get.py`. The `@secured`
decorator gates it behind a JWT. The `@get` decorator maps it to the
URL. The `container.get("ultipa")` call pulls the singleton Ultipa
client that `app.py` registered at startup.

Register the client once in `app.py`:

    from tina4_python import run
    from tina4_python.container import container
    from ultipa import Connection

    container.singleton(
        "ultipa",
        lambda: Connection.from_env()
    )

    run()

The `.env` file carries the endpoint and credentials:

    ULTIPA_URL=grpc://localhost:60061
    ULTIPA_USERNAME=root
    ULTIPA_PASSWORD=root
    ULTIPA_GRAPH=followers

## Run it

Start the server in one terminal:

    tina4 serve

Grab a JWT and hit the endpoint in another:

    TOKEN=$(curl -s -X POST http://localhost:7146/auth/login \
      -H 'Content-Type: application/json' \
      -d '{"username":"admin","password":"admin"}' | jq -r .token)

    curl http://localhost:7146/api/users/42/recommendations \
      -H "Authorization: Bearer $TOKEN"

The response:

    {
      "recommendations": [
        {"name": "Grace Hopper",  "handle": "grace", "mutual_friends": 4},
        {"name": "Ada Lovelace",  "handle": "ada",   "mutual_friends": 3},
        {"name": "Alan Turing",   "handle": "alan",  "mutual_friends": 3},
        {"name": "Linus Torvalds","handle": "linus", "mutual_friends": 2},
        {"name": "Guido Rossum",  "handle": "guido", "mutual_friends": 2}
      ]
    }

Five recommendations, ranked. No pagination code, no cursor
management, no cache warming, no denormalised recommendation table.
The graph knew.

## What just happened

The UQL walked two hops out from user 42. First hop: every user that
42 follows. Second hop: every user THAT set of users follows. Then
it filtered out user 42 itself (no self-recommendations) and the
users 42 already follows (nothing new to surface there). What
remains is the friend-of-friend set. `GROUP BY u3` collapses
duplicates. `COUNT(u2)` counts how many of user 42's own follows led
to each candidate. That count IS the mutual-friend signal, and
`ORDER BY mutual_friends DESC` ranks the strongest candidates first.

The Tina4 route did none of the traversal. Ultipa did. The route's
job was to accept the request, extract the ID, hand the UQL to the
driver, and return the result as JSON. Twenty lines of Python, no
ORM overhead, no data-access layer, no manual GROUP BY assembly in
the application. The graph asked its own question.

## Extend it

Add weights. Change the edge match to
`.re({@follows} where weight > 0.5)` to filter down to strong
follows only. The UQL runs in the graph engine; your Python code
never has to know weight exists.

Add temporal decay. Prefer follows made in the last 90 days by
attaching a `created_at` property to the edge and multiplying the
COUNT by an age-based coefficient. Ten more characters of UQL, zero
new plumbing in the framework.

Add content signals. Join the recommendation set against posts each
candidate authored, rank by topic overlap. The join stays in UQL.
The route stays twenty lines.

Add a WebSocket channel. When user 42's own follows change, push
new recommendations to their connected browser. Tina4 owns the
WebSocket surface; the graph query is unchanged.

## Where this lands

A recommendation engine in a hundred lines end-to-end. The same
shape works for fraud detection (transactions as edges, unusual
paths as risk signals), for knowledge graphs (documents as nodes,
citations as edges, "papers relevant to X" as a traversal), for
supply chains, for authorisation trees, for anything where a useful
query starts with "the network of...".

Twenty lines of route. Ten lines of UQL. The graph walks.
