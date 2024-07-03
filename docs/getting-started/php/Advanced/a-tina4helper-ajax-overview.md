# Tina4Helper.js overview and it's use for AJAX

The tina4helper.js library was created to ease the pain of working with forms and posting data asynchronously (AJAX) .  It is plain Javascript and does
not require any dependencies. It works on all the browsers.

## sendRequest method

Sends a request to backend

```javascript

// sendRequest (url, request, method, callback);
//POST data to an end point
sendRequest ('/api/cars', {"name": "Toyota", "year": 2024}, "POST", function(response){
    console.log ('Response data', response);
    //Use the response to do other things.
});

//GET data from an end point
sendRequest ('/api/cars', null, "GET", function(response){
    console.log ('Response data', response);
    //Use the response to do other things.
});

```

## getFormData

Gets form data based on form ID and Posts it up to the server.

```javascript
let data = getFormData('#signUp');

sendRequest ('/api/register', data, "POST", function(response){
    console.log ('Response data', response);
    //Use the response to do other things.
});

```

## loadPage

Loads a page into a specific HTML tag using its `id`

```html
<div id="some-content"></div>
<script>
    //without call back
    loadPage("/api/page", "some-content", callback = null)

    //with call back
    loadPage("/api/page", "some-content", function(data) {
        console.log("Load page", data);
    })
</script>
```

## postUrl

Posts data to a URL and puts the response in an HTML tag using its `id` 

```html
<div id="some-content"></div>
<script>
    //without call back
    postUrl("/api/page", {"id": 1, "name": "test"}, "some-content", callback= null);

    //with call back
    postUrl("/api/page", {"id": 1, "name": "test"}, "some-content", function(data){
        console.log ("Post Url", data);
    });

</script>

```

## saveForm

Saves a form data to Post end point and puts the response in an HTML tag using its `id`

```javascript
saveForm(formName, targetURL, targetElement, callback = null)
```




