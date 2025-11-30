# Get Up and Running with PHP on Windows

Good news — you **don’t need WAMP, XAMPP, or any heavy installers** in 2025.  
Just grab the official PHP binaries, unzip, and go!

## 1. Download the latest PHP zip (Thread-Safe version)

Go to: https://windows.php.net/download/

- Choose **VS16 x64 Thread Safe Zip** (recommended for Tina4 and Composer)
- As of November 2025, the latest stable is PHP 8.3.x or 8.4.x

Direct link example (always verify the latest):
```
https://windows.php.net/downloads/releases/php-8.5.0-nts-Win32-vs17-x64.zip
```

## 2. Extract to C:\php

1. Unzip the downloaded file
2. Create folder `C:\php` (if it doesn’t exist)
3. Move all contents into `C:\php`

Your folder should now contain `php.exe`, `php.ini-development`, etc.

## 3. Create php.ini

Copy `php.ini-development` → `php.ini` inside `C:\php`

```bash
copy C:\php\php.ini-development C:\php\php.ini
```

## 4. Add C:\php to your System PATH

1. Press `Win + X` → System → Advanced system settings
2. Click **Environment Variables**
3. Under **System variables**, find and edit **Path**
4. Click **New** → add `C:\php` → OK → OK

Open a **new** Command Prompt or PowerShell and test:

```bash
php -v
```

You should see the PHP version output.

## 5. Enable common extensions

Edit `C:\php\php.ini` and uncomment the extensions you need (remove the `;`):

```ini
extension=curl
extension=fileinfo
extension=gd
extension=mbstring
extension=openssl
extension=pdo_mysql
extension=pdo_sqlite
extension=sqlite3
; uncomment if you use PostgreSQL
;extension=pdo_pgsql
```

## 6. Install Composer (one-liner)

In PowerShell or CMD (as Administrator is **not** required):

```powershell
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if(hash_file('sha384', 'composer-setup.php') === trim(file_get_contents('https://composer.github.io/installer.sig'))) { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); }"
php composer-setup.php
php -r "unlink('composer-setup.php');"
move composer.phar C:\php\composer.bat
```

Now `composer` works globally:

```bash
composer --version
```

## 7. (Optional but recommended) Install Xdebug

```bash
# Find your PHP version info
php -i | findstr "PHP Version"

# Go to https://xdebug.org/wizard and paste the output
# Then download the DLL it recommends and place it in C:\php\ext\
# Finally add to php.ini:
zend_extension=xdebug
```

## You’re ready!

Start a new Tina4 project instantly:

```bash
composer create-project tina4stack/tina4-php my-awesome-site
cd my-awesome-site
composer start
```

Open http://localhost:7145 — welcome to Tina4 on Windows! 🚀
