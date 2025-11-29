# Installation Guide for Tina4 PHP

Tina4 PHP is the original lightweight toolkit for building web applications, APIs, and real-time services in PHP—offering simplicity like Slim or Lumen, with built-in features comparable to Laravel's routing and templating but without the overhead. This guide covers setup using Composer, the standard PHP dependency manager, for reproducible environments.

## Prerequisites
- **PHP Version**: PHP 7.4 or higher (8.0+ recommended for performance and security).
- **Composer**: The PHP dependency manager (install via [getcomposer.org](https://getcomposer.org/)).
- **OpenSSL**: Required for secure operations; typically included in PHP installations.
- **Environment Configuration**: Ensure PHP is on your PATH for CLI access. For production, consider servers like Apache/Nginx; development uses PHP's built-in server.

Tina4 PHP runs seamlessly on your local machine with an enhanced version of the PHP webserver which simulates a production environment.

## Installation with Composer
Composer handles dependencies declaratively, similar to Laravel's `composer create-project`.

From your project root (create an empty folder if starting fresh):

1. **Install Tina4 PHP**:
   ```bash
   composer require tina4stack/tina4php
   ```

2. **Initialize the Project**:
   ```bash
   composer exec tina4 initialize:run
   ```
   This sets up the project structure, including folders for routes, templates, and more.

3. **Start the Development Server**:
   ```bash
   composer start
   ```
   This launches a built-in PHP server at `http://localhost:7145` with hot-reloading—edit files and refresh the browser to see changes instantly.

## Customizing the Setup
- **Change Port**: Edit `composer.json` under the `scripts` section to modify the default port (e.g., replace `7145` with your preferred port).
- **Existing Projects**: Tina4 packages can integrate into non-Tina4 apps without the full framework—add specific modules via Composer (see [Packages](/getting-started/php/Packages/)).

## Verification
Open `http://localhost:7145/` in your browser. You'll see a welcome page or initialization prompt. Add routes in the generated files to test—changes apply immediately, echoing Laravel's artisan serve with live reload.

For production, deploy to a web server; Tina4 supports easy integration with Apache, Nginx, or containers. If issues occur, verify Composer/PHP versions with `composer --version` and `php -v`.

This minimal setup gets you coding fast, embodying Tina4's "not a framework" philosophy. Explore [Basic Routing](basic-routing.md) for routing examples.
