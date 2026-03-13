# AJAX - tina4helper.js

::: tip 🔥 Hot Tips
- tina4helper.js is a lightweight JavaScript utility for AJAX calls
- Works with form tokens automatically
- Shared across all Tina4 implementations (PHP, Python, Ruby)
:::

## Including tina4helper.js

```html
<script src="/js/tina4helper.js"></script>
```

## Basic Usage

```javascript
// GET request
tina4.get("/api/users", function(response) {
    console.log(response);
});

// POST request
tina4.post("/api/users", { name: "Alice" }, function(response) {
    console.log(response);
});

// PUT request
tina4.put("/api/users/1", { name: "Alice Updated" }, function(response) {
    console.log(response);
});

// DELETE request
tina4.delete("/api/users/1", function(response) {
    console.log(response);
});
```

## Form Submission

```javascript
// Submit a form via AJAX
tina4.submitForm("myForm", "/api/submit", function(response) {
    alert("Saved!");
});
```

[More details](/python/tina4helper.md) — the JavaScript library is shared across all Tina4 implementations.
