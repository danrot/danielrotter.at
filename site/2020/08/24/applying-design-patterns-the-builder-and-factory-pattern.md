---
layout:
    post: true
title: "Applying design patterns: The builder and factory pattern in a DI context"
excerpt: Creating objects is a very basic task. Although this seems like a simple problem, it can be improved by using patterns like builder and factory.
last_modified_at: 2020-09-10

tags:
    - php
    - oop
    - symfony
---

Quite a while ago I have [implemented something called `RouteBuilder`](https://github.com/sulu/sulu/pull/4276)(has been
renamed to `ViewBuider` in the meantime) in [Sulu](https://sulu.io/), which - as the name suggests - makes use of the
[Builder pattern](https://en.wikipedia.org/wiki/Builder_pattern) in order to create different routes in a Sulu
application. In addition to the Builder pattern the
[Factory pattern](https://en.wikipedia.org/wiki/Abstract_factory_pattern) was also used.

**For me the hardest part of learning such patterns was to get an idea when it makes sense to use them.** Therefore I
decided to report about my usages of design patterns, to hopefully give other people an idea how they could be applied.
So this is the first blog post of a potential series covering the Builder and Factory pattern.

## The downsides of an abstract model

In order to better understand why we have chosen to use these patterns, I will try to explain the inconviences we had
to deal with before. The use case was to create something we called `Route` at the time (now it has been renamed to
`View`), which is a representation of a URL of our
[Single Page Application](https://en.wikipedia.org/wiki/Single-page_application).  This `Route` did not only contain
the URL itself, but also a reference to a [React](https://reactjs.org/) component, which should be shown if the defined
URL was active. Since we also needed to reference routes in the system, we also added a name parameter to the route.
These were the crucial parts of a route, and always had to be given, so we decided to put them into the constructor of
the `Route` class. We didn't want to implement a separate React component for every single route, therefore we made
them configurable by using options placed on the route.

```php
(new Route('sulu_tag.datagrid', '/tags', 'sulu_admin.datagrid'))
    ->addOption('title', 'sulu_tag.tags')
    ->addOption('resourceKey', 'tags')
    ->addOption('adapters', ['table'])
    ->addOption('addRoute', 'sulu_tag.add_form.detail')
    ->addOption('editRoute', 'sulu_tag.edit_form.detail');
```

The above example shows the definition of such a `Route` in PHP. `sulu_tag.datagrid` is the name of the route, `/tags`
is the route that will be displayed in the browser's address bar and `sulu_admin.datagrid` is a string referencing a
React component in the frontend. This component was implemented in a highly configurable manner, so that we could not
only use it for tags in the previous example, but also for all other kind of entities we have in our system. This is
what the `resourceKey` option is describing.

I would argue that if you have a little knowledge about our domain, you would be able to guess what most of these
options are doing. **However, it is still cumbersome for the developer who writes code like this:**

- The names of options (`title`, `resourceKey`, ...) are **not obvious** and **your IDE cannot support you via auto
  completion.**
- The content of these options **can't be validated**, since the `Route` is an abstraction for many different type of
  routes.
- The **instantion of the `Route` is hardcoded** and the implementation can't be replaced. That was not necessary in
  our case, but might be necessary in others.

We knew that these obstacles are impairing the developer, but we still liked the idea of having a single `Route` class,
because this was the only case we had to handle in our frontend code. Otherwise we would have to take care of a
`FormRoute`, `DatagridRoute` and so on in our frontend code, which didn't seem really nice as well.

Luckily the Builder pattern enabled us to overcome these obstacle by introducing well defined interfaces to create
these routes while still maintaining a single `Route` class.

## Instantiate objects with the Builder pattern

The Builder pattern is one of the creational patterns, which means in an OOP context that it takes care of
instantiating objects. It does so by creating a `Builder` class with an interface that allows to partly build that
object. So even if you have some object that must know many different things at its construction time, you can still
pass all of them separately, if you have a `Builder` as a separation layer between getting that information and the
object instantion. Let's have a look at the implementation of such a `RouteBuilder`, which applies the `Builder`
pattern to our `Route` class mentioned above:

```php
<?php
namespace Sulu\Bundle\AdminBundle\Admin\Routing;

class DatagridRouteBuilder
    implements DatagridRouteBuilderInterface
{
    private $route;

    public function __construct(string $name, string $path)
    {
        $this->route = new Route(
            $name,
            $path,
            'sulu_admin.datagrid'
        );
    }

    public function setResourceKey(
        string $resourceKey
    ): DatagridRouteBuilderInterface
    {
        $this->route->setOption('resourceKey', $resourceKey);

        return $this;
    }

    public function setTitle(
        string $title
    ): DatagridRouteBuilderInterface
    {
        $this->route->setOption('title', $title);

        return $this;
    }

    // Omitted some of the methods for brevity

    public function getRoute(): Route
    {
        if (!$this->route->getOption('resourceKey')) {
            throw new \DomainException(
                'A route for a datagrid view needs a '
                . '"resourceKey" option. You have likely '
                . 'forgotten to call the "setResourceKey" '
                . 'method.'
            );
        }

        // Omitted more checks for brevity

        return clone $this->route;
    }
}
```

So instead of instantiating the `Route` as shown above with all of its drawbacks, the instantiation of the `Route` can
be replaced with something like this:

```php
(new DatagridRouteBuilder('sulu_tag.datagrid', '/tags'))
    ->setResourceKey('tags')
    ->setTitle('sulu_tag.tags')
    ->addDatagridAdapters(['table'])
    ->setAddRoute('sulu_tag.add_form.detail')
    ->setEditRoute('sulu_tag.edit_form.detail')
    ->getRoute();
```

So with the introducation of the `DatagridRouteBuilder` we have solved some of the problems mentioned above:

- By **using specific methods** instead of options with a string key **the IDE can support you with auto completion**.
- Before returning the `Route` from the `getRoute` option **its options can be validated**.
- By introducing a `DatagridRouteBuilderInterface` the **instantiation process can also be replaced**.

And in addition to the `DatagridBuilder` we have e.g. also introduced the `FormRouteBuilder`, which does something
very similar and gets also rid of these problems. And the best thing is that the `getRoute` method of both builders
still return a `Route` object, so we can still easily iterate over all available routes, and know how to handle them.

In the above example the `Route` class is instantiated right away and the other `Builder` methods only call the
`setOption` method to assign the correct values. The nice thing is that you could even postpone the creation of the
object to the getter method of the `Builder` if necessary, allowing you to define an constructor making sure that the
object is valid starting from the very beginning while making the creation of such an object comfortable for the
developer.

*Mind that in our case the `Router` constructor can still be called directly, which might lead to invalid routes. We
have accepted that tradeoff to have a single `Route` object and avoid creating a deep inheritance hierarchy.*

Another advantage is that the `Builder` object can also be passed as argument to other functions taking part in the
object creation process. Let's say in your application you have some configuration you want to add to a few `Datagrid`
routes. In that case you could implement that part in a function:

```php
<?php
function enhanceDatagridRoute(DatagridRouteBuilder $builder) {
    $builder->addDatagridAdapters(['table']);
}
```

At Sulu we have used a [similar approach](https://github.com/sulu/sulu/blob/0114e8c95b28e006173b9236b85656aba590984e/src/Sulu/Bundle/SecurityBundle/AccessControl/AccessControlQueryEnhancer.php#L32)
a few times for the [`QueryBuilder` of
Doctrine](https://www.doctrine-project.org/projects/doctrine-orm/en/2.10/reference/query-builder.html).

```php
<?php
function enhance(
    QueryBuilder $queryBuilder,
    UserInterface $user = null,
    string $entityClass,
    string $entityAlias
) {
    $queryBuilder->leftJoin(
        AccessControl::class,
        'accessControl',
        'WITH',
        'accessControl.entityClass = :entityClass '
        . 'AND accessControl.entityId = ' . $entityAlias . '.id'
    );

    $queryBuilder->setParameter('entityClass', $entityClass);
}
```

This simplified example from the Sulu codebase will make a join to our access control table, and that can be reused for
every query we make. This way of doing things is enabled by the use of `Builder` pattern. Doing something similar with
[plain DQL](https://www.doctrine-project.org/projects/doctrine-orm/en/2.10/reference/dql-doctrine-query-language.html)
would require being much more careful about building the query from the very beginning, which might be very cumbersome
and not a good developer experience. Therefore I almost always use a `QueryBuilder` instead of DQL.

## Make the builder replacable by the Factory pattern

Previously the `DatagridRouteBuilderInterface` was introduced and I have listed the possibility to replace the
`Builder` implementation as an advantage. But actually this is still not possible, since the only difference is that
the instantiation of a different class has been hardcoded. The `DatagridRouteBuilder` needs to have a separate instance
for each object being created, because it contains state about the current building process. That means we can't easily
inject it by using e.g. Symfony's dependency injection, because a service is always considered exactly one instance.
Instead another creational pattern can be used: The Factory pattern.

A factory also encapsulates the creation of an object, although it does it in a different way than the Builder pattern.
But that shouldn't stop us from using the Builder and Factory pattern in combination. A very important difference
between these patterns is that a `Factory` can be instantiated a single time, due to the fact that it returns the new
object immediately and therfore does not need to keep any state. That means that we can avoid constructing this class
in our code directly (which is kind of a bad practice in a dependency injection context anyway) and can inject the
`Factory`.  This means that the `Factory` implementation can be replaced easily, by simply changing the argument passed
to the constructor of the class using that `Factory`. The following code snippet shows how such a factory could look
like:

```php
<?php
namespace Sulu\Bundle\AdminBundle\Admin\Routing;

class RouteBuilderFactory implements RouteBuilderFactoryInterface
{
    public function createDatagridRouteBuilder(
        string $name,
        string $path
    ): DatagridRouteBuilderInterface
    {
        return new DatagridRouteBuilder($name, $path);
    }

    public function createFormRouteBuilder(
        string $name,
        string $path
    ): FormRouteBuilderInterface
    {
        return new FormRouteBuilder($name, $path);
    }
}
```

By doing so the creation of the above `DatagridRoute` changes:

```php
$this->routeBuilderFactory
    ->createDatagridRouteBuilder('sulu_tag.datagrid', '/tags')
    ->setResourceKey('tags')
    ->setTitle('sulu_tag.tags')
    ->addDatagridAdapters(['table'])
    ->setAddRoute('sulu_tag.add_form.detail')
    ->setEditRoute('sulu_tag.edit_form.detail')
    ->getRoute();
```

The `routeBuilderFactory` member variable can be assigned by using dependency injection, making that part of the code
replacable and testable. Mission accomplished!

## Conclusion

By applying the `Factory` and `Builder` pattern we made our code cleaner, more testable and more self-documenting. It
also introduced a language that is known among other developers as well, since `Builder` and `Factory` are patterns
that are widely known. This solution also allows model your domain in a way that actually makes sense, since you can
defer the creation of an object until all information is available. So the constructor can be built in a way that
guarantees you that the object state is valid.

Usually is said that the `Builder` pattern is great when you want to create an object in multiple steps. But I think it
is also great when you have a complex constructor of an object, because it fixes the issue of guessing what the 7th
appearance of `true` in the calling code means. So it can also be a substition if you use a PHP version that does not
support [named parameters](https://wiki.php.net/rfc/named_params) yet.
