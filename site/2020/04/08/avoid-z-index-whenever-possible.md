---
layout:
    post: true
title: Avoid z-indexes whenever possible
excerpt: Whenever I use z-indexes, I am going to regret it at some point, especially with libraries utilizing components. Let's see if we can avoid them all together.

tags:
    - html
    - css
    - javascript
    - react
---
When I first heard about the `z-index` css property it sounds like such a helpful and innocent concept. But after some
years of using them I would declare them the
[billion dollar mistake](https://en.wikipedia.org/wiki/Null_pointer#History) of web development. But let me explain that
in a bit more detail.

## Some history

Back in the days using `z-index` was the way to go if you wanted to make sure that some of your HTML content was
displayed on top of your other content. The main use case for that would be any kind of overlay or dialog, which tries
to get the user's attention. Often these components also disallow to click anywhere outside themselves, so that the user
has to take care of them. Since this is a very aggressive way of gaining attention, these elements were used very rarely
on websites. Maybe there was a single overlay on the entire website to get your user to sign up for your newsletter (not
that I've been a big fan of those...) or an overlay to show an image gallery.

Since the use cases were so limited, it was not a big deal to handle them. An implementation of such an overlay might
have looked something like this:

```html
<!DOCTYPE html>
<html>
    <head>
        <style>
            .overlay {
                width: 300px;
                height: 200px;
                background: lightgray;
                position: absolute;
                z-index: 10;
                top: 30px;
                left: 100px;
                font-size: 0.5em;
            }
        </style>
    </head>
    <body>
        <h1>My headline</h1>
        <h2>My subheadline</h2>

        <div class="overlay">
            <h2>My overlay content</h2>
        </div>
    </body>
</html>
```

*You can check out [this codepen](https://codepen.io/danrot/pen/RwPzNeK) to see the results.*

Of course I am talking about pre-HTML5 times here, when you had to add `text/css` as a type to your `style` tag and use
a much more complex `DOCTYPE` I was too lazy to look up now. Actually the above example would not even need the
`z-index` definition, but it was still used a lot in cases like this, because some other component might already have
had a `z-index` applied.

But the point remains: Putting an overlay like this on your website was not much of a big deal, also because the amount
of other elements using a `z-index` was manageable.. But then something interesting happened: The web was getting more
and more interactive. Companies decided to use the web as a plattform for applications they have previously built as
desktop software. And software like this is a lot more complex than a website or even some documents CSS was originally
designed to style. And this is when it started to get messy. Until today I see CSS containing properties like the
following:

```css
.overlay {
    z-index: 99999 !important;
}
```

**Basically it was just putting higher numbers to your z-index, to make sure nothing else was on top of your overlay.**
At least until you wanted to place something on top of that overlay, in which case you just came up with an even higher
number. And I think you can imagine that this does not scale very well.

So since then `z-index` was probably the css property I was most obsessed about. It just seems so unbelievably hard to
understand this concept. One of the biggest problems is probably that these values are compared among each other, and if
there are loads of them it easily gets too complex to manage. I did some research on how to tame that complexity, and
stumbled upon a few interesting approaches.

## Draw inspiration from game development

In a [CSS-Tricks article](https://css-tricks.com/handling-z-index) I have encountered one of these
interesting approaches. They use an idea which seems to be very popular in game development, which is putting all used
`z-index` values in a single file. Since not all browsers
([looking at you, IE11](https://caniuse.com/#search=variables)) support the the new
[CSS custom properties](https://developer.mozilla.org/en-US/docs/Web/CSS/--*) you usually have to use some kind of
preprocessor like SCSS to implement that.

```scss
$zindexHeader: 1000;
$zindexOverlay: 10000;
```

There are two interesting points to make about this approach:

1. Leaving some space between the numbers allows for easy addition of more `z-index` values later.
2. Having all values defined enables developers to be aware of all `z-index` values.

However, in order for that work, you have to make sure that there is no `z-index` property in your code base, which is
not using a variable of this file.
[This article also contains a comment](https://css-tricks.com/handling-z-index/#comment-1580226) with a nice variant of
this approach. Instead of defining values using numbers, it makes use of SCSS lists and a function retrieving the index
of the given value from that list. The advantage is that you don't even have to think about any numbers anymore, and
inserting a new value is as easy as placing it correctly in the list. This sounds awesome, right?

## Introducing stacking contexts

The thing is that even if you would be strictly following this rule, there might still be situations with an unexpected
outcome. That is because of the
[stacking context](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Positioning/Understanding_z_index/The_stacking_context)
defined in the HTML specification. Browsers will apply the `z-index` values only within the stacking context the element
was defined. Let's see an example to make it easier understand what that means.

```html
<!DOCTYPE html>
<html>
    <head>
        <style>
            .box-1, .box-2, .box-3 {
                position: absolute;
                width: 100px;
                height: 100px;
            }

            .box-1 {
                top: 20px;
                left: 20px;
                z-index: 1;
                background-color: blue;
            }

            .box-2 {
                top: 20px;
                left: 20px;
                z-index: 3;
                background-color: red;
            }

            .box-3 {
                top: 60px;
                left: 60px;
                z-index: 2;
                background-color: green;
            }
        </style>
    </head>
    <body>
        <div class="box-1">
            <div class="box-2"></div>
        </div>
        <div class="box-3"></div>
    </body>
</html>
```

If you are reading this without any knowledge about stacking contexts, you would probably say that the red box with the
class `box-2` should be appearing on the very front. In case you thought so, you can have a look at
[this codepen](https://codepen.io/danrot/pen/JjdQogG) for prove that this is really not the case.

The reason for this behavior is that the blue box also has a `z-index` value. Its value of `1` is lower then the value
`2` of the green box, so the browser ensures that the blue box --- **including its content** --- will stay below the
green box. So the `z-index` value of `3` of the red box will only be compared to other child elements of the blue box.
[Philip Walton did a great job at explaining this in more detail](https://philipwalton.com/articles/what-no-one-told-you-about-z-index/).
And this somehow makes sense, because that might be what you want when you are only comparing `box-1` and `box-3`. The
developer writing the rules for these two elements probably wanted to ensure that `box-3` is on top of `box-1`,
independant of their children.

Unfortunately it is very likely that this contradicts with the behavior the developer implementing the overlay would
expect. I assume that the reason people are adding such high `z-index` values, is that they want to be a 100% sure that
the elements are always visible. Too bad that the highest value doesn't help, if the element is part of a stacking
context. But it gets even worse: A new stacking context is not only introduced when an element has a `z-index` attached,
but also with a few other properties (see the
[full list on MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Positioning/Understanding_z_index/The_stacking_context)).
So even if whatever you have build is currently working, other developers might break it by adding any of these
properties to any ancestor of your element without even realizing it (I can't blame them, they might not even know there
is an element like this in the subtree).

**TL;DR: `z-index` and stacking contexts are very complex.**

These problems might not even occur on a website written using plain JavaScript. Just put the overlays right before the
closing `body` tag, and they will appear on top of everything else. At least if there is no other `z-index` set
somewhere, because the browser will render elements appearing later in the HTML source on top of elements that appear
sooner. That part actually sounds quite easy, right?

The problem is that with libraries endorsing thinking in components (like e.g [React](https://react.dev/)) this is not
that easy to achieve. That's because a component somewhere deep in the component tree might want to render an overlay,
that should appear on top of all the other elements, no matter where it is located in the source code. Let's assume your
application has a structure like this:

- App
    - `Header`
    - `Form`
        - `Input`
        - `Textarea`
        - Submit Button
        - Confirmation Dialog

I guess it would not be uncommon for the `Header` and `Form` component to have some `z-index` value, to ensure that the
`Header` will be display in front of the `Form` component. If the form is now rendering a dialog to confirm e.g. storing
the provided information, it is not possible to display this dialog in front of the `Header`, if the component structure
is repesented in the same way in the DOM.

But let's assume that no other `z-index` --- or any property creating a new stacking context --- is used in the
application. Even then you are running into problems, because in React you might want to implement a single `Overlay`
component, that can be reused in multiple places. If you are displaying multiple of them, it might also be tricky to
display the correct one in front of the other. That's because the `Overlay` component has always the same `z-index`
value. If you are relying on the `z-index` for this kind of stuff, you would probably have to pass a `z-index` prop to
your React components. And that feels as if we are doing the full circle and go back to where we've started: **Trying to
find a higher number than everybody else.** But fortunately the blog post is not finished yet.

## Where to go from here?

I feel like I have just ranted a lot until now, but I think it is important to understand what lead me to the decision I
am going to explain next. I was facing with two different `z-index` issues when working on [Sulu's](https://sulu.io/)
administration interface within a very short amount of time. So I've decided to put a bit more effort into this. I took
inspiration from the classic [*JavaScript: The Good Parts*](http://shop.oreilly.com/product/9780596517748.do). It has been
quite some time since I've read this book, and I know that JavaScript changed a lot rendering some of the advices in
this book obsolete, but I still like its general idea. Getting rid of stuff that is causing troubles. So that was
exactly what I did:
[I removed (almost) all `z-index` values from Sulu's codebase.](https://github.com/sulu/sulu/pull/5138) Might seem a bit
radical, but I am sure this will pay off in the long run.

You might think that your special use case requires `z-index` in order to make everything work, but we are building a
relatively complex single page application, and I was able to get rid of all `z-index` properties. I think what I did
can be broken into two different tasks.

At first I have to say that **it is really incredible how many `z-index` properties you can avoid by just correctly
order your elements in the DOM.** You want to make sure that some kind of elements to edit an image appear on top of the
image? Try to just put these elements after the image in your HTML source, and it will already work! No `z-index` at all
is required for that, and you will avoid that any of the above reasons might break your application. I think that was
the most important realization when trying to avoid `z-index`es.

There was only one element that was not that easy to transform using this advice: The header with the always visible
toolbar in our administration interface. The problem is that it appears at the very top and putting it first in HTML is
one way of achieving that. But if the header comes first, I would have had to add a `z-index` to let it appear in front
of the content that comes after it. I then tried to move the header at the end of that container, but then it appeared
on the bottom of it (and I didn't want to start using `position: absolute` or something like that, since that comes with
its own set of problems, which would probably fill a separate blogpost). For a short time I thought it does not matter,
but then I realized that the header has a box-shadow, that is hidden behind elements that are coming below the header in
HTML.

```html
<!DOCTYPE html>
<html>
    <head>
        <style>
            * {
                margin: 0;
                padding: 0;
            }

            header {
                height: 20vh;
                background-color: steelblue;
                box-shadow: 0 1vh 1vh teal;
            }

            main {
                height: 80vh;
                background-color: ivory;
            }
        </style>
    </head>
    <body>
        <header></header>
        <main></main>
    </body>
</html>
```

*This [codepen](https://codepen.io/danrot/pen/abOgvEG) shows that the teal `box-shadow` of the header is not visible.
Very tempting to use a `z-index`...*

The solution I came up with was to put the header at the end of the container, and use `flex-direction: column-reverse`
to the container element. That makes the header element appear on top of the others because it shows up later in the
source code, but still was display on the top of the screen, because flexbox reverses the order of the elements. I've
tried something similar with the `order` CSS property, but without any luck. I am not totally sure how this approach
impacts accessibility, but I guess fiddeling around with `z-index` values does also not help a lot with that.

```html
<!DOCTYPE html>
<html>
    <head>
        <style>
            * {
                margin: 0;
                padding: 0;
            }

            body {
                display: flex;
                flex-direction: column-reverse;
            }

            header {
                height: 20vh;
                background-color: steelblue;
                box-shadow: 0 1vh 1vh teal;
            }

            main {
                height: 80vh;
                background-color: ivory;
            }
        </style>
    </head>
    <body>
        <main>
        </main>
        <header>
        </header>
    </body>
</html>
```

*This [codepen](https://codepen.io/danrot/pen/yLNdYjX) shows how changing the order of the elements and use
`column-reverse` also does the trick without needing a `z-index`.*

Now the only remaining open question is how a component like an overlay fits into that equation, especially if a
component deep in the component tree wants to render it. Actually
[React has a built-in concept called portals](https://legacy.reactjs.org/docs/portals.html) helping exactly with that.
Portals allow to break out of the DOM of the parent component. This also fixes other problems with overlays, like the
fact that if the parent has `overflow` set to `hidden` it is not possible to display anything outside the parent
container. We use portals quite a lot, and append stuff at the end of the body tag. Since the elements are now rendered
at the very end of the `body` tag --- and we don't have any other `z-index` set --- setting a `z-index` is not necessary
at all! The only drawback I ran into was that the order in the DOM seems to be dependant on when the portal code is
called. That lead to a confusing situation I was able to fix quite fast, and it didn't make any problems anymore. Still
feels like something that is good to know and might help debugging situations like this.

Last note: I mentioned that I removed only almost all `z-index`. Some are still necessary, but only because of some
third party libraries making use of `z-index`. The solution there was to set a `z-index` of `0` on my own on a parent
container of these libraries. That introduced a new stacking context, which ensures that these elements of these
libraries are not shown in front of e.g. our overlays. But "not relying on `z-index`" still made it to my criteria list
for evaluating libraries.

Finally I want to say: **Whenever you are about to add a `z-index` --- think very hard if there is really no better
solution.**
