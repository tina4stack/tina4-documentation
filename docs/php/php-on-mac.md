# Get Up and Running with PHP on macOS

This guide will get you a fully working PHP development environment (including Composer and Tina4) on your Mac in just a few minutes using **Homebrew** – the de facto standard package manager for macOS.

## 1. Install Homebrew (if you don’t have it already)

Open Terminal and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen instructions (you may need to enter your password).

## 2. Install PHP

```bash
brew update
brew install php
```

This installs the latest stable PHP version (currently PHP 8.3+ as of 2025) with all common extensions enabled.

Verify it works:

```bash
php -v
```

You should see something like:

```
PHP 8.3.x (cli) (built: ...) ...
```

## 3. Install Composer (PHP dependency manager)

```bash
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

# Verify the installer (official SHA-384 hash – always up-to-date at https://composer.github.io/installer.sig)
php -r "if (hash_file('sha384', 'composer-setup.php') === trim(file_get_contents('https://composer.github.io/installer.sig'))) { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"

php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Clean up
php -r "unlink('composer-setup.php');"
```

Now test Composer:

```bash
composer --version
```

You should see:

```
Composer version 2.x.x 2025-xx-xx ...
```

## 4. Optional: Make PHP & Composer available in all new terminals

Homebrew usually does this automatically, but if needed, add these lines to your shell profile (`~/.zshrc` for zsh, `~/.bash_profile` for bash):

```bash
export PATH="/opt/homebrew/opt/php/bin:$PATH"
export PATH="/opt/homebrew/opt/php/sbin:$PATH"
export PATH="$HOME/.composer/vendor/bin:$PATH"
```

Then reload:

```bash
source ~/.zshrc   # or source ~/.bash_profile
```

## 5. Install the Tina4 CLI

The Tina4 CLI is a Rust-based binary that manages project scaffolding and the dev server across all Tina4 frameworks.

```bash
brew install tina4stack/tap/tina4
```

Verify:

```bash
tina4 --version
```

## You're ready!

You now have a clean, modern PHP environment and can start building with **Tina4** right away:

```bash
tina4 init php my-project
cd my-project
composer install
tina4 serve
```

Open http://localhost:7146 in your browser -- welcome to Tina4!
