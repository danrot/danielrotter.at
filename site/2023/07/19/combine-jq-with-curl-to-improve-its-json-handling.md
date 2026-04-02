---
layout:
    post: true
title: Combine jq with curl to improve its JSON handling
excerpt: jq is a nice JSON processor, which is helpful when working with JSON outputs, no matter if they are retrieved using curl or any other command.

tags:
    - cli
    - http
    - json
    - logging
---

As you might have realized in some of my other blog posts I am a bit of a CLI aficionado, and for this reason, I do not
like tools like [Postman](https://www.postman.com/) despite their rich feature set. To be precise, I don't like them
exactly for their rich feature set, since it takes me ages to find the exact option I am looking for. Finding the right
option might be as hard in CLI tools as in GUI tools, but once the option has been discovered, there are much better
ways to reuse them (creating an alias, a script, finding it in your shell history, ...).

**There is an obvious and well-known CLI replacement for at least some of Postman's functionality:
[curl](https://curl.se/).** In my opinion, it is even better, since it comes with a - at least compared to Postman -
reduced feature set, but following the Unix philosophy, it is possible to use it in combination with other commands.

Another option I know is [HTTPie](https://httpie.io/cli), which is like curl on steroids focused on APIs. It comes with
a CLI API that is simpler than curl's and has other amazing features like built-in JSON highlighting. However, I still
decided to continue using curl, since the arguments I need are not that numerous and were not too hard to remember once
I really tried. Also, it is kind of the industry standard, so it is easier to find documentation for it, and it is often
better integrated in other software, e.g. **most browsers have an option in their developer tools to copy network
requests as curl commands, which includes all headers, cookies, etc. that were included in that request, which makes
seven testing an API that needs authentication**.

![The "Copy as curl" option in the Firefox developer tools](/images/posts/firefox-copy-as-curl.webp)

I do not know of any browser offering a similar option for HTTPie, and that alone is enough reason for me to stick with
curl.

Fortunately, there is the [`jq`](https://jqlang.org/), which is a command-line JSON processor. The great thing about it
is that it allows you to pretty print JSON, filter and/or transform it, etc., but does not care about where it gets its
input from. **Therefore it is very versatile and can be used in many different scenarios.** One scenario for which I
used it recently is to pretty print the log output of a Kubernetes container, which used JSON as log format. It was
hardly possible to read that output, therefore I used `jq` without any arguments to pretty-print the output, which
results in syntax-highlighted and properly formatted text that is easy to read. The example command `cat log.json | jq`
in the following screenshot uses a simple file for demonstration purposes, but it does not matter where the command
before the pipe gets the content from, as long as it outputs it.

![`jq` highlighting JSON results in a much easier to read text](/images/posts/jq-highlighted-json.webp)

`jq` would even allow filtering e.g. by the level of the log message using its [`select`
function](https://jqlang.org/manual/#select), and there are many other possibilities.

Combining `jq` with the `curl` command results in a JSON output from an HTTP API to be shown properly indented and with
syntax highlighting, which is one of the best features of HTTPie. The command for this would be something like that:

```plaintext
curl http://127.0.0.1:8000/something.json | jq
```

But it does not even stop there. `jq` also allows filtering deeply nested JSON objects, which I found particularly handy
when I was working at [Sulu](https://sulu.io/). There we implemented a configuration request, which was used by the
administration SPA to retrieve quite some initial data. This configuration request also contained configuration data
from different modules, so it looked somehow like this (omitted a lot of data in objects and arrays to keep it brief):

```json
{
  "sulu_admin": {
    "fieldTypeOptions": {},
    "internalLinkTypes": {},
    "localizations": [],
    "navigation": [],
    "routes": [],
    "resources": {},
    "smartContent": {},
    "user": {},
    "contact": {},
    "collaborationEnabled": true,
    "collaborationInterval": 20000
  },
  "sulu_contact": {},
  "sulu_media": {},
  "sulu_page": {},
  "sulu_website": {},
  "sulu_preview": {},
  "sulu_trash": {},
  "sulu_security": {}
}
```

So when I implemented something that should update a value in this big configuration I found it quite hard to find the
desired value when requesting the data in the browser. So what I did instead was to use `jq` to filter for the exact
value I needed to see.

If I e.g. wanted to check if the `collaborationInterval` was adjusted accordingly I used the "Copy as curl" option from
my browser's developer tools, pasted it into the terminal (in the example below I omitted all HTTP headers for brevity,
although depending on your application some might be necessary), and piped it through a `jq` command with a filter only
returning the `collaborationInterval` value:

```plaintext
curl 'https://127.0.0.1:8000/admin/config' | jq .sulu_admin.collaborationInterval
```

**This allows me to just executed the last command in my history, again and again, to see if the value I was trying to
update.** And that even without looking for it in a huge pile of JSON.

`jq` is a really powerful tool, and there are many more opportunities to use it. I highly recommend checking out the [jq
Manual](https://jqlang.org/manual/) if you are working with JSON a lot, I am sure there are some ways you can
benefit from it!
