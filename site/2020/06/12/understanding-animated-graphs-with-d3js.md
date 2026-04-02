---
layout:
    post: true
title: Understanding animated graphs in D3.js
excerpt: Building a graph is a pretty straight forward task in D3.js, but I've had a hard time understanding how to update them. This is a try to explain why.
tags:
    - javascript
    - d3js
    - visualization
    - svg
---

[D3.js](https://d3js.org/) is a great and in my opinion very elegant library for building visualizations in a web
browser. Unfortunately some concepts are not that easy to understand from its documentation, especially when it comes to
animathing graphs. I made that experience myself and when I tried to teach these concepts to my students using the
[official resources](https://github.com/d3/d3/wiki).

I am sure that [ObservableHQ](https://observablehq.com/@d3/learn-d3) is a great way to tinker and learn more about
certain features, but its nature of being inspired by a spreadsheet that automatically updates makes it hard to
understand how these features have to be combined in a real world application.

Therefore I am going to try to explain my (and maybe also other's) troubles when learning D3.js by using a quite simple
example. This won't cover many different features of D3.js, but it will explain the parts I feel are the hardest to
understand. This guide adds some pieces to the [introduction available on the D3.js homepage](https://d3js.org/) that
would have made learning D3.js easier for me.

*The below examples assume that the `d3` variable and a `<svg>` tag is in scope. This can be done by e.g. using a script
tag [as described in the D3.js documentation](https://github.com/d3/d3/wiki#installing).*

```html
<svg />
<script src="https://d3js.org/d3.v5.js"></script>
```

## Building a simple graph

Basically D3.js allows you to generate different markup (e.g. HTML or SVG) based on data. Let's have a look at an
example, which will visualize the numbers of an array as differently sized circles.

```javascript
const data = [10, 30, 20];

d3.select('svg').selectAll('circle')
    .data(data)
        .join(
            (enter) => enter
                .append('circle')
                    .style('fill', 'red')
                    .attr('r', (d) => d)
                    .attr('cx', (d, i) => (i + 1) * 50)
                    .attr('cy', 50)
        )
```

The `data` variables holds the data we want to visualize. In order to do so, we need the
[`d3.select` function](https://github.com/d3/d3-selection#select), which returns a
[D3.js selection](https://github.com/d3/d3-selection). Such a selection acts as a wrapper for the DOM, which focuses on
mass manipulation using data. The `d3.select` function returns a selection with the first element matching its passed
CSS selector, therefore the only `<svg>` tag in our HTML document. D3.js makes use of a
[fluent interface](https://www.martinfowler.com/bliki/FluentInterface.html) enabling us to use the just returned
selection and make another [function call `selectAll`](https://github.com/d3/d3-selection#selectAll). This will return
all [`cirlce` elements](https://developer.mozilla.org/en-US/docs/Web/SVG/Element/circle) being a descendant of the
first `<svg>` tag in our document. This feels a bit weird, because this results in an empty selection, but we'll get to
that in a second.

So using the `d3.select('svg').selectAll('circle')` call, we have an empty selection, because no circle exists within
the `<svg>` tag yet. Now we can assign our `data` variable using the
[`data` function](https://github.com/d3/d3-selection#selection_data). This will give us a data selection knowing which
elements we have to add to our visualization. And this is where it starts to get interesting.

Such a data selection offers a [`join` method](https://github.com/d3/d3-selection#selection_join), taking up to three
arguments. In the above example only one of the arguments has been used, being a function taking the `enter` selection.
This selection holds all the values from our data set (`10`, `30` and `20`) currently not being tied to a SVG `circle`
element. Since no elements exist yet, it's our job to create them. This is what the
[`append` method](https://github.com/d3/d3-selection#selection_append) does. We called it with the `'circle'` argument,
which means there will be three `circle` elements once the call is finished, one for every missing data point.

Afterwards the [`style`](https://github.com/d3/d3-selection#style) and
[`attr`](https://github.com/d3/d3-selection#selection_attr) calls are used on these circles, in order to style them in
some way. Checkout the [`circle` documenation on
MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/circle) in order to learn about the available
properties. These functions are not only taking simple values; they also accept functions as arguments. **If a function
gets passed, this function will be called with the value (the `d` variable) and the index (the `i` variable) of the
current data point.** This way we can set the radius `r` to the passed value, and move the circles to the right using
the index to calculate the `cx` attribute.

With these few lines of code we have already created three red circles with a radius of 10, 30 and 20 pixels.

## Updating a current selection

Until now we only have a static representation of three values as circles. That's not really interesting so far; we
could have simply written a few lines of SVG ourselves to achieve the same result. The popularity of D3.js comes from
its more advanced features. Let's see how we can change the data when a new data set arrives. At the beginning I was
wondering how this works, since it was not evident from the documentation. **Basically the trick is to call the exact
same code again with a different data set.** D3.js will then find out which elements have already existed, which ones
have to be added, and if any of the elements have to be removed. The only thing we have to do (besides calling that
code once more) is to tell D3.js how it should handle these different sets of elements.

We do that by passing more function parameters to the `join` method. The third parameter handles the elements that are
about to be removed, and the second one handles the elements that have already existed before based on the `selectAll`
call, which explains why it has been there in the above code from the beginning. We will put the entire D3.js code from
above into a separate function, which will be called again when new data arrives. So the `selectAll` will only return an
empty set on its very first call, but the consecutive calls of it will return the old `circle` elements.

The following code shows that concept and assume that you have a `<button>` tag somewhere in your HTML, that will load
the next data set when it is clicked (no out-of-bounds check for brevity):

```javascript
const data = [
    [10, 30, 20, 40],
    [20, 20, 20],
    [40, 10, 20, 10, 20],
    [20, 10, 20],
];

let currentIndex = 0;

document.getElementsByTagName('button')[0].addEventListener(
    'click',
    () => update(++currentIndex)
);

function update(index) {
    d3.select('svg').selectAll('circle')
        .data(data[index])
            .join(
                (enter) => enter.append('circle'),
                (update) => update,
                (exit) => exit.remove(),
            )
                .style('fill', 'red')
                .attr('r', (d) => d)
                .attr('cx', (d, i) => (i + 1) * 50)
                .attr('cy', 50);
}

update(0);
```

The `data` variable now contains an array of arrays, whereby the inner array is interpreted as a single data set. We
have a index variable that starts with `0`, and each click on the first button of the document will call the `update`
function and increase the value of the index. The `update` function contains the D3.js specific code, but also uses the
`index` parameter to access the current data set. As explained before the `join` method is used with 3 callbacks:

1. The **`enter` callback** is called for data points not being currently represented in the visualization. In here the
`append` method is used to add a `circle` SVG element for each new data point.
2. The **`update` callback** is called for data points that were already represented in the visualization. At the
moment we don't do anything special with these elements, so we are just returning that set.
3. The **`exit` callback** is called for elements in the visualization, that do not have a data point in the new data
set anymore. This example uses the `remove` method to delete these elements immediately.

*In case you are familar with [React](https://react.dev/), you can think of D3.js doing a similar job: You just tell it
what should happen on each case, and D3.js figures out for you when to call which function.*

Since except for appending new circles for the `enter` set we often want to handle the `enter` and `update` set in the
same way, the `join` method will merge these two sets and return the combination of both. So the return value of the
`join` method can be used to set styles and other attributes to both of these sets (we could also have added the
subsequent method calls to directly in the `enter` and `update` callback, which is usually done when the handling
between those sets differs). That part of the code has just been copied from the first example.

## Add transitions for smoother animations

The previous example changed the visualization on every button click, but it still does not really feel like a
sophisticated visualization. D3.js also comes with support for transitions, which will make the animations a lot
smoother. The most important method to achieve this is called
[`transition`](https://github.com/d3/d3-transition#selection_transition), and returns an object similar to a D3.js
selection. **After calling `transition` you can use the `attr` and `style` methods as described previously, but instead
of being immediately applied, these changes will be animated.** In order to control the speed of the animation, this
selection-like object also contains the [`duration` method](https://github.com/d3/d3-transition#transition_duration).
For delaying the animation the [`delay` method](https://github.com/d3/d3-transition#transition_delay) is available.
Both of these functions take a parameter being interpreted as milliseconds.

There is a very important side note: **A transition object, despite its similarity, is not a D3.js selection.** If a
transition instead of a selection is passed, D3.js might throw errors. For this reason the
[`call` method](https://github.com/d3/d3-selection#selection_call) exists. The `call` method will execute the passed
function, but instead of returning the value the passed function returns, it will always return the selection on which
the `call` method was executed. This way the method chain can be broken into pieces, without creating separate
variables bloating our code. See the following example, which just shows a new body for the `update` function above:

```javascript
d3.select('svg').selectAll('circle')
    .data(data[index])
        .join(
            (enter) => enter.append('circle')
                .attr('r', 0)
                .attr('cy', 50),
            (update) => update,
            (exit) => exit.call((exit) => exit
                .transition()
                    .duration(500)
                        .attr('r', 0)
                        .remove()
            )
        )
            .transition()
                .duration(500)
                    .attr('r', (d) => d)
                    .attr('cx', (d, i) => (i + 1) * 50)
```

This is almost the same code as above, but three crucial changes were made in order to animate the transitions between
the data sets:

1. **The `transition` method is called after the `join` method.** This way we tell the merge of the `enter` and
`update` set of the `join` method that the subsequent `attr` calls should be animated, with a duration of 500 ms.
2. **The `enter` set of the `join` method gets a `r` and `cy` value immediately.** These values are the start values
before the animation. Setting the `cy` immediately and leave it untouched will cause the circles to move only on the
x-axis.
3. **The `exit` set of the `join` method uses also the `transition` and `duration` calls.** The `attr` method is called
again after the `transition` method, which will make the cirlce shrink until it is not visible anymore. The `remove`
of the transition will remove the element after the animation has finished (in contrast to the `remove` method of the
standard selection, which would remove the element immediately). Although not necessary for the `exit` set (because it
will not be further manipulated), the `call` method has been used, in order to return a proper selection and not a
transition from the third callback.

## Identify data points by using keys

This already makes a pretty slick visualization! But another important piece is missing: The circles currently do not
have any identity. That means if more numbers than previously have been passed the difference is being passed to the
`enter` set, and if less number are passed the difference is passed to the `exit` set. But in many cases this is not
enough. Imagine the visualization of an election: There might be two new parties and one party doesn't exist anymore,
so there should be some elements in the `enter` and in the `exit` set. **In order to make this possible, we have to be
able to identify the data somehow. And this is why the key function in the `data` method has been introduced.**

We are going to use the above code to show the result of different elections. I know that a bar diagram would be the
better approach to this visualization, but we are going to use the circles again, so please bear with me. In order to
make the circle identifiable by D3.js, and also allow it to move the existing circles instead of just making them
disappear and appear again, we are going to make use of the `key` function passed as second parameter to the `data`
method. We are also not using plain numbers as data anymore, but objects consisting of a `fill` and a `value` property.
The `value` replaces the previous number, and the `fill` property describes the color of the circle and acts as the
identifier of the circle. Let's have a look at the code:

```javascript
const data = [
    [
        {fill: 'green', value: 30},
        {fill: 'red', value: 18},
        {fill: 'blue', value: 9},
    ],
    [
        {fill: 'black', value: 35},
        {fill: 'red', value: 27},
        {fill: 'green', value: 18},
        {fill: 'pink', value: 3},
    ],
    [
        {fill: 'red', value: 30},
        {fill: 'green', value: 15},
        {fill: 'black', value: 14},
        {fill: 'pink', value: 6},
    ],
];

let currentIndex = 0;

document.getElementsByTagName('button')[0].addEventListener(
    'click',
    () => update(++currentIndex)
);

function update(index) {
    d3.select('svg').selectAll('circle')
        .data(data[index], (d) => d.fill)
            .join(
                (enter) => enter.append('circle')
                    .style('fill', (d) => d.fill)
                    .attr('r', 0)
                    .attr('cy', 50),
                (update) => update,
                (exit) => exit.call((exit) => exit
                    .transition()
                        .duration(500)
                            .attr('r', 0)
                            .remove()
                )
            )
                .transition()
                    .duration(500)
                        .attr('r', (d) => d.value)
                        .attr('cx', (d, i) => (i + 1) * 50)
}

update(0);
```

It again looks very similar to what we've had before, except for a few minor differences I want to highlight:

1. **The `data` variable has changed as described previously.** It is an array of array, whereby the inner array
contains objects with a `fill` color and a `value`. The result of an election might be represented in a similar way.
2. **The `data` function gets a second argument passed, which is called the `key` function.** We return the `fill`
value of the `data` variable, which will be used as the identifier of the circle.
3. **In the `transition` after the `join` call the `attr` call for `r` has to be adapted**, because the data point is
an object instead of a number now.

Now D3.js is able to correctly assign the circles to the `enter`, `update` and `exit` sets. When clicking through the
different data points, the circles should now be keeping their color and move around. If this is not done correctly,
the circles will change their color instead of moving the correct location. That might easily defeat the purpose of
such a visualization, because it what happened to the data is not clear to the viewer this way.

## Conclusion

Hopefully the above points help others to understand D3.js faster than I did. **Finally I want to say that it might be
easier in many cases to use a simpler charting library, but these libraries are not that powerful, and you might hit
dead ends quite soon.** Once you have understood D3.js, you are also pretty fast at developing simple bar and line
chart, while keeping the possibility to turn your chart into something much more sophisticated if required. And as an
additional bonus: Visualizing data is fun!
