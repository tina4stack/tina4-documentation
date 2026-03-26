# Threads
::: tip 🔥 Hot Tips
- Debug using file_put_contents()
- Beware race conditions if multiple threads are running concurrently.
- Adds value to using them with [Services](services.md)
  :::
## Creating the thread
Threads are very easily created and can be passed variables.
```php
Thread::addTrigger("myFirstThread", function ($myVariable){
    // run code here
});
```

## Triggering the thread
This one line, will spin up a separate php thread, loading in Tina4 and then the anonymous function in the Thread declaration.
```php
Thread::trigger("myFirstThread", "Variable passed to the thread");
```