# Adding CSS to Your Static Website with SCSS

Tina4 handles SCSS compilation out-of-the-box, but with zero configuration needed. Place files in `src/scss`, and they compile to `src/public/css/default.css` during runtime or build, ensuring efficient and nested styling.

::: tip 🔥 Hot Tips
- **Automatic Compilation**: No extra tools or watchers—SCSS from `src/scss` merges into a single `default.css`, reducing HTTP requests like Webpack bundling.
- **Modular Design**: Use variables, nesting, and mixins for cleaner code, akin to Bootstrap's Sass setup.
- **Hot-Reloading**: Changes in SCSS reload instantly in dev mode, boosting workflow.
- **Static Serving**: Compiled CSS serves from `/css/default.css`, integrable with CDNs for production-scale sites.
:::

## Updated Project Structure
```
myproject/
├── app.py
├── src/
│   ├── scss/               # SCSS source files (e.g., _variables.scss, main.scss)
│   ├── templates/          # Twig files (as before)
│   └── public/             # Public assets
│       └── css/            # Compiled output
│           └── default.css # Merged CSS file

```

## Step 1: Add SCSS Files
Create `src/scss/main.scss` (or any `.scss` files—Tina4 compiles all):

```scss
// src/scss/_variables.scss (partial file, imported)
$primary-color: #007bff;
$font-stack: Helvetica, sans-serif;

// src/scss/main.scss
@import 'variables';

body {
  font-family: $font-stack;
  color: $primary-color;
  background: lighten($primary-color, 40%);

  h1 {
    text-transform: uppercase; // Nested styling
  }
}
```

- **Partials**: Files starting with `_` (e.g., `_variables.scss`) are imported without compiling separately—efficient like Sass best practices.

## Step 2: Link CSS in Twig Templates
Update `base.twig` to reference the compiled CSS:

```twig
<!DOCTYPE html>
<html lang="en">
<head>
    ...
    <link rel="stylesheet" href="/css/default.css">  {# Served from src/public/css #}
</head>
...
```

- **Path Note**: Tina4 serves `src/public` at root (e.g., `/css/`), making it accessible.

## Step 3: Develop and Deploy
- For production: Compilation happens automatically; we recommend committing the compiled CSS to source control for versioning and ease of deployment.
- Custom Builds: If needed, extend with a script for ahead-of-time compilation, but Tina4's runtime handling suffices for most static sites.

This integrates seamlessly with your auto-rendered Twig pages (e.g., `/` from `index.twig`), delivering styled content effortlessly. 
