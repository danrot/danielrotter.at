---
layout:
    post: true
title: Some reasons for disliking react hooks
excerpt: React has introduced hooks to replace classes. Some people are huge fans, while I am a bit more skeptical. An explanation.
last_modified_at: 2022-02-12
tags:
    - javascript
    - react
---

[React hooks](https://legacy.reactjs.org/docs/hooks-intro.html) have been introduced in React 16.8. Their aim is
described on the react documentation:

> They let you use state and other React features without writing a class.

Quite soon after the announcement I had a look at them, and I was running through the following cycle since then:

1. I disliked hooks, mainly because they were new and it's probably people's nature to be skeptical about new things,
although most developers (including me) are probably too skeptical.
2. Then I got used to them and started to like them because they have certain advantages.
3. Now I am not that fond of them anymore, since I ran into some unexpected problems and realized that I have a hard
time explaining them in my university courses to students.

I could imagine that there are some people out there that ran through the same stages. In this blog post, I want to
explain my reasoning.

## Positive aspects of hooks

Skipping my first phase of disliking hooks (which, as usual, is a bit uncalled for) I would like to explain some of the
reasons I like them after I got used to them.

### Hooks compose nicely

What is objectively nice about hooks is that they compose in a very nice way. There are some prebuilt hooks
([`useState`](https://legacy.reactjs.org/docs/hooks-state.html) and
[`useEffect`](https://legacy.reactjs.org/docs/hooks-effect.html) are probably the most prominent ones), that **can be
easily used in hooks built in a custom way for projects**, and a custom hook is just another function that might reuse
existing hooks. A simple made-up scenario would be a custom hook, that also returns the doubled value of a state, which
could be implemented because the doubled value is required quite often in a web application (for whatever reason).

```javascript
function useStateWithDouble(initialValue) {
    const [value, setValue] = useState(initialValue);

    return [value, setValue, value * 2];
}
```

This `useStateWithDouble` hook returns not only the value itself and a function to set it, but also the doubled value,
which could then be easily used in a react component.

```javascript
function App() {
    const [value, setValue, doubledValue] = useStateWithDouble(0);

    return (
        <>
            <input
                onChange={(event) => setValue(event.target.value)}
                type="number"
                value={value}
            />
            <p>Value: {value}</p>
            <p>Doubled value: {doubledValue}</p>
        </>
    );
}
```

There is no real limit on what can be done within such a custom hook, it is also possible to mix many different calls
to the `useState`, `useEffect`, and all the other hooks, a custom hook can even reuse another custom hook. This allows
for very easy code reuse among different components.

### `useEffect` is really nice

Another thing I like is the idea of the `useEffect` hook (although I think hooks are not absolutely necessary for that
idea). Previously [lifecycle
methods](https://legacy.reactjs.org/docs/state-and-lifecycle.html#adding-lifecycle-methods-to-a-class) had to be used
instead. They allowed to execute code when e.g. the component was mounted into or unmounted from the DOM, but the
problem was that code that actually belongs together was split. E.g. if a component that counts the elapsed seconds was
developed, then a `setInterval` was started when the component mounted and `clearInterval` was called when the component
was unmounted. This is exactly what the `componentDidMount` and `componentWillUnmount` functions in the code below are
doing.

```javascript
class App extends React.Component {
    constructor() {
        super();

        this.state = {
            seconds: 0,
        }
    }

    componentDidMount() {
        this.interval = setInterval(() => {
            this.setState({
                seconds: this.state.seconds + 1,
            });
        }, 1000);
    }

    componentWillUnmount() {
        clearInterval(this.interval);
    }

    render() {
        return <p>{this.state.seconds}s ellapsed!</p>;
    }
}
```

The code for the interval is split among these two lifecycle functions, which is already bad enough, but it gets even
worse when there is more than one piece of code that needs a setup like this because then the `componentDidMount` and
`componentWillUnmount` functions do not follow the [single responsibility
principle](https://en.wikipedia.org/wiki/Single-responsibility_principle) anymore. The following code shows an example
of that by also counting minutes.

```javascript
class App extends React.Component {
    constructor() {
        super();

        this.state = {
            seconds: 0,
            minutes: 0,
        }
    }

    componentDidMount() {
        this.secondsInterval = setInterval(() => {
            this.setState({
                seconds: (this.state.seconds + 1) % 60,
            });
        }, 1000);

        this.minutesInterval = setInterval(() => {
            this.setState({
                minutes: this.state.minutes + 1,
            });
        }, 60000);
    }

    componentWillUnmount() {
        clearInterval(this.secondsInterval);
        clearInterval(this.minutesInterval);
    }

    render() {
        const {minutes, seconds} = this.state;

        return <p>{minutes}m and {seconds}s ellapsed!</p>;
    }
}
```

The same code can be implemented a lot cleaner using the `useEffect` hook. The effect can return a function, which is
the cleanup function. This way the code that belongs together also is also colocated in the source, like the
`setInterval` and `clearInterval` calls in the code below.

```javascript
function App() {
    const [seconds, setSeconds] = useState(0);
    const [minutes, setMinutes] = useState(0);

    useEffect(() =>  {
        const interval = setInterval(() => {
            setSeconds((seconds) => (seconds + 1) % 60);
        }, 1000);

        return () => clearInterval(interval);
    }, []);

    useEffect(() => {
        const interval = setInterval(() => {
            setMinutes((minutes) => minutes + 1);
        }, 60000);

        return () => clearInterval(interval);
    }, []);

    return (
        <p>{minutes}m and {seconds}s ellapsed!</p>
    );
}
```

## Negative aspects of hooks

Let us switch to the negative parts of hooks that made me at least like them a lot less than after the first honeymoon
phase. There are workarounds for some of these issues, but they **make some concepts hard to explain**, and in my
opinion, this is a sign that not everything is solved in the best possible way, and that there might be some underlying
issues.

To me, it feels like the authors of react dislike classes too much. Sure, there are some issues with classes in
JavaScript, the most prominent example is the **[binding of `this`](https://web.dev/javascript-this/), which sometimes
behaves differently than in other object-oriented languages**. But using [class
properties](https://babeljs.io/docs/en/babel-plugin-proposal-class-properties) worked quite well, so this is not really
an argument for me. And this hatred against classes leads me to my first point.

### Functions do not simply map input to output anymore

I think they have worked too hard to get rid of classes, up to a state that they were willing to overlook some serious
downsides of the hooks approach. But most importantly, this decision **broke a very important invariant of functions,
namely that a function will return the same value if the same input parameters are passed**. The main reason for that
is the `useState` hook.

```javascript
export default function App() {
    const [count, setCount] = useState(0);

    return (
        <button onClick={() => setCount(count + 1)}>
            Clicked {count} times
        </button>
    );
}
```

The above code shows what I mean by that. Whenever the `button` has to be rerendered, the function is executed again.
But even though in all cases the function is called without any arguments, there is no clear mapping to the output,
the output is different every time instead. `useState` introduces some side effects, something that has been frowned
upon, especially in functional programming, because it makes hunting bugs harder. It is not possible to tell if the
component is working just by calling it with some parameters because it now has some internal state. Sure, that is
also a downside of object-oriented programming, but it is expected in object-oriented programming, for functions not so
much. So **I think that stuff having an internal state should be modeled using classes and objects instead of
functions.**

Additionally, there are many hooks like `useState`, `useRef`, or `useMemo` that seem to replicate the behavior that
would be quite easy to be implemented in classes, which makes this decision even less understandable for me.

### `useState` introduces staleness

Another issue is that hooks avoid the `this` keyword, but introduce another problem called staleness. This is
demonstrated in the below (not functional) example.

```javascript
function App() {
    const [seconds, setSeconds] = useState(0);

    useEffect(() => {
        const interval = setInterval(() => {
            setSeconds(seconds + 1);
        }, 1000);

        return () => clearInterval(interval);
    }, []);

    return <p>{seconds} seconds ellapsed!</p>;
}
```

The above example will only count to 1 and seems to stop then. The issue is that the `seconds` variable in the
`useEffect` hook will always be taken from the first render, where `seconds` was set to `0` because this is [how
closures work](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Closures). Therefore the `setSeconds` called
every second will always calculate `0 + 1` and assign 1 to the state, causing the seconds to hang from an end-user
perspective. This issue can be fixed by passing a function to `setSeconds`, which will retrieve the current value as an
argument.

```javascript
function App() {
    const [seconds, setSeconds] = useState(0);

    useEffect(() => {
        const interval = setInterval(() => {
            setSeconds((seconds) => seconds + 1);
        }, 1000);

        return () => clearInterval(interval);
    }, []);

    return <p>{seconds} seconds ellapsed!</p>;
}
```

So the problem with `this` was fixed by replacing it with another one; instead of having to know how classes and the
`this` keyword work, developers have to know how closures work, and they can lead to even sneakier bugs in my opinion.
If `this` is accidentally bound to a wrong value for whatever reason, then there will be an error in the developer
console. But as the above example show, the example with hooks will continue to work somehow, just not in the expected
way.

However, this can sometimes also be the desired behavior, as [Kent C. Dodds describes in his blog
post](https://epicreact.dev/how-react-uses-closures-to-avoid-bugs/), but interestingly I cannot remember a time where
the problem described in this blog post was a serious issue in my development work.

### Return values are somehow weird

Some people might also think that the return values of e.g. the `useState` hook is a bit weird (probably even the react
team themselves, since [they devoted an own section in the documentation for
it](https://legacy.reactjs.org/docs/hooks-state.html#tip-what-do-square-brackets-mean)).

```javascript
export default function App() {
    const [count, setCount] = useState(0);

    return (
        <button onClick={() => setCount(count + 1)}>
            Clicked {count} times
        </button>
    );
}
```

The `useState` call in the above code makes use of array destructuring. `useState` will return an array, containing:

- First, the current value of the state
- Second, a function to update the state and rerender the current component (i.e. re-execute the function)

When the function is re-executed, the `useState` hook will return a different value for `count`, but in a new function
execution. Therefore the `count` variable can have a different value on each execution, although it is defined as
`const`.

In order to retrieve the value and update function array destructuring is used. **This decision has been made to allow
the variables however you wish because they are assigned by their position.** The `useState` hook itself does not name
that at all.

So, while this might make sense with this explanation, I would not say that this is very intuitive. **The below code
might be more verbose, but I think it is easier to understand what is happening.**

```javascript
class App extends React.Component {
    constructor() {
        super();

        this.state = {
            count: 0,
        };
    }

    render() {
        const {count} = this.state;

        return (
            <button
                onClick={() => this.setState({count: count + 1})}
            >
                Clicked {count} times
            </button>
        );
    }
}
```

**In addition, it makes sense that the class resp. object has an internal state, something that rather confuses in the
example with the functional component and hooks.**

### `useEffect` has a strange second parameter

Even though `useEffect` is probably my favorite hook, it has still a rather strange syntax, which makes it not that
easy to explain. Especially the second parameter is weird, which describes when the effect should be executed. It does
that by comparing each element of the second parameter (which is an array), and if they differ from the previous
render, then first the old cleanup function is executed and afterwards, the effect is run again.

Once understood that makes perfect sense, but it is not that easy to explain. Again, that is a sign for me, that there
might be an easier solution that makes fewer problems. It is also not that easy to recognize when the effect is
executed.

```javascript
useEffect(() => {
    console.log('Executed after every render');
});

useEffect(() => {
    console.log('Executed only after component has mounted')
}, []);
```

The above two examples are not that easy to differentiate, so for a developer not being that familiar with react it
might be hard to remember this. The old lifecycle functions had their fair share of problems, for which reason I think
it is a step forward, **but having methods on a class called `componentDidMount`, `componentWillUmount`, etc. was more
explicit and easier to understand for developers reading such a code for the first time**.

Another thing that bothers me is that the `useEffect` hook is always taken as an example of why hooks are better than
classes, but I think that is mixing two different things. **The idea of effects is great, but they should be seen
decoupled from hooks.** I think effects could have also been implemented using classes in one or the other way.

### `useMemo` and `useCallback` might not even help with performance

The other thing is that some hooks force developers to generate even more code, which might cause performance to be
worse, even for hooks like `useMemo` and `useCallback` that are actually made for improving performance. However, that
only works in certain situations. [Kent C. Dodds has written another blog post about
this.](https://kentcdodds.com/blog/usememo-and-usecallback) **The main takeaway is that when using `useCallback` or
`useMemo` there is already another function call and array definition, and the performance win has to outweigh this
additional work.**

When developing classes this is more or less already solved, at least apart from a few possible confusing scenarios
regarding the `this` keyword. But as mentioned above, until now I have had no problems, if class properties were used.

I still want to do a benchmark to compare how much of a difference there is between a class component with a class
property function and a component using inline functions with hooks. Unfortunately, I didn't have time yet, but this
might be the topic of a future blog post.

## Conclusion

Summed up I can agree with the fact, that there are some advantages with hooks, especially with `useEffect`. But
especially the `useEffect` hook could probably also be implemented using classes, at least in theory. Unfortunately,
there is no way to use something like effects with class components, which would be great because the concept has clear
advantages over the lifecycle methods.

But at the same time, it feels like hooks are just reimplementing some features of classes in functions, and from my gut
feeling, they are mainly combining the worst of both worlds. There are no pure functions anymore, so they have
integrated some of the drawbacks of classes.

When classes were introduced in JavaScript, there were a lot of people in the community that were against them, and I
guess they have not changed their minds until today. It somehow feels like a compromise, and neither party is really
happy. Functional JavaScript developers will never use classes, and people with an OOP background will still wonder
that they work a little bit differently from the classes they know from other programming languages. It would probably
be best to have two different programming languages here so that both parties are closer to their favorite
programming language. But unfortunately, JavaScript is the only language for client-side development… Hopefully,
WebAssembly will also allow communicating with the DOM one day so that there is room for many different programming
languages built on top of it.

These thoughts are coming off the top of my head, if you agree/disagree or have other issues with hooks please let me
know on
[Twitter](https://twitter.com/search?q={{ site.url }}{{ page.url }})!
