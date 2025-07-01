# Installation

This assumes you have OpenSSL, PHP and composer already installed. Look into [requirements](/getting-started/-Requirements/) to configure your environment correctly.

## Using Composer

From your project root run the following
```bash
composer require tina4stack/tina4php
composer exec tina4 initialize:run
composer start
```
This will result in a webserver running on [localhost:7145](http://localhost:7145)
Once you click on the link your project folders will be initialized.

You can then modify your `composer.json` file to change the default port where your project will run.
Any file changes you effect will be applied immediately and you can refresh your browser to see changes.


## Basics

Here are some useful links to get started with the basics:

- [Static Website using Twig](/getting-started/php/-Basics/a-static-website-with-twig.html)
- [HTML Forms & Tokens](/getting-started/php/-Basics/b-html-forms-and-tokens.html)
- [Using .env for Settings](/getting-started/php/-Basics/d-using-env-for-settings.html)
- [Creating Routes & REST Endpoints](/getting-started/php/-Basics/c-creating-routes-and-rest-points.html)
- [Connecting to a Database](/getting-started/php/-Basics/e-connecting-to-a-database.html)
- [API Documentation with Swagger](/getting-started/php/-Basics/f-annotating-api-end-points.html)
- [Integrating external APIs](/getting-started/php/-Basics/g-third-party-api-integrations.html)
- [Creating Database Migrations](/getting-started/php/-Basics/h-creating-database-migrations.html)
- [Using the ORM](/getting-started/php/-Basics/i-using-the-orm.html)
- [Security & Custom Auth Helper](/getting-started/php/-Basics/j-security-and-custom-auth-helper.html)
