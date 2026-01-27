# Posting forms and Token handling

::: tip 🔥 Hot Tips
- Most route endpoints are secure by default (Not GET)
- Redirect after successful POST (Post/Redirect/Get pattern)
- Use `request.params` for form data and query data
- Tokens available in 3 ways
  :::

## Securing your routes {#secure-routes}
If you're used to posting forms in the traditional manner to the web service, then:

* All `POST`, `PUT`, `PATCH`, and `DELETE` requests are **secured by default**
* You **must** pass a `formToken` input value to be validated (CSRF protection)
* `GET` requests must be manually secured
* Invalid tokens return a `403 Forbidden` automatically.
### Standard Route Setup

```php
// Unprotected GET route
\Tina4\Get::add("/standard-get", function(\Tina4\Request $request,\Tina4\Response $response) {
    $message = "This is a standard GET route, and is unprotected";

    return $response($message, HTTP_OK, TEXT_HTML);
});

// POST route protected by default
\Tina4\Post::add("/standard-post", function(\Tina4\Request $request,\Tina4\Response $response) {
    $message = "This is a standard POST route, and is protected by default";

    return $response($message, HTTP_OK, TEXT_HTML);
});
```
### Advanced Route Setup
```php
/**
 * GET route protected by the annotation
 * @secure
 */
\Tina4\Get::add("/protected-get", function(\Tina4\Request $request,\Tina4\Response $response) {
    $message = "This is a protected GET route";

    return $response($message, HTTP_OK, TEXT_HTML);
});
```
Complex route security can be obtained by labels after the `@secure` annotation. These can be accessed in the `$request->security` array and incorporated into your security logic.
```php
/**
 * GET route protected by the annotation
 * $request->security = ["website", "api"]
 * @secure website,api
 */
\Tina4\Get::add("/protected-get", function(\Tina4\Request $request,\Tina4\Response $response) {
    $message = "This is a protected GET route";

    return $response($message, HTTP_OK, TEXT_HTML);
});
```

## Setting up the template with form tokens {#form-tokens}
```twig
<!-- templates/contact.twig -->
<form method="POST" action="/contact">
    <!-- Auto-generates <input name="formToken" value="ey..."> -->
    {{ "contactForm" | formToken }}  
    <div>
        <label for="name">Name</label>
        <input type="text" id="name" name="name" placeholder="Your name" required>
    </div>
    <div>
        <label for="email">Email</label>
        <input type="email" id="email" name="email" placeholder="your@email.com" required>
    </div>
    <div>
        <label for="message">Message</label>
        <textarea id="message" name="message" rows="5" required></textarea>
    </div>
    <button type="submit">Send Message</button>
</form>
```
### Form tokens - Twig Global Function
The twig global function generates a token which can be added to a hidden input. It can be passed a json payload, which
can be found in the `payload` parameter of the JWT token.
```twig
{% set token = formToken({"page": "login", "version":"1.01"}) %}
<input type="hidden" name="formToken" value="{{ token }}">
```
### Form tokens - Twig Filters
The twig filter is simpler to use, auto generating a hidden input field. The given name `contactForm` below, will be added to the parameter
`formName` in the JWT token payload and can be used as page specific tokens.
```twig
<!-- Auto-generates <input type="hidden" name="formToken" value="ey..."> -->
{{ "contactForm" | formToken }} 
```
### Form tokens - Response Headers
Specifically useful for ajax reponses, a `freshtoken` is supplied in the response headers. There are numerous ways to access
the `freshtoken` but will depend on how the ajax call was made, which is beyond the scope of this article. 
::: info
This is made simpler when using the [Tina4Helper.js](tina4helper.md) 
:::

## File Uploads with Forms {#upload-files}

Add `enctype="multipart/form-data"` to the form.
```twig
// For a single file upload
<form method="POST" action="/upload" enctype="multipart/form-data">
    {{ "upload" | formToken }}

    <input type="file" name="avatar" accept="image/*">
    <button type="submit">Upload Files</button>
</form>
```
Uploading multiple files requires the `multiple` attribute and an array added to the name
```twig
// For multiple file uploads
<form method="POST" action="/upload" enctype="multipart/form-data">
    {{ "upload" | formToken }}

    <input type="file" name="avatar[]" accept="image/*" multiple>
    <button type="submit">Upload Files</button>
</form>
```
The files will be available in the standard php `$_FILES` super global and in the `$request->files` parameter.
```php
\Tina4\Post::add("/upload", function(\Tina4\Request $request,\Tina4\Response $response) {
    $files = $request->files;
    
    // Process files here, depending on single or multiple uploads
    // refer to standard php documentation for file upload management

    return $response(\Tina4\renderTemplate("fileUploadResponse.twig"), HTTP_OK, TEXT_HTML);
});
```

## Validation & Error Handling {#handle-errors}

Return errors and old input on failure.

```php
\Tina4\Post::add("/register", function(\Tina4\Request $request,\Tina4\Response $response) {
    $errors = [];
    $data = $request->params;
    if (!isset($data["email"])){
        $errors["email"] = "Email is required";
    }
    if (!isset($data["password"]) && strlen($data["password"] < 8)){
        $errors["password"] = "Password must be at least 8 characters";
    }

    if (!empty($errors)){

        return $response(\Tina4\renderTemplate("register.twig", ["errors" => $errors, "old" => $data]), HTTP_OK, TEXT_HTML);
    }

   \Tina4\redirect("/dashboard");
});
```

This error data can be used in the twig to repopulate fields and deliver error messages

```twig
<form method="POST" action="/register">
    {{ "register" | formToken }}

    {% if errors %}
        <p class="error">{{ errors.email }}</p>
        <p class="error">{{ errors.password }}</p>
    {% endif %}

    <input type="text" name="email" value="{{ old.email ?? "" | e }}" required>
    <input type="password" name="password" required>

    <button>Login</button>
</form>
```

## Disabling Protection

Unlike Tina4Python, there is no `noauth` feature to switch off default route security. Should one need to create public
webhooks there are more than enough strategies to create a bypass.
* use an unsecured get route
* Overwrite the auth `validate` function.
* add the `@secure` annotation to the POST route, add a name and using `request->security` create specialised security overwriting.

## Example: Full Login Flow {#login-example}

### Routes

```php
\Tina4\Get::add("/login", function(\Tina4\Request $request,\Tina4\Response $response) {

    return $response(renderTemplate("login.twig"), HTTP_OK, TEXT_HTML);
});

\Tina4\Post::add("/login", function(\Tina4\Request $request,\Tina4\Response $response) {
    $data = $request->params;
    
    if (validateUser($data["username"], $data["password"])){
        $_SESSION["user"] = $data["username"];
        \Tina4\redirect("dashboard.php");
    }

   return $response(renderTemplate("login.twig", ["error" => "Invalid credentials", "old" => $data]), HTTP_BAD_REQUEST, TEXT_HTML);
});
```

### Template

```twig
<form method="POST" action="/login">
    {{ "loginForm" | formToken }}

    {% if error %}
        <p class="error">{{ error }}</p>
    {% endif %}

    <input type="text" name="username" value="{{ old.username ?? "" | e }}" required>
    <input type="password" name="password" required>

    <button>Login</button>
</form>
```
