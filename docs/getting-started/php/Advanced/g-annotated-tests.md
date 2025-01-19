# Annotated Tests

The most common way to write tests in PHP is using PHPUnit or Codeception, but they require a lot of configuration and may
be hard to use for beginners. Our functional testing framework is done using annotations and simple evaluations. It is a good way
to start your test driven development journey.  Once you have the basics running you can then move on to PHPUnit or Codeception.

## Our first test

The first example is a simple test checks if the answer of the sum of two numbers is actually correct. We will look at how we can go about the process of TTD.
First we create the function that will return the sum of two numbers, we deliberately return 0 as we want to check if our tests work.

```php
function addNumbers($a,$b) : int
{
    return 0;
}
```

Next we add a single test using the ```@test``` annotation and then ```assert```.  We want to assert if the sum of 1 and 2 is 3.  The message if the test fails is after the assertion separated by a comma.
So our pattern for a test is as follows: ```assert method(arguments) === expected, message```  The ```===``` operator can be replaced with any other operator.

```php
/**
* @tests
*   assert addNumbers(1,2) === 3, 1 + 2 is not 3
*/
function addNumbers($a,$b) : int
{
    return 0;
}
```
  

