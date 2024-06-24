# Annotating End Points for Swagger

We use the swagger-ui to document our end points, the swagger-ui interface is shipped as part of the framework and is available on the `/swagger` route.
If you have not done any documentation on swagger it will simply have the title from the `.env` file.
Start by changing the `.env` to describe your API end point.

## Setting the .env variables
Use the following reference to see where to change your API description.

**.env**
```dotenv
[Open API]
SWAGGER_TITLE=Project Name
SWAGGER_DESCRIPTION=Description of your project
SWAGGER_VERSION=1.0.0
```

## Annotating end points

There are a number of annotations that can be used to annotate end points effectively:

| Annotation   | Description                                                                                                                |
|--------------|----------------------------------------------------------------------------------------------------------------------------|
| @secure      | Secures any end point requiring it to be authed with a formToken or Basic Auth                                             |
| @description | Describe the end point that is being used and what it does                                                                 |
| @summary     | Summary of what the end point does                                                                                         |
| @tags        | Comma separated list of tags for the end point, end points will be grouped  <br/> in the documentation by these categories |
| @params      | Free form inputs to be passed as query parameters on the URL                                                               |
| @queryParams | Same as @params                                                                                                            |
| @example     | Can be a JSON string or simply an ORM class <br/> or Object that should be used to describe the JSON post data             |

## Example of an annotated REST end point

In the example below we have annotated the "sign up" end point, feel free to copy and paste the code to test the swagger documentation.

```php
/*
 * @description Sign up a user to the system
 * @tags users,sign up
 * @example {"firstName": "Name", "lastName": "Last Name", "email": "Email"}
 * @params limit,skip
 * @summary Signs up a user
 */
\Tina4\Post::add("/sign-up", function(\Tina4\Response $response, \Tina4\Request $request) {

    return $response($request);
});
```

Below is how the swagger will look

![](/img/example_annotation_signup.png)

And then if we open up the end point to test we should get this:

![](/img/example-test-end-point.png)


## Hot Tips
>- Any end point which is not a GET is annotated automatically with `@secure` 
>- Use .env `API_KEY` variable to setup a quick Bearer token to secure your API.
