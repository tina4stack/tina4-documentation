# Package Overview

Most of the Tina4 PHP packages can be used with your existing PHP projects without having to install the full framework.

### tina4php-core

The core tina4 module

#### Installation

```bash
composer require tina4stack/tina4php-core
```

#### Overview

- Annotation.php - reads annotations from block comments
- Cache.php - implements the base caching for routes and templates - PhpFastCache
- Module.php - turns any Tina4 project into a loadable module
- Test.php - inline testing for methods
- Utilities.php - common methods used across the whole scope of the framework

#### Dependencies

- PHPFastCache

### tina4php-debug

The debug module for Tina4. It can be used in any PHP composer project.

#### Installation

```bash
composer require tina4stack/tina4php-debug
```

#### Overview

- Debug.php - debug module for outputting messages to console based on the debug level

```php
const TINA4_LOG_EMERGENCY = "emergency";
const TINA4_LOG_ALERT = "alert";
const TINA4_LOG_CRITICAL = "critical";
const TINA4_LOG_ERROR = "error";
const TINA4_LOG_WARNING = "warning";
const TINA4_LOG_NOTICE = "notice";
const TINA4_LOG_INFO = "info";
const TINA4_LOG_DEBUG = "debug";
const TINA4_LOG_ALL = "all";
```

### tina4php-database

The database abstraction layer, all the specific database abstractions are inherited from this module.

#### Installation

```bash
composer require tina4stack/tina4php-database
```

#### Overview

Use this pattern to implement your own database driver
```php
<?php
/**
* Example database implementation
*/
class DataMyDb implements DataBase
{
    use DataBaseCore;
    
}    
```
