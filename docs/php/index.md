# Tina4 PHP – Quick Reference

<nav class="tina4-menu">
    <a href="#installation">Installation</a> •
    <a href="#static-websites">Static Websites</a> •
    <a href="#basic-routing">Routing</a> •   
    <a href="#middleware">Middleware</a> •
    <a href="#templates">Templates</a> •
    <a href="#session-handling">Sessions</a> •
    <a href="#scss-stylesheets">SCSS</a> •
    <a href="#environments">Environments</a> •
    <a href="#authentication">Authentication</a> •
    <a href="#html-forms-and-tokens">Forms & Tokens</a> •
    <a href="#ajax">AJAX</a> •
    <a href="#swagger">OpenAPI</a> •
    <a href="#databases">Databases</a> •
    <a href="#database-results">Database Results</a> •    
    <a href="#migrations">Migrations</a> •
    <a href="#orm">ORM</a> •
    <a href="#crud">CRUD</a> •
    <a href="#consuming-rest-apis">REST Client</a> •
    <a href="#inline-testing">Testing</a> •
    <a href="#services">Services</a> •
    <a href="#threads">Threads</a> •
    <a href="#queues">Queues</a> •
    <a href="#wsdl">WSDL</a>

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
[More details](installation.md) around project setup and some customizations. 

### Static Websites {#static-websites}

Put `.html` or `.twig` files in `./src/templates` • assets in `./public`

```twig
<!-- src/templates/index.twig -->
<h1>Hello Static World</h1>
```
[More details](static-website.md) on static website routing.

### Basic Routing {#basic-routing}

