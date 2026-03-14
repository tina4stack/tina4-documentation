# Testing {#testing}

Tina4 projects use [PHPUnit](https://phpunit.de/) for testing. Each module in the Tina4 ecosystem includes a `phpunit.xml` configuration and a `tests/` directory.

::: tip Hot tips!
- Use SQLite (`:memory:`) for database tests — no external services needed
- Run `composer test` from any Tina4 module to execute its test suite
- All Tina4 modules target PHPUnit 9 with PHP 8.1+
:::

## Setting Up Tests {#setup}

### Install PHPUnit

PHPUnit is included as a dev dependency in Tina4 modules:

```bash
composer require --dev phpunit/phpunit ^9
```

### Create phpunit.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="https://schema.phpunit.de/9.5/phpunit.xsd"
         bootstrap="vendor/autoload.php"
         colors="true"
         verbose="true">
    <testsuites>
        <testsuite name="default">
            <directory>tests</directory>
        </testsuite>
    </testsuites>
</phpunit>
```

### Add a Test Script to composer.json

```json
{
    "scripts": {
        "test": "./vendor/bin/phpunit tests --color"
    }
}
```

## Writing Tests {#writing-tests}

### Basic Test

```php
<?php

namespace Tests;

use PHPUnit\Framework\TestCase;

class MyTest extends TestCase
{
    public function testExample(): void
    {
        $this->assertTrue(true);
    }
}
```

### Testing with a Database

Use SQLite in-memory for fast, isolated database tests:

```php
<?php

namespace Tests;

use PHPUnit\Framework\TestCase;
use Tina4\DataSQLite3;

class DatabaseTest extends TestCase
{
    private $DBA;

    protected function setUp(): void
    {
        $this->DBA = new DataSQLite3(":memory:");
        $this->DBA->exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)");
        $this->DBA->exec("INSERT INTO users (name, email) VALUES ('John', 'john@example.com')");
    }

    public function testFetchUsers(): void
    {
        $result = $this->DBA->fetch("SELECT * FROM users");
        $this->assertEquals(1, $result->getNoOfRecords());
    }

    public function testInsertUser(): void
    {
        $this->DBA->exec("INSERT INTO users (name, email) VALUES ('Jane', 'jane@example.com')");
        $result = $this->DBA->fetch("SELECT * FROM users");
        $this->assertEquals(2, $result->getNoOfRecords());
    }
}
```

### Testing ORM Objects

```php
<?php

namespace Tests;

use PHPUnit\Framework\TestCase;
use Tina4\DataSQLite3;

class ORMTest extends TestCase
{
    protected $DBA;

    protected function setUp(): void
    {
        global $DBA;
        $DBA = new DataSQLite3(":memory:");
        $this->DBA = $DBA;

        $this->DBA->exec("CREATE TABLE user (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name TEXT,
            last_name TEXT,
            email TEXT
        )");
    }

    public function testSaveAndLoad(): void
    {
        $user = new \App\User();
        $user->firstName = "John";
        $user->lastName = "Doe";
        $user->email = "john@example.com";
        $user->save();

        $loaded = (new \App\User())->load("id = ?", [1]);
        $this->assertEquals("John", $loaded->firstName);
        $this->assertEquals("john@example.com", $loaded->email);
    }
}
```

### Testing Routes

```php
<?php

namespace Tests;

use PHPUnit\Framework\TestCase;

class RouteTest extends TestCase
{
    public function testGetRoute(): void
    {
        // Register the route
        \Tina4\Get::add("/api/test", function(\Tina4\Response $response) {
            return $response(["status" => "ok"]);
        });

        // Simulate a request
        $result = \Tina4\Routing::callRoute("/api/test", "GET");
        $this->assertStringContainsString("ok", $result);
    }
}
```

## Running Tests {#running}

```bash
# Run all tests
composer test

# Run a specific test file
./vendor/bin/phpunit tests/MyTest.php

# Run with verbose output
./vendor/bin/phpunit tests -vvv --color

# Run a specific test method
./vendor/bin/phpunit --filter testExample tests/MyTest.php

# Generate JUnit XML report
./vendor/bin/phpunit tests --log-junit=tests/junit.xml
```

## Test Organization {#organization}

A typical Tina4 project test structure:

```
project/
  tests/
    bootstrap.php         # Optional: custom setup before tests
    DatabaseTest.php      # Database layer tests
    ORMTest.php          # ORM model tests
    RouteTest.php        # API endpoint tests
    ServiceTest.php      # Business logic tests
  phpunit.xml            # PHPUnit configuration
```

### Bootstrap File

If you need custom setup (e.g., defining constants, connecting to a test database):

```php
<?php
// tests/bootstrap.php

if (!isset($_SERVER['DOCUMENT_ROOT'])) {
    $_SERVER['DOCUMENT_ROOT'] = dirname(__DIR__);
}

require_once dirname(__DIR__) . '/vendor/autoload.php';
```

Update `phpunit.xml` to use it:

```xml
<phpunit bootstrap="tests/bootstrap.php" ...>
```

## CI Integration {#ci}

All Tina4 modules include GitHub Actions CI. A typical workflow:

```yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        php-version: ['8.1', '8.2', '8.3', '8.4']

    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php-version }}
      - run: composer install --no-progress
      - run: composer test
```
