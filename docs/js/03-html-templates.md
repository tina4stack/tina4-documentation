# Chapter 3: HTML Templates

The `html` tagged template is the DOM rendering engine in tina4-js. It creates real DOM nodes, binds signals to specific text nodes and attributes, and updates only what changes.

This chapter covers every binding syntax: reactive text, reactive blocks, events, boolean attributes, property bindings, and class bindings.

## Full Chapter

This chapter contains JavaScript template literal syntax that conflicts with VitePress dev mode rendering. The full content is available at:

- **Book:** [tina4-book/book-5-javascript/chapters/03-html-templates.md](https://github.com/tina4stack/tina4-book/blob/main/book-5-javascript/chapters/03-html-templates.md)
- **Live:** [tina4.com/js/03-html-templates](https://tina4.com/js/03-html-templates)

## Quick Reference

| Syntax | What it does | Reactive? |
|--------|-------------|-----------|
| Static text | Text node, XSS-safe | No |
| Signal | Reactive text node | Yes |
| Function | Reactive block (conditionals, lists) | Yes |
| Fragment | Insert DocumentFragment | No |
| Array | Render each item | No |
| @click | Event listener | - |
| ?disabled | Boolean attribute (add/remove) | If signal/function |
| .value | DOM property binding | If signal |
| .innerHTML | Raw HTML injection | If signal |
| class | Regular attribute | If signal/function |

## Key Concepts

### Static vs Reactive

A static value evaluates once. A signal or function creates a subscription — when the dependency changes, the DOM updates automatically.

### Event Handling

Events use the `@` prefix. They are automatically batched — multiple signal updates in one handler produce one DOM update.

### Boolean Attributes

The `?` prefix adds or removes an attribute based on a truthy/falsy value. Useful for `disabled`, `hidden`, `checked`, `readonly`.

### Property Bindings

The `.` prefix sets DOM properties instead of HTML attributes. Use `.value` for form inputs, `.innerHTML` for raw HTML injection.

### Conditional Rendering

Return `null` from a reactive function to render nothing. Return an `html` fragment to render content. The template engine handles insertion and removal.

### List Rendering

Map an array signal through a function that returns `html` fragments. Each item gets its own reactive text nodes.

For complete code examples and exercises, see the [full chapter in the book](https://github.com/tina4stack/tina4-book/blob/main/book-5-javascript/chapters/03-html-templates.md).
