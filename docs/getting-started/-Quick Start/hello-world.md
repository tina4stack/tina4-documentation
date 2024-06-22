# Hello World Website

In the `src/templates` folder create an `index.twig` folder with the following content:

**index.twig**
```html
<!DOCTYPE html>
<html>
<head>
<title>Tina4 - Hello Tina</title>
</head>
<body>

<h1>Hello World!</h1>

</body>
</html>
```

We use Twig on PHP and Jinja2 on Python so your basic functionality should remain the same.

>- All static elements will be served from `src/public` and html paths are relative to that folder.
>- Example: `<img src="/images/logo.png">` will resolve to `./src/public/images/logo.png`
>- A file called `about-us.twig` will be able to be resolved at [http://localhost:7145/about-us](http://localhost:7145/about-us)

