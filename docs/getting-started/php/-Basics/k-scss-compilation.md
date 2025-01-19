# SASS & CSS compilation

By default, any files placed in the `scr/scss` folder will be compiled to the `src/public/css/default.css` file.

## File naming structure.

Consider naming your scss files as follows to order the compilation correctly:

```bash
1_home_page.scss
2_about_page.scss
3_additional.scss
```

!!! tip "Hot Tips"
    - Scss files are built on page load
    - Currently, there is no support for Less, pull requests will be considered.
