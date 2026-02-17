# CRUD (Create, Read, Update, Delete)
::: tip 🔥 Hot Tips
- Attach CRUD to any ORM model.
- Single method to auto generate routes and templates for a fully functioning CRUD system.
- Can be used as website, api or both.
- Default CSS provided by Bootstrap.
  :::

## Generating CRUD

* Ensure the desired `Tina4\ORM` model is created.
* Create an empty `php` file in your routes folder. 
* Type in the following command in the file. 
* Run any page in the website.
* The CRUD is built completely.

```php
<?php
// The path 'crud/catalog' is used for both the route names and template folder structure
(new Catalog())->generateCrud("/crud/catalog");
```
So let's look at what just happenend.
* A landing route `/crud/catalog/landing` has been created which loads the browser based screens.
* The single route `/crud/catalog` to run the browser screens, or as an api is created. This handles all operations.
* The screen templates are created in the `templates/crud/catalog` folder. The first file `grid.twig` is the display page. The second file `form.twig` is the editing modal.
* Both files extend the `public/components/base.twig` file.
* These templates are created from the templates found in the `public/components`.

## Customisation

* Templates can be customized in the `public/components` files.
* CSS can be replaced or extended. 
* Generated files can be further customised as desired.