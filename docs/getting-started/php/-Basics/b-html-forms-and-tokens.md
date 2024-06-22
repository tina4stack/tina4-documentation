# HTML forms and tokens

Post routes and events are protected by `formTokens` and Authorization headers. That means that forms need to submit a `formToken` variable with the other inputs in order to pass the security test.
Tokens have an expiry time as well so will be invalidated if they expire.

## Sign up form

Consider the following sign up form which can be placed under `src/templates`. If you hit the Sign Up button the form submits but you get a `403 error`. This means we need to add a form token.

**sign-up.twig**
```html
<!DOCTYPE html>
<html>
<head>
<title>Sign Up</title>
</head>
<body>
    <form name="sign-up" method="post" action="/sign-up">
        <input type="text" name="email" placeholder="Email">
        <input type="text" name="firstName" placeholder="First Name">
        <button>Sign Up</button>
    </form>
</body>
</html>
```

## Sign up form with a formToken

We can modify the form as follows, once we submit it the screen should show the form again.  Tina4 submits the post request to the server and if we haven't defined a post route it will render the same screen again but with the input
from the form passed in a request variable. We can validate this by dumping the `request` variable.

**sign-up.twig**
```html
<!DOCTYPE html>
<html>
<head>
<title>Sign Up</title>
</head>
<body>
    <form name="sign-up" method="post" action="/sign-up">
        <input type="text" name="email" placeholder="Email">
        <input type="text" name="firstName" placeholder="First Name">
        <button>Sign Up</button>
        {{ "sign up form" | formToken }}
    </form>
</body>
</html>
```

## Form with a dump of the request variables

We can add the dump the request variable to see the result

```html
<!DOCTYPE html>
<html>
<head>
<title>Sign Up</title>
</head>
<body>
    <form name="sign-up" method="post" action="/sign-up">
        <input type="text" name="email" placeholder="Email">
        <input type="text" name="firstName" placeholder="First Name">
        <button>Sign Up</button>
        {{ "sign up form" | formToken }}
        {{ dump(request) }}
    </form>
</body>
</html>
```

