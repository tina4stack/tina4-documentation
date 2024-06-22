# Package Overview

Most of the Tina4 PHP packages can be used with your existing PHP projects without having to install the full framework.

### tina4php-core

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