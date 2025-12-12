# Tina4 PHP – Quick Reference - Examples need fixing

<nav class="tina4-menu">
    <a href="#installation">Installation</a> •
    <a href="#basic-routing">Routing</a> •  
    <a href="#middleware">Middleware</a> •  
    <a href="#static-websites">Static Websites</a> •
    <a href="#templates">Templates</a> •
    <a href="#session-handling">Sessions</a> •
    <a href="#scss-stylesheets">SCSS</a> •
    <a href="#environments">Environments</a> •
    <a href="#authentication">Authentication</a> •
    <a href="#html-forms-and-tokens">Forms & Tokens</a> •
    <a href="#swagger">OpenAPI</a> •
    <a href="#databases">Databases</a> •
    <a href="#database-results">Database Results</a> •    
    <a href="#migrations">Migrations</a> •
    <a href="#orm">ORM</a> •
    <a href="#crud">CRUD</a> •
    <a href="#inline-testing">Testing</a> •
    <a href="#wsdl">WSDL</a> •
    <a href="#consuming-rest-apis">REST Client</a>
</nav>

<style>
.tina4-menu { 
  background: #2c3e50; color: white; padding: 1rem; border-radius: 8px; margin: 2rem 0; text-align: center; font-size: 1.1rem;
}
.tina4-menu a { color: #1abc9c; text-decoration: none; margin: 0 0.4rem; }
.tina4-menu a:hover { text-decoration: underline; }
</style>

### Installation {#installation}

```bash
composer require tina4stack/tina4php
composer exec tina4 initialize:run
composer start
```

### Basic Routing {#basic-routing}

```php
\Tina4\Get("/", function (\Tina4\Response $response) {
    return $response("<h1>Hello Tina4 PHP</h1>");
});

// post requires formToken or Bearer auth
\Tina4\Post("/api", function (\Tina4\Request $request, \Tina4\Response $response) {
    return $response(["data" => $request->params]);
});

// redirect after post
\Tina4\Post("/register", function (\Tina4\Request $request, \Tina4\Response $response) {
    return \Tina4\redirect("/welcome");
});
```

### Middleware {#middleware}

```php
class RunSomething {

    function beforeSomething(\Tina4\Request $request, \Tina4\Response $response) {
        $response->content .= "Before";
        return [$request, $response];
    }

    function afterSomething(\Tina4\Request $request, \Tina4\Response $response) {
        $response->content .= "After";
        return [$request, $response];
    }

    function beforeAndAfterSomething(\Tina4\Request $request, \Tina4\Response $response) {
        $response->content .= "[Before / After Something]";
        return [$request, $response];
    }
}

\Tina4\Get("/middleware", function (\Tina4\Request $request, \Tina4\Response $response) {
    return $response("Route");
}, ["middleware" => "RunSomething"]);
```

### Static Websites {#static-websites}

Put `.twig` files in `./src/templates` • assets in `./public`

```twig
<!-- src/templates/index.twig -->
<h1>Hello Static World</h1>
```

### Template Rendering {#templates}

Put `.twig` files in `./src/templates` • assets in `./public`

```twig
<!-- src/templates/index.twig -->
<h1>Hello {{name}}</h1>
```

```php
\Tina4\Get("/", function (\Tina4\Request $request, \Tina4\Response $response) {
    return $response(\Tina4\renderTemplate("index.twig", ["name" => "World!"]));
});
```

### Sessions {#session-handling}

The default session handling is file-based, override in config.

```php
\Tina4\Get("/session/set", function (\Tina4\Request $request, \Tina4\Response $response) {
    $_SESSION["name"] = "Joe";
    $_SESSION["info"] = ["info" => ["one", "two", "three"]];
    return $response("Session Set!");
});

\Tina4\Get("/session/get", function (\Tina4\Request $request, \Tina4\Response $response) {
    $name = $_SESSION["name"];
    $info = $_SESSION["info"];
    return $response(["name" => $name, "info" => $info]);
});
```

### SCSS Stylesheets {#scss-stylesheets}

Drop in `./src/scss` → auto-compiled to `./public/css`

```scss
// src/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```

### Environments {#environments}

Default development environment in `.env`

```
PROJECT_NAME="My Project"
VERSION=1.0.0
TINA4_LANGUAGE=en
TINA4_DEBUG=true
API_KEY=ABC1234
DATABASE_NAME=sqlite3:test.db
```

```php
$apiKey = getenv("API_KEY") ?: "ABC1234";
```

### Authentication {#authentication}

Pass `Authorization: Bearer API_KEY` to secured routes. See `.env` for default `API_KEY`.

```php
\Tina4\Post("/login", function (\Tina4\Request $request, \Tina4\Response $response) {
    return $response("Logged in", HTTP_OK, ["cookies" => ["session" => "abc123"]]);
}, ["auth" => false]);

\Tina4\Get("/protected", function (\Tina4\Request $request, \Tina4\Response $response) {
    return $response("Hi " . ($request->cookies["username"] ?: "guest") . "!");
}, ["secure" => true]);
```

### HTML Forms and Tokens {#html-forms-and-tokens}

```twig
<form method="POST" action="/register">
    {{ formToken("Register" ~ random()) }}
    <input name="email">
    <button>Save</button>
</form>
```

### Swagger {#swagger}

Visit `http://localhost:7145/swagger`

```php
\Tina4\Get("/users", function (\Tina4\Response $response) {
    /**
     * @description Returns all users
     */
    return $response((new User())->select("*"));
});
```

### Databases {#databases}

```php
// Require DB package, e.g., composer require tina4stack/tina4php-sqlite3
global $DBA;
$DBA = new \Tina4\Database("sqlite3:data.db");
```

### Database Results {#database-results}

```php
$result = $DBA->fetch("select * from test_record order by id", 3, 1);

$list = $result->asArray();
$array = $result->asObject();
$dict = $result->asResult();
$csv = $result->asCsv();
$json = $result->asJson();
```

### Migrations {#migrations}

```bash
composer exec tina4 migrate:create create_users_table
```

```sql
-- migrations/00001_create_users_table.sql
CREATE TABLE users
(
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT
);
```

```bash
composer exec tina4 migrate:run
```

### ORM {#orm}

```php
class User extends \Tina4\ORM {
    public $tableName = "users";
}

$user = new User(["name" => "Alice"]);
$user->save();
$user = (new User())->load("id = ?", 1);
```

### CRUD {#crud}

```php
\Tina4\Get("/users/dashboard", function (\Tina4\Request $request, \Tina4\Response $response) {
    $users = (new User())->select("id, name, email");
    return $response(\Tina4\renderTemplate("users/dashboard.twig", ["crud" => $users->asCrud($request)]));
});
```

```twig
{{ crud }}
```

### Inline Testing {#inline-testing}

```php
/**
 * @test assertEqual(7,7) 1
 * @test assertEqual(-1,1) -1
 * @test assertThrows(ZeroDivisionError) 5,0
 */
function divide($a, $b) {
    if ($b == 0) {
        throw new Exception("division by zero");
    }
    return $a / $b;
}
```

Run: `composer test`

### WSDL {#wsdl}

Note: WSDL support may require additional configuration or packages.

```php
class Calculator {
    public function Add($a, $b) {
        return ["Result" => $a + $b];
    }

    public function SumList($Numbers) {
        return [
            "Numbers" => $Numbers,
            "Total" => array_sum($Numbers),
            "Error" => null
        ];
    }
}

\Tina4\Post("/calculator", function (\Tina4\Request $request, \Tina4\Response $response) {
    return $response->wsdl(new Calculator());
});
```

### Consuming REST APIs {#consuming-rest-apis}

```php
$api = new \Tina4\Api("https://api.example.com", ["Authorization" => "Bearer xyz"]);
$result = $api->get("/users/42");
echo $result["body"];
```

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">↑ Back to top</a>
</nav>