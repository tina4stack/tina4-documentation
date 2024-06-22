# Installation

This assumes you have OpenSSL, PHP and composer already installed. Look into [requirements](/getting-started/-Requirements/) to configure your environment correctly.

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

# Basics

Here are some useful links to get started with the basics

- [Static Website using Twig/Jinja]()
- [HTML Forms & Tokens]()
- [Using .env for Settings]()
- [Creating Routes & REST Endpoints]()
- [Connecting to a Database]()
- [Open API Documentation with Swagger]()
- [Integrating external APIs]()
- [Using the ORM]()
- [Creating Database Migrations]()
- [Security & Custom Auth Helper]()