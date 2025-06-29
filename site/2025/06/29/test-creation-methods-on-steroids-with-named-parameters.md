---
layout:
    post: true
title: Test creation methods on steroids with named parameters
excerpt: Creation methods are a well-known pattern in testing. But they are even more powerful when used with named parameters.

tags:
  - testing
  - php
---

In [my previous blog post about writing high quality tests](/2024/10/19/writing-high-quality-tests.html) I mentioned
that writing test code in the most minimalistic way will improve maintainability in the long run by a lot. One pattern
that helps with that is the [creation method pattern](http://xunitpatterns.com/Creation%20Method.html), especially when
the object to be created is complex to set up and some of the required attributes are not important for the test at
hand. Also, it helps to avoid using the constructor of objects directly making it a lot easier to adjust the tests when
the constructor changes.

The original description of the creation method pattern has some variations, the two most important ones for this blog
post being:

- Anonymous Creation Method
- Parameterized Creation Method

In the examples of the pattern description there are methods like `createAnonymousCustomer` or
`createCreditworthyCustomer`, which would look something like this in PHP:

```php
<?php

private function createAnonymousCustomer()
{
    return new Customer('John', 'Doe');
}

private function createCreditworthyCustomer(string $firstName, string $lastName)
{
    return new Customer($firstName, $lastName, true);
}
```

*The `createCreditworthyCustomer` in that example just sets a third parameter to be true, which indicates that the
customer is creditworthy. There would probably be better solutions to this problem, but I want to keep it simple.*

This is already quite nice, because it allows you to write tests without having to set all `Customer` parameters
manually even if you don't care about them. However, the number of methods required can easily explode, depending on
which set of parameters you want to set in your tests. Maybe you also want to have a test creating an anomymous
creditworthy customer, or a customer with a bank account but the name of the customer does not matter for the test (for
which reason you don't want to mention any names in the test to keep it minimal).

The good news is that it is relatively easily possible to cover all those use cases if you are using a language that
supports [named parameters](https://en.wikipedia.org/wiki/Named_parameter) like e.g.
[PHP](https://www.php.net/manual/en/functions.arguments.php#functions.named-arguments). In that case you can have just
one `createCustomer` method handling all fields of the customer, give each parameter a default value, and then only set
the ones you need in a single test:

```php
<?php

private function createCustomer(string $firstName = 'John', string $lastName = 'Doe', bool $creditworthy = true)
{
    return new Customer($firstName, $lastName, $creditworthy);
}
```

Depending on how often this method is needed, it can be placed as a private method on a test class or implemented using
a [trait](https://www.php.net/manual/en/language.oop5.traits.php), so that it can be reused in multiple different test
classes.

And now it is really easy to use that creation method in your tests without passing all parameters every time (which is
not so bad with 3 constructor parameters, but imagine there are more).

If there is a test testing if the invoice is correctly generated you probably might want to assert if the right name is
used. In that case you set the `firstName` and `lastName` parameters of the `createCustomer` method:

```php
<?php

public function testGenerateInvoice()
{
    $customer = $this->createCustomer(firstName: 'Daniel', lastName: 'Rotter');

    // ...
}
```

In another case you might want to check if customers not being creditworthy are rejected:

```php
<?php

public function testRejectNonCreditworthyCustomer()
{
    $customer = $this->createCustomer(creditworthy: false);

    // ...
}
```

And if your test just needs a customer because another object requires it, but you don't care about the values at all,
you can create an anonymous customer by calling the method without any parameters (and you should do so, to convey to
the reader that the test does not care about the customer's attributes):

```php
<?php

public function testOrderMinimumQuantity()
{
    $customer = $this->createCustomer();

    // ...
}
```

As you can see this allows to have a minimal implementation effort (only one creation method per class), while still
keeping all the advantages of that pattern. Happy testing!
