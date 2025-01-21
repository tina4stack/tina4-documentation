# Posting Forms

If you are used to posting forms in the traditional manner to the webservice then you should pay attention to the following:

!!! note "Posting Forms"
    - All POST requests are secured
    - You need to pass a `formToken` input value to be validated.



## Example Forms using the Filter and Global Mechanism

Using a global

```twig title="login.twig"
<form name="login" method="post">
    <input type="name" value="" placeholder="Some value to post">
    {%  set token = formToken({"page":"Login"}) %}
    <input type="hidden" name="formToken" value="{{ token }}">
    <button>Submit</button>
</form>
```

Using a filter, notice the use of `RANDOM` to refresh the output of the filter.  The result is a hidden input with a fresh token.

```twig title="login.twig"
<form name="login" method="post">
    <input type="name" value="" placeholder="Some value to post">
    {{  "Login"~RANDOM() | formToken }}
    <button>Submit</button>
</form>
```

!!! tip "There are three ways you can get a formToken in Tina4."
    - Calling a JINJA filter "formToken"
    - Calling a JINJA global "formToken()"
    - Getting the FreshToken value from an already authenticated header.