```php
\Tina4\Get::add("/", function (\Tina4\Response $response) {
    return $response("<h1>Hello Tina4 PHP</h1>");
});

// Post requires a formToken or Bearer auth
\Tina4\Post::add("/api", function (\Tina4\Request $request, \Tina4\Response $response) {
    return $response(["data" => $request->params]);
});

// redirect after post
\Tina4\Post::add("/register", function (\Tina4\Request $request, \Tina4\Response $response) {
    \Tina4\redirect("/welcome");
});
```
Follow the links for , this [basic routing](basic-routing.md#basic-routing), [dynamic routing](basic-routing.md#dynamic-routing) with variables and [different response types](basic-routing.md#response-options).

### Middleware {#middleware}

```php
// Declare the middleware 
\Tina4\Middleware::add("MyMiddleware", function (\Tina4\Response $response, \Tina4\Request &$request) {

    return $response("This is not my middleware");
});

// The middleware will intercept the route, which will actually never fire in this design
\Tina4\Get::add("/my-route", function (\Tina4\Response $response, \Tina4\Request $request) {

    return $response("This is my route");
})::middleware(["MyMiddleware"]);
```
Follow the links for more on [Middleware Declaration](middleware.md#declare), [Linking to Routes](middleware.md#routes), [Middleware Chaining](middleware.md#chaining) and [Middleware With Dynamic Routes](middleware.md#dynamic).

### Template Rendering {#templates}

Put `.twig` files in `./src/templates` • assets in `./public`. Render the templates passing data in an array.

```twig
<!-- src/templates/hello.twig -->
<h1>Hello {{name}}</h1>
```

```php
\Tina4\Get("/", function (\Tina4\Request $request, \Tina4\Response $response) {

    return $response(\Tina4\renderTemplate("hello.twig", ["name" => "World!"]));
});
```

### Sessions {#session-handling}

Sessions are started by default in the Tina4\Auth constructor.

### SCSS Stylesheets {#scss-stylesheets}

Drop in `./src/scss` then `default.css` is auto-compiled to `./public/css`

```scss
// src/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```
[More details](css.md) on css and scss.

### Environments {#environments}

Default development environment in `.env`

```
[Project Settings]
VERSION=1.0.0
TINA4_DEBUG=true
TINA4_DEBUG_LEVEL=[TINA4_LOG_ALL]
TINA4_CACHE_ON=false
[Open API]
SWAGGER_TITLE=Tina4 Project
SWAGGER_DESCRIPTION=Edit your .env file to change this description
SWAGGER_VERSION=1.0.0
```
Environment variables are available through the Environment superglobal variable.
```php
$data = $_ENV["SWAGGER_TITLE"];
```

### Authentication {#authentication}

All POST routes are naturally secured. GET routes can be secured through php annotations

```php
/**
 * @secure
 */
\Tina4\Get::add("/my-route", function(\Tina4\Response $response) {
   
    return $response("This route is protected");
});  
```
A valid bearer token or Tina4 formed JWT token are valid authorizations

### HTML Forms and Tokens {#html-forms-and-tokens}

Form tokens can be added using a Tina4 twig filter
```twig
<form method="POST" action="submit">
    {{ "emailForm" | formToken }}
    <input name="email">
    <button>Save</button>
</form>
```
Renders out this form with "emailForm" sent via the JWT payload
```html
<form method="POST" action="submit">
    <input type="hidden" name="formToken" value="ey...">
    <input name="email">
    <button>Save</button>
</form>
```
[More Details](posting-form-data.md) on posting form data.

### AJAX and tina4helper.js {#ajax}

Tina4 ships with a small javascript library, in the bin folder, to assist with the heavy lifting of ajax calls.

[More details](tina4helper.md) on available features.

### OpenAPI and Swagger UI {#swagger}

Swagger is built into Tina4 and found at `/swagger`. Adding the `@description` annotation will include the route into swagger.

```php
/**
 * @description Returns all users
 */
\Tina4\Get("/users", function (\Tina4\Response $response) {

    return $response((new User())->select("*"));
});
```
Follow the links for more on [Configuration](swagger.md#config), [Usage](swagger.md#usage) and [Annotations](swagger.md#annotations).

### Databases {#databases}

Each database module implements the Database interface and needs to be included into composer, depending on which Database has been selected.
```bash

composer require tina4stack/tina4php-sqlite3
```
The initial database connection in `index.php` might differ due to database selected.
```php
//Initialize Sqlite Database Connection
global $DBA;
$DBA = new \Tina4\DataSQLite3("database/myDatabase.db", "username", "my-password", "d/m/Y");
```
Follow the links for more on [Available Connections](database.md#connections), [Core Methods](database.md#core-methods), [Usage](database.md#usage) and [Full transaction control](database.md#transactions).

### Database Results {#database-results}
Returning a single row is as easy as 
```php
$dataResult = $DBA->fetchOne("select * from test_record order by id");
```

Database objects all return a DataResult object, which can then be returned in a number of formats.
```php
// fetch($sql, $noOfRecords, $offset)
$dataResult = $DBA->fetch("select * from test_record order by id", 3, 1);

$list = $dataResult->asArray();
$array = $dataResult->asObject();
```
Looking at detailed [Usage](database.md#usage) will improve deeper understanding.

### Migrations {#migrations}
Migrations are available as cli commands. This command will create a migration file in the migrations folder. Just add your sql.
```bash

composer migrate:create my-first-migration
```
A number of migration creations can be made before executing the migrations. Once all creations are finished, just run them.
```bash

composer migrate
```

Alternatively you can spin up the webserver and do the same from the browser.
```
http://localhost:7145/migrate/create

http://localhost:7145/migrate
```
[Migrations](migrations.md) do have some limitations and considerations when used extensively.

### ORM {#orm}

Once you have run your migrations, creating the tables, ORM makes database interactions seamless.
```php
class User extends Tina4\ORM
{
    public $tableName = 'user';
    
    public $id;
    public $email;
}

$user = new User(["email" => "my-email@email.com"]);
$user->save();
$user = (new User())->load("id = ?", 1);
```
ORM functionality is quite extensive and needs more study of the [Advanced Detail](orm.md) to get the full value from ORM.

### CRUD {#crud}
With a single line of code, Tina 4 can generate a fully functional CRUD system, screens and all.
```php
(new User())->generateCrud("/my-crud-templates")
```
[More details](crud.md) on how CRUD works, where it puts the generated files is worth some investigation.

### Consuming REST APIs {#consuming-rest-apis}
Getting data from a public api is as simple as one line of code.
```php
$api = (new \Tina4\Api())->sendRequest("https://api.example.com", "GET");
```
[More details](rest-api.md) are available on sending a post data body, authorizations and other finer controls of sending api requests.

### Inline Testing {#inline-testing}

Tina4 allows testing to be added to functions without having to set up a test suite.
```php
    /**
     * @tests Cris
     * assert(2,5)==7,"2+5 not equal 7"
     */
    public function addTwoNumbers($number1, $number2)
    {
        return $number1 + $number2;
    }
```
After making changes you can run the tests
```bash

composer test
```
[Limitations](tests.md) and 
### Services {#services}

Create the required process
```php
class MyProcess extends \Tina4\Process
{
    public function canRun(): bool
    {
        // Include any selection criteria you need, or just return true
        return true;
    }
    
    public function run(): void
    {
        // Do whatever you want here
    }
}
```
Add the process to the service
```php
    $service = (new \Tina4\Service());
    $service->addProcess(new MyProcess("Unique Process Name")); 
```
Create the service on the server by creating and registering an appropriate script. 

There are a number of special cases that [Need Investigating](services.md) for getting the full value out of services, and should be studied in conjunction with threads.

### Threads {#threads}

 Create the thread code as required
```php
Tina4\Thread::addTrigger('myNewProcess', function () {
    // Do whatever you want to do here
});
```
Call the thread as required
```php
// Starts a new php thread running the code as declared above
Tina4\Thread::trigger('myNewProcess');
```
Please read [More Details](threads.md) on Threads, their restrictions and usage ideas.

### Queues {#queues}

Services and Threads together can be used to replicate queues, but stand alone queues are not implemented in Tina4 Php.

### WSDL {#wsdl}
Declare your WSDL definition
```php
class Calculator extends \Tina4\WSDL {
    protected array $returnSchemas = [
        "Add" => ["Result" => "int"],
        "SumList" => [
            "Numbers" => "array<int>",
            "Total" => "int",
            "Error" => "?string"
        ]
    ];

    public function Add(int $a, int $b): array {
        return ["Result" => $a + $b];
    }

    /**
     * @param int[] $Numbers
     */
    public function SumList(array $Numbers): array {
        return [
            "Numbers" => $Numbers,
            "Total" => array_sum($Numbers),
            "Error" => null
        ];
    }
}
```
Add your WSDL routes
```php
\Tina4\Any::add("/calculator", function (\Tina4\Request $request, \Tina4\Response $response) {
    $calculator = new Calculator($request);
    $handle = $calculator->handle();
    return $response($handle, HTTP_OK, APPLICATION_XML);
});
```
[More Details](wsdl.md) are available for WSDL

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">↑ Back to top</a>
</nav>