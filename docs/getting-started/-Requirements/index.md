# Overview

Obviously you don't need to use or install all of these languages or systems, choose which one is applicable for the problem you are solving.

## Docker

The docker environment is probably the easiest way to test the framework without impacting your system.
We have developed our dockers to expose the working directory to the docker, so you can code whilst using the running docker.

On Windows and Mac you can download the docker desktop which should suffice for running development.

## Windows

### Open SSL
Windows is missing packages for OpenSSL. You should make sure you have these installed before you start your Tina4 journey.
You can test if your operating system is ready by opening a terminal and typing:
```cmd
openssl -v
```
You should get a version output for openssl. If this fails then use the following link to get the latest installation of OpenSSL for windows.
Make sure you add the bin folder of the installation into your Environment path.

[Download OpenSSL for Windows](https://slproweb.com/products/Win32OpenSSL.html)

### PHP

PHP development with Tina4 only requires the PHP interpreter to be available on your path as we make use of the built in webserver.

PHP 7.4 and greater is supported

[Download the latest PHP](https://windows.php.net/download)

-- The VC15 and VS16 builds require to have the Visual C++ Redistributable for Visual Studio 2015-2019 x64 or x86 installed

Before you install the debugger, it would be a good idea to install **composer** the package manager for PHP.

[Download Composer](https://getcomposer.org/download/)

In order to debug PHP applications we recommend X-debug. Make sure to choose the version that corresponds with the version of PHP you have installed.

[Download XDebug](https://xdebug.org)

Rename the downloaded dll module to xdebug.dll and place inside your PHP ext folder.

Use the following config in your `php.ini`

```
[Xdebug]
zend_extension=xdebug
xdebug.mode = debug
xdebug.start_with_request=yes
```

### RAD Studio

Building native applications in an efficient manner is readily available in the Community Edition of RAD Studio.  The primary language being pascal, we have some really good REST components for use in the IDE.

[Download Community Edition of RAD Studio](https://www.embarcadero.com/products/delphi/starter/free-download)

### Python

The default Python installation from the application store on windows is 100% for your use as we recommend making virtual environments to run on for each project you create.
On windows a virtual environment can be created and activated relative to your project folder.

```cmd
python -m venv venv
.\venv\Scripts\activate
```

Notice the `(venv)` prefix on the command prompt, if it does not show you are probably not running relative to an environment.
We use the **poetry** package manager for python. 


### NodeJs

NodeJs can be installed and added to path from the following link, our tina4js package is still in early alpha development.

[Download NodeJs](https://nodejs.org/en/download/prebuilt-installer)

## MacOS

MacOS is pretty straight forward if you are prepared to install **homebrew** package manager. Using homebrew you can quickly provision PHP, Python, NodeJs & Ruby. 

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### OpenSSL

You will need openssl libraries to be installed

```bash
brew install openssl
```

### PHP

The following will install PHP, Composer & XDebug

```cmd
brew install php
brew install composer
pecl install xdebug
```

## Linux

Most of our deployments are to Linux servers, we are in the process of documenting this for development.
Our preferred flavour of Linux is Ubuntu, we can confirm though that Tina4 plays nice with most flavours.
We simply look at the ease of installation on most platforms and Ubuntu's package management seems to be the easiest to use.

