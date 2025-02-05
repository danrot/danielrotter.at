---
layout:
    post: true
title: The problem with indirections
excerpt: Indirections are invaluable for programming, since basically every programming concept makes use of one.
    However, we should still be careful when using them.

tags:
    - programming
    - php
    - javascript
    - vue
---

Almost any program we write makes heavy use of different kind of indirections, at least if it should be remotely useful.
Even though they are so fundamental to the everyday work of a software developer, we should always carefully consider in
which extent we want to use them, and more often than not I see certain indirections be heavily overused, which can
easily lead to hard-to-understand code.

But what exactly is an indirection? I like to think of it as something that hides something from me respectively
something that requires me to look something up somewhere else in order to understand the result.

## A overly simplified example

I have this topic on my mind for quite some time already, and recently I ran into [this post from Clemens
Helm](https://www.linkedin.com/posts/clemenshelm_ich-finde-diese-l%C3%B6sung-gro%C3%9Fartig-warum-activity-7262040621786259456-9AKz/),
which finally motivated me to write about it. I think that meme was originally posted on
[r/ProgrammerHumor](https://www.reddit.com/r/ProgrammerHumor/comments/1ax8zh6/taskdone/). Somebody asks for help with
the task "print numbers from 1 to 25 in a clockwise expanding spiral from center", and the other person responds with
the following code:

```python
print('21 22 23 24 25')
print('20  7  8  9 10')
print('19  6  1  2 11')
print('18  5  4  3 12')
print('17 16 15 14 13')
```

As Clemens has pointed out, this is kind of the best solution to the problem. Unless you need to print a spiral with
another value than 25, it does not make any sense to invest more time into this. However, quite often developers try to
come up with clever solutions – which are certainly fun to implement (otherwise you kind of miss the point of being a
developer) – even if a much simpler one would also do the job. This is commonly known as
[over-engineering](https://en.wikipedia.org/wiki/Overengineering). There is also the [YAGNI (You aren't gonna need it)
principle](https://en.wikipedia.org/wiki/You_aren%27t_gonna_need_it), which advices against writing code in a more
complicated manner than absolutely necessary. Sticking with the previous example, this means that you should not write
some complex algorithm if all you ever will do is calling that algorithm with a single value. If you fail to follow
these principles, it will lead to lots of unnecessary code that needs additional maintaining and is harder to understand
compared to code that is kept simple.

Now, as said, this example is overly simplified, but I want to show you some more examples of indirections that might
sometimes even hurt the maintainability of your code. Of course **the usage of certain patterns also comes with
advantages, but carefully consider whether or not the advantages outweigh the additional baggage they come with**.

I will also show how some frameworks introduce additional indirections that might be cumbersome, especially when you try
to debug your application. In the case of frameworks you also have to keep in mind that in addition to these
indirections, you are also vulnerable to breaking changes on updates, which is a serious drawback that should not be
taken lightly. So when choosing a framework make sure that it gives you more in return than you might pay in the long
run.

## Variables

Probably the most used indirection is using a variable. Of course variables make a lot of sense in many cases, without
them it would be impossible to build anything remotely dynamic. They might also make sense [to give something a name to
avoid adding an additional comment](/2021/01/16/code-comments-are-mostly-a-violation-of-dry.html).

However, there are also situations in which using a variable might make code more complicated to read. This is the case
when there is no variation in the value at all, and it is pretty much self-explanatory. The following example shows code
that is relatively hard to understand when you think about what it actually does.

```php
<?php

$greeting = 'Hello';
$name = 'Daniel';
$punctuation = '!';

echo "$greeting $name$punctuation";
```

Of course, if any of these parts could change due to external circumstances using variables makes total sense, but in
that case the code could be written much simpler by only putting the name into a variable (assuming that this is the
only part that might change).

```php
<?php

$name = 'Daniel';

echo "Hello $name!";
```

This way there is no need to look and maybe even jump to a completely different location to find the value of a
variable (the above example is still pretty simple, but the different variables might not be located right next to each
other in code). Therefore I am trying not to introduce variables unless they really serve some purpose.

## Methods and functions

[Extracting a function](https://refactoring.com/catalog/extractFunction.html) (or method) is one of the first ideas
people have when writing DRY code, since it helps a lot with not duplicating any information. And of course, this is a
good thing! However, keep in mind that when the code is read by another developer (or yourself in a few months) they
probably have to follow that function and also try to understand what it is doing when they are looking for a bug. So a
method should only be extracted when it either helps with readability or the code is actually used in multiple places.

**Something that has always bothered me a bit is when rules are blindly followed.** One such rule I remember is "avoid
nesting", which is usually done to have methods with a lower [cyclomatic
complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity). While it would be nice to have an objective number
telling if a function is good or bad, I am absolutely sure that solely relying on cyclomatic complexity is a bad idea.
One situation in which I have experienced such a rule was when I had to write code reading an XML file that had a
structure that forced me to use nested loops. I spare you the details, since I don't like XML (does anybody use that
nowadays anyway?) and role with a much simpler example.

Let's say we want to write a method that output the content of a two-dimensional array. This kinda calls for a nested
`for` loop.

```php
<?php

function printTable(array $table) {
    for ($i = 0; $i < count($table); $i++) {
        for ($j = 0; $j < count($table[$i]); $j++) {
            echo $table[$i][$j];
        }

        echo PHP_EOL;
    }
}
```

I think this code is pretty straightforward to read and understand, at least as long as it stays that simple. However,
if you work with somebody who has an unreasonable fear of nested `for` loops they will make you write code like this:

```php
<?php

function printTable(array $table) {
    for ($i = 0; $i < count($table); $i++) {
        printRow($table[$i]);

        echo PHP_EOL;
    }
}

function printRow(array $row) {
    for ($j = 0; $j < count($row); $j++) {
        echo $row[$j];
    }
}
```

Now you have introduced an indirection, which makes the code harder to follow, especially when the functions are a bit
longer and they do not fit your screen. Instead of just reading code from top to bottom and easily understand what is
happening you must jump to the definition of the `printRow` function and go back after you have read it. And the worst
part: **The nested for loop is still there, so from a runtime perspective nothing has improved.**

Again, of course there is some point at which it might make sense to extract a method, but doing it too early is
something I would consider premature optimization, which can make code even harder to read.

Another example is usage of the [`setUp` method in xUnit frameworks like
PHPUnit](https://docs.phpunit.de/en/12.0/fixtures.html#fixtures), which is even worse, since that call is happening
implicitly, i.e. it is called before the actual test method, without the actual test method referencing it in any way.
Let's have a look at the (stripped down) example from the official PHPUnit documentation (which is shown there just for
demonstration purposes, they even address some of the issues):

```php
<?php

final class ExampleTest extends TestCase
{
    private ?Example $example;

    public function testSomething(): void
    {
        $this->assertSame('the-result', $this->example->doSomething());
    }

    protected function setUp(): void
    {
        $this->example = new Example(
            $this->createStub(Collaborator::class)
        );
    }
}
```

Developers with experience in that testing framework will know about the setup method – especially when there is an
otherwise uninitialized property. But if the test gets more complex it might not be that obvious. And when the test is
written as follows, even developers without knowledge of the `setUp` method can easily understand what's going on.

```php
<?php

final class ExampleTest extends TestCase
{
    public function testSomething(): void
    {
        $example = new Example($this->createStub(Collaborator::class));
        $this->assertSame('the-result', $example->doSomething());
    }
}
```

Again, I am not saying never use the `setUp` method, I use them quite often myself (and probably would even do it in the
above example). However, **I always make sure to keep it minimal, which means most of the time I do the bare minimum to
initialize the system under test**. That is because if there is too much code in the `setUp` method it is very likely
that not all tests need that code to be executed, which makes your tests slower to run and harder to understand.

## Interfaces

Similar to my complaint about blindly following rules regarding methods before, I also think that interfaces are
sometimes overused. There is a saying "code against interfaces, not implementations", which is probably a big driver for
usage of the `interface` keyword. However, **keep in mind that does not necessarily mean that you need an `interface`
keyword**, since also a class has its own implicit interface, even if it does not implement one.

Also, the usage of interfaces has some disadvantages. First, it results in more code and therefore a higher complexity.
It also forces you to write the same signature at least twice in your code, once in the interface itself and at least
once in a class implementing that interface. This means you also need to update two places in case something about the
interface changes (although most programming languages resp. static analyzers will happily tell you when these
signatures do no match). Additionally, it also has some (negative) impact on the developer experience. **If you have
ever worked with a code base making heavy use of interfaces you know how cumbersome it is to always jump twice in your
IDE to get to the implementation** (first to the interface itself, then to the implementation of the interface).

Therefore I try to resist to introduce interfaces for all classes and only use them when it yields a real benefit. Some
example coming to my mind:

- Making use of [polymorphism](https://en.wikipedia.org/wiki/Polymorphism_(computer_science)), e.g. to loop over many
different objects implementing the same interface
- Reverse the relationship between different packages or modules using the [dependency inversion
principle](https://en.wikipedia.org/wiki/Dependency_inversion_principle)
- Introducing multiple implementations of the same interface, e.g. to introduce [an in-memory implementation of a
repository for tests](/2023/09/22/avoid-mocking-repositories-by-using-in-memory-implementations.html)

## CSS utility classes

I want to start with a disclaimer: I am probably one of the biggest [tailwind](https://tailwindcss.com/) opponent out
there. This has many different reasons, but in this post I only want to discuss the impact of the indirections
introduced by a utility-first CSS framework like tailwind.

First of all, the installation process of tailwind is not trivial. While with plain CSS you just use one `link` or
`style` tag (depending on you want the styles to be inlined in HTML or in a separate CSS file) the [getting started page
of tailwind](https://tailwindcss.com/docs/installation) lists five steps to get started, whereby in every step something
could go wrong.

In addition, **any framework using CSS utility classes requires the developers to learn about those classes**, which
seems like wasted time to me, especially when these utility classes are on such a low level that they do not abstract
anything, and you still need to know how CSS works under the hood to use them. I rather learn the CSS properties
instead, which will be useful for a much longer time than any classes introduced by a framework.

Another drawback is that using such utility-first frameworks kinda break the dev tools, or at the very least make them
less helpful. Take for instance a look at this HTML fragment I've taken from [tailwind's installation
page](https://tailwindcss.com/docs/installation).

```html
<div class="relative flex text-slate-400 text-xs leading-6">
    <div class="mt-2 flex-none text-sky-300 border-t border-b border-t-transparent border-b-sky-300 px-4 py-1 flex items-center">
        src/index.html
    </div>
    <div class="flex-auto flex pt-2 rounded-tr-xl overflow-hidden">
        <div class="flex-auto -mr-px bg-slate-700/50 border border-slate-500/30 rounded-tl"></div>
    </div>
    <div class="absolute top-2 right-0 h-8 flex items-center pr-4">
        <div class="relative flex -mr-2">
            <button type="button" class="text-slate-500 hover:text-slate-400">
                <svg /> <!-- omitted the SVG for brevity-->
            </button>
        </div>
    </div>
</div>
```

I would argue that **it is not easily possible to tell the purpose of each element, yet this is what you see when you
open the HTML inspector of your preferred browser**. It does not really look better for the styles shown in the
developer tools, when you click on one of the elements you see a long list of classes with mostly a single CSS property.
Both of these problems disappear when you use plain CSS in combination with semantic class names instead. Someone could
argue that these classes are also a level of indirection, but at the very least they are not coming from a framework and
they are in our control. So I think the following example is shorter, easier to understand, and there is no need to
learn about another indirection (utility classes and their abbreviations in this example).

```html
<div class="tabs-container">
    <div class="tab">
        src/index.html
    </div>
    <div class="empty-area-container">
        <div class="empty-area"></div>
    </div>
    <div class="icons">
        <div class="copy-to-clipboard-container">
            <button type="button" class="copy-to-clipboard-button">
                <svg /> <!-- omitted the SVG for brevity-->
            </button>
        </div>
    </div>
</div>
```

This way I can apply the exact same styles as in the previous example, but when I am looking at the HTML inspector,
which I find an invaluable tool, I have a much nicer time navigating the DOM tree. Also, when clicking on any element in
the inspector, the list of applied styles is easier to read, since there are a lot less classes involved.

## Referencing classes using strings

This is something I see a lot in Laravel, e.g. in its [Validation module](https://laravel.com/docs/11.x/validation). The
following lines show how incoming request data can be validated in Laravel:

```php
<?php

$validated = $request->validate([
    'title' => 'unique:posts',
]);
```

This is how you define in Laravel that the `title` property must be unique among all posts. In my opinion encoding this
information in just a simple string is not a good idea. The only advantage I see is its brevity, but this definitely
does not outweigh its disadvantages. First of all **you have to know the defined strings for validation rules, and I am
not sure if any IDE supports auto-completing these values**. Additonally it is another level of indirection: **If you
want to have a look at the implementation, then you would have to look up the key (e.g. `required`) somewhere manually,
in order to figure out which file or class implements that rule.**

Luckily Laravel also supports a cleaner version of the codee above:

```php
<?php

$validated = $request->validated([
    'title' => [Rule::unique('posts')],
]);
```

When writing the code like this, every proper IDE with PHP support will not only apply proper syntax highlighting, but
also enable you to jump to the definition of the validation rule. This is much more convenient when you want to figure
out what those rules do exactly.

Unfortunately, it is quite common for Laravel to optimize for brevity. This causes them to often recommend techniques I
would consider bad practices.

## Magic getters and setter

Another thing I realized while working with Laravel (especially Eloquent) is that using magic getters and setters can
also cause unexpected situations. Such a [magic
getter](https://www.php.net/manual/en/language.oop5.overloading.php#object.get) is e.g. implemented in Laravel's
[`Model` class](https://github.com/laravel/framework/blob/v11.38.2/src/Illuminate/Database/Eloquent/Model.php#L2258),
which calls the rather complicated [`getAttribute`
method](https://github.com/laravel/framework/blob/v11.38.2/src/Illuminate/Database/Eloquent/Concerns/HasAttributes.php#L464).

While this might make sense for an ORM to implement [lazy loading](https://en.wikipedia.org/wiki/Lazy_loading) in a
transparent way, it can still lead to wrong expectations, because accessing a property will not just read a value from a
property. Have a look at the following example (using the `Flight` example from the [Eloquent
documentation](https://laravel.com/docs/11.x/eloquent)):

```php
<?php

echo $flight->name;
```

Some developers might think it is safe to assume that this just reads the `name` property of the `$flight` object and
outputs it. However, **with the magic getter shown above, this code even might load something from the database, causing
a potential performance bottleneck in a seemingly innocent operation**. Additionally, this is also another indirection
(executing a function instead of just accessing a property), which needs to be understood by developers reading that
code.

Even though I am listing this here as kind of a negative example, I am still excited about the new [property hooks
feature in PHP](https://www.php.net/manual/en/language.oop5.property-hooks.php). I am well aware of the fact that these
property hooks allow to introduce the exact same problems, but there are still some valid use cases (like the lazy
loading example mentioned above). In my opinion they could also be useful to allow for a consistent class-level API
without forcing you to mix property accessors and getters.

```php
<?php

class Rectangle
{
    public function __construct(public readonly int $width, public readonly int $height) {}

    public int $area {
        get => $this->width * $this->height;
    }
}

$rectangle = new Rectangle(10, 20);

echo $rectangle->width;
echo $rectangle->height;
echo $rectangle->area;
```

By making use of property hooks we can avoid having a `width` and `height` property but a `getArea` method. The
alternative would be to make all three properties only accessible via a getter, but that would lead to lots of
boilerplate code.

However, I will try to restrict using these property hooks to only relatively simple operations (with some exceptions
like lazy loading). This way the potential performance issues caused by seemingly innocent code may be mitigated.

## State management libraries

Something I have already seen in many different code bases using frontend libraries like [React](https://react.dev/) and
[Vue](https://vuejs.org/) is that developers use advanced state management solutions (e.g.
[Redux](https://redux.js.org/), [Vuex](https://vuex.vuejs.org/), or [Pinia](https://pinia.vuejs.org/)) way too often.

Let me explain that by an example I stumbled upon some time ago. In a Vue project there was a component responsible for
displaying a share link. The link was displayed in a modal, which was shown after a button was clicked. It also included
additional functionality like having another button copying that link to the clipboard, but for the sake of the example
I am going to keep it minimal. I am also using Pinia instead of Vuex, and from my experience the Vuex impact would be
even bigger.

Although this is quite a simple component, it was implemented using a store. This resulted in a `ShareModel.vue` file
looking something like this:

```html
<script setup>
import {useShareModalStore} from './stores/share-modal.js';

const store = useShareModalStore();
</script>

<template>
    <dialog :open="store.open">
        <input readonly :value="store.url"></input>
    </dialog>
</template>
```

As you can see, all this component does is putting a URL into a readonly input field within a dialog, and the dialog is
only shown when the store's `open` property is set to `true`. While the above file looks pretty simple, we still need to
implement the store returned by `useShareModalStore` ourselves. This is usually done in a separate file
`stores/share-modal.js` that could be implement as follows:

```javascript
import { ref } from 'vue'
import { defineStore } from 'pinia'

export const useShareModalStore = defineStore('share-modal', () => {
    const open = ref(false);
    const url = ref(null);

    function show() {
        open.value = true;
    }

    function setUrl(newUrl) {
        url.value = newUrl;
    }

    return {open, url, show, setUrl};
});
```

**So just for storing a URL with a boolean flag indicating whether or not a modal should be shown we rely on another
dependency (Pinia)**. The information is stored in a [`ref`](https://vuejs.org/api/reactivity-core.html#ref), which is
returned in a JavaScript object along with some methods that allow to manipulate it.

Of course, we also need a third file, which acts as glue code. It makes use of the same store, sets the URL to be
shared, and adds a button that calls the `show` method when it is clicked:

```html
<script setup>
import {useShareModalStore} from './stores/share-modal.js';
import ShareModal from './ShareModal.vue';

const store = useShareModalStore();
store.setUrl('http://www.danielrotter.at');
</script>

<template>
    <button @click="store.show()">Share</button>
    <ShareModal />
</template>
```

This is not only quite a lot of code for such a simple feature, it also comes with a serious limitation: **This
component cannot really be used multiple times on a page, at least not if you want to offer different share URLs.** The
reason for this is that stores are global, and therefore changing the value of a store would affect all of the component
instances. There is nothing wrong with this library, it is just not built for this use case, but that is a different
story.

So there is quite some added complexity, especially when comparing it to the simple Vue-only version. In that case the
information is passed via props to the component:

```html
<script setup>
defineProps({open: Boolean, url: String});
</script>

<template>
    <dialog :open="open">
        <input readonly :value="url"></input>
    </dialog>
</template>
```

There is no need for a store at all, instead the information about the URL can be passed as a simple prop to the
component, which also allows setting different URLs for each component instance. The `open` state can be created as a
`ref` in the parent component, and also passed via a prop.

```html
<script setup>
import {ref} from 'vue';
import ShareModal from './ShareModal.vue';

const open = ref(false);
</script>

<template>
    <button @click="open = true">Share</button>
    <ShareModal :open="open" url="www.danielrotter.at" />
</template>
```

This is not only less code, there are also less dependencies (causing much less effort for updates), and the code is
easier to understand.

## Command bus

A few years ago the concept of command buses became popular in PHP. [Matthias Noback wrote a nice introduction
article](https://matthiasnoback.nl/2015/01/a-wave-of-command-buses/), and for this article I am blatantly stealing his
example.

The basic idea of a command bus is that it handles commands, which are represented in very simple command classes like
the following:

```php
<?php

class SignUp
{
    private $emailAddress;
    private $password;

    public function __construct($emailAddress, $password)
    {
        $this->emailAddress = $emailAddress;
        $this->password = $password;
    }
}
```

Then, instead of having some weird logic in the controller, we have a clear border between HTTP and our domain, since
the **controller's only task is to create an object of a simple command object and pass it to the command bus**, whose
responsibility it is to execute this command:

```php
<?php

class UserController
{
    public function signUpAction(Request $request)
    {
        $command = new SignUp(
            $request->request->get('emailAddress'),
            $request->request->get('password')
        );

        $this->commandBus->handle($command);
    }
}
```

However, the command bus does not and cannot know how to handle a command class you have made up completely by yourself.
Therefore there must be another component, which is a command handler. This class contains the code that is actually
handling the command:

```php
<?php

class SignUpHandler
{
    public function __construct(UserRepository $userRepository)
    {
        $this->userRepository = $userRepository;
    }

    public function handle($command)
    {
        $user = User::signUp($command->emailAddress, $command->password);

        $this->userRepository->add($user);
    }
}
```

Of course there are good reasons to implement something like that. The code in the controller is very minimal, and
implementing a console command that does something similar becomes almost trivial – the code is basically the same, the
only change is that you do not get the data from a request but from some other kind of input.

But as usual, this does not come without downsides. A very common problem is that you cannot have a proper return value
from a command bus, since depending on the command that is being passed you might wish to return something different.
Also, it comes with some additional overhead, which you usually feel when debugging your application. **If you step into
the call to the command bus, you might have to go a few more layers deep in order to get to the command handler you have
implemented on your own.** This makes debugging harder, since depending on the behavior you want to inspect, you might
end up in the same code location multiple times, which forces you to use something like conditional breakpoints. And
this is not the only time this adds some complexity.

Especially if you do not have a good reason to make use of a command bus (like e.g. [transaction
handling](https://matthiasnoback.nl/2015/01/responsibilities-of-the-command-bus/)), you could get some of the advantages
with a much simpler architecture.

Usually I still like to have command classes for every action the user can trigger. But instead of passing it to a
generic command bus, I just pass it to a service, which is very boring (but in a good way!):

```php
<?php

class UserController
{
    public function signUpAction(Request $request)
    {
        $command = new SignUp(
            $request->request->get('emailAddress'),
            $request->request->get('password')
        );

        $this->userService->signUp($command);
    }
}
```

And then the `UserService` acts as the handler of the command:

```php
<?php

class UserService
{
    public function signUp(SignUp $command)
    {
        $user = User::signUp($command->emailAddress, $command->password);

        $this->userRepository->add($user);
    }
}
```

This approach shares quite some advantages, but it is much simpler, since there is no generic command bus sitting in
between. This code can easily be statically analyzed, does not need any external dependencies, and is much easier to
debug.

## Conclusion

In general many indirections result in a worse debugability (I guess that is part of maintainability, but in my opinion
that would warrant its own term), more code, and therefore more stuff that could go wrong, especially if external
dependencies are used. **Therefore I advice you to stop for a moment before you use another indirection, and think about
if the additional complexity is actually worth it.** In my experience the answer to this question is way more often "no"
than you might think.
