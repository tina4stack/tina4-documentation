# Password Hashing and Validation

We have included this functionality in tina4_python to assist in hashing and validating passwords.

## Hashing a password

```python
from tina4_python import Debug, tina4_auth
password = tina4_auth.hash_password("password1234!")
Debug.info("Password hash for", "password1234!", "is", password)
```

## Validating a password

Consider the following example which takes a request object as its input param from a post route
The password in the `request.body` is checked against the hash in the database.

```python
from tina4_python import tina4_auth
tina4_auth.check_password(user_record["password"], request.body["password"])
```

```python title="get_user_login"
def get_user_login(request):
        # sets the session to be logged out
        request.session.set("logged_in", False)
        
        # check for the email value in the request.body
        if "email" in request.body:
            # check for the password value in the request.body
            if "password" in request.body:
                # get the user from the database based on the email address
                user_record = dba.fetch_one("select * from user where email = ?", [request.body["email"]])
                # validate the password
                if user_record is not None and tina4_auth.check_password(user_record["password"],request.body["password"]):
                    user_record["password"] = ""
                    Debug(user_record, request.session.session_values)
                    request.session.set("user_data", user_record)

                    request.session.save()
                    return True
                else:
                    Debug("User failed password check", TINA4_LOG_ERROR)
                    # add password fail check
                    return False
            else:
                return False
        else:

            return False
```

!!! tip "Hot Tips"
    - Don't store plain text passwords in your database
