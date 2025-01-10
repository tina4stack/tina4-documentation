# Custom Session Handler

You would only want to create your own session handler if the Redis enabled session handling built into Tina4 is not sufficient.
Fortunately this process is very simple and you only have to implement three static methods.  You would also need to declare the session handler
as soon as possible as Tina4 Webserver would want to load it in to handle the sessions.

In your `.env' or environment you would declare the session handler as such

```dotenv title=".env"
TINA4_SESSION_HANDLER=SessionFileHandler
```

## Load Balancing

If you plan to load balance your Tina4 application then using Redis or a custom session handler is essential to persist sessions over multiple server instances.


## Redis Example

Here is the code example for the Redis handler as well as it's environment variables

```dotenv title=".env"
TINA4_SESSION_HANDLER=SessionRedisHandler
TINA4_SESSION_REDIS_HOST="localhost"
TINA4_SESSION_REDIS_PORT=6379
```

You can use the following code as a pattern to write your own Session handler. We dynamically load the redis module
as we only try load it if we need it.

The methods load, save and close must be implemented to use the sessions correctly.  We are using the JWT token encoding built into Tina4 to 
serialize the session variables so that they expire and that no one can just read them if they gain access to the token.

```python title="SessionRedisHandler"
from tina4_python.Session import SessionHandler
from tina4_python.Debug import Debug

class SessionRedisHandler(SessionHandler):

    @staticmethod
    def __init_redis():
        try:
            redis = importlib.import_module("redis")
        except Exception as e:
            Debug("Redis not installed, install with pip install redis or poetry add redis", Constant.TINA4_LOG_ERROR)
            sys.exit(1)

        redis_instance = redis.Redis(host=os.getenv("TINA4_SESSION_REDIS_HOST", "localhost"), port=os.getenv("TINA4_SESSION_REDIS_PORT",6379), decode_responses=True)

        return redis_instance

    """
    Session Redis Handler
    """
    @staticmethod
    def load(session, _hash):
        """
        Loads the redis session
        :param session:
        :param _hash:
        :return:
        """
        try:
            session.session_hash = _hash
            r = SessionRedisHandler.__init_redis()
            token = r.get(_hash)
            if tina4_python.tina4_auth.valid(token):
                payload = tina4_python.tina4_auth.get_payload(token)
                for key in payload:
                    if key != "expires":
                        session.set(key, payload[key])
            else:
                Debug("Session expired, starting a new one", Constant.TINA4_LOG_DEBUG)
                session.start(_hash)
        except:
            Debug("Redis not available, sessions will fail", Constant.TINA4_LOG_ERROR)


    @staticmethod
    def close(session):
        """
        Closes the redis session
        :param session:
        :return:
        """
        r = SessionRedisHandler.__init_redis()
        try:
            r.set(session.session_hash, "")
            return True
        except:
            return False

    @staticmethod
    def save(session):
        """
        Saves the redis session
        :param session:
        :return:
        """
        r = SessionRedisHandler.__init_redis()
        try:
            token = tina4_python.tina4_auth.get_token(payload_data=session.session_values)
            r.set(session.session_hash, token)
            return True
        except Exception as e:
            Debug("Session save failure", str(e), Constant.TINA4_LOG_ERROR)
            return False

```