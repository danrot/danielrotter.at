---
layout:
    post: true
title: Batch curl requests in PHP using multi handles
excerpt: Sending many requests in a PHP script might not be a straightforward task, especially if you want to do that in a performant manner.

tags:
    - programming
    - php
---

Recently I had a task at work, in which I had to send a decent amount of HTTP requests within a script. Naturally, one
of the first ideas was to use a [batching mechanism](https://en.wikipedia.org/wiki/Batch_processing) to send multiple
requests in parallel. However, there was no resource with some real world (whatever that means) examples using PHP, so I
did what I usually do in these cases: Figuring it out myself and blog about if afterwards.

*Some context: I am using PHP 8.4.5 on my MacBook Pro 16" with an Apple M2 Pro to run the scripts in this blog post. I
ran the scripts multiple times and always publish the fastest run.*

## Sequential processing

The easiest way to send multiple requests using a PHP script is to loop over all URLs and use the following steps:

- Call [`curl_init`](https://www.php.net/manual/en/function.curl-init.php) to retrieve a handle
- Set some options on that handle using [`curl_setopt`](https://www.php.net/manual/en/function.curl-setopt.php)
- Send the request with [`curl_exec`](https://www.php.net/manual/en/function.curl-exec.php)

So the first naive implementation would probably result in something like this:

```php
<?php

$urls = [
    'https://example.com/',
    'https://example.com/1',
    'https://example.com/2',
    'https://example.com/3',
    'https://example.com/4',
    'https://example.com/5',
    'https://example.com/6',
    'https://example.com/7',
    'https://example.com/8',
    'https://example.com/9',
];

$total_start = microtime(true);

foreach ($urls as $url) {
    $request_start = microtime(true);
    $handle = curl_init();
    curl_setopt($handle, CURLOPT_URL, $url);
    curl_setopt($handle, CURLOPT_RETURNTRANSFER, true);
    $response = curl_exec($handle);
    $response_code = curl_getinfo($handle, CURLINFO_HTTP_CODE);
    $request_duration = number_format(microtime(true) - $request_start, 3);

    echo "Response code for request to {$url} is {$response_code} in {$request_duration}s\n";
}

$total_duration = number_format(microtime(true) - $total_start, 3);
echo "All requests took {$total_duration}s\n";
```

The output of this script looks something like this on my machine (I have used the `example.com` domain as
demonstrations like this is their purpose, but unfortunately everything except the root path returns a status code of
`404`):

```plaintext
$ php 01_sequential_processing.php
Response code for request to https://example.com/ is 200 in 0.414s
Response code for request to https://example.com/1 is 404 in 0.414s
Response code for request to https://example.com/2 is 404 in 0.447s
Response code for request to https://example.com/3 is 404 in 0.453s
Response code for request to https://example.com/4 is 404 in 0.496s
Response code for request to https://example.com/5 is 404 in 0.418s
Response code for request to https://example.com/6 is 404 in 0.433s
Response code for request to https://example.com/7 is 404 in 0.465s
Response code for request to https://example.com/8 is 404 in 0.470s
Response code for request to https://example.com/9 is 404 in 0.415s
All requests took 4.427s
```

So this script needs about 4.4 seconds to execute 10 requests. This is the baseline without any optimizations. The next
sections will try to improve this naive implementation.

## Reusing the curl handle

A very simple but yet quite effective optimization is to move the initialization of the curl handle before the loop.
This way we are initializing the curl handle only once, and use the same curl handle to send all of our requests. In
addition to the `curl_init` call all hard coded curl options can also be moved before the loop, which is in this case
the `CURLOPT_RETURNTRANSFER` option causing `curl_exec` to return the response instead of directly outputting it.

```php
<?php

$urls = [
    'https://example.com/',
    'https://example.com/1',
    'https://example.com/2',
    'https://example.com/3',
    'https://example.com/4',
    'https://example.com/5',
    'https://example.com/6',
    'https://example.com/7',
    'https://example.com/8',
    'https://example.com/9',
];

$total_start = microtime(true);

$handle = curl_init();
curl_setopt($handle, CURLOPT_RETURNTRANSFER, true);

foreach ($urls as $url) {
    $request_start = microtime(true);
    curl_setopt($handle, CURLOPT_URL, $url);
    $response = curl_exec($handle);
    $response_code = curl_getinfo($handle, CURLINFO_HTTP_CODE);
    $request_duration = number_format(microtime(true) - $request_start, 3);

    echo "Response code for request to {$url} is {$response_code} in {$request_duration}s\n";
}

$total_duration = number_format(microtime(true) - $total_start, 3);
echo "All requests took {$total_duration}s\n";
```

When running this version, **you might already realize that it runs much faster than the previous one**:

```plaintext
$ php 02_reuse_handles.php
Response code for request to https://example.com/ is 200 in 0.400s
Response code for request to https://example.com/1 is 404 in 0.130s
Response code for request to https://example.com/2 is 404 in 0.135s
Response code for request to https://example.com/3 is 404 in 0.130s
Response code for request to https://example.com/4 is 404 in 0.144s
Response code for request to https://example.com/5 is 404 in 0.212s
Response code for request to https://example.com/6 is 404 in 0.139s
Response code for request to https://example.com/7 is 404 in 0.130s
Response code for request to https://example.com/8 is 404 in 0.134s
Response code for request to https://example.com/9 is 404 in 0.133s
All requests took 1.688s
```

As it seems, initializing such a handle seems to be quite a heavy task. I know that executing something just once (or
even multiple times, as I did on these examples) is not a good benchmark, but a perfomance improvement of over 60% is
still substantial.

## Sending curl requests in parallel

Even with the latter improvement, all of the requests are running in sequence, i.e. one request has to finish before the
next one can start. It would be much faster, if all these requests would run in parallel. Luckily, PHP comes with some
methods prefixed with `curl_multi_`, which enable developers to do exactly that. However, I found all those methods a
bit confusing, which was probably the main motivation to write this blog post.

So if we want to parallelize all requests from the previous examples, the code would look like the following:

```php
<?php

$urls = [
    'https://example.com/',
    'https://example.com/1',
    'https://example.com/2',
    'https://example.com/3',
    'https://example.com/4',
    'https://example.com/5',
    'https://example.com/6',
    'https://example.com/7',
    'https://example.com/8',
    'https://example.com/9',
];

$total_start = microtime(true);

$multi_handle = curl_multi_init();
$handles = [];
for ($i = 0; $i < count($urls); ++$i) {
    $handles[$i] = curl_init();
    curl_setopt($handles[$i], CURLOPT_RETURNTRANSFER, true);
    curl_setopt($handles[$i], CURLOPT_URL, $urls[$i]);
    curl_multi_add_handle($multi_handle, $handles[$i]);
}

$running = null;
do {
    curl_multi_exec($multi_handle, $running);
    curl_multi_select($multi_handle);
} while ($running > 0);

for ($i = 0; $i < count($urls); $i++) {
    $response_code = curl_getinfo($handles[$i], CURLINFO_HTTP_CODE);

    echo "Response code for request to {$urls[$i]} is {$response_code}\n";
}

$total_duration = number_format(microtime(true) - $total_start, 3);
echo "All requests took {$total_duration}s\n";
```

The main difference to the previous examples are all these calls to the `curl_multi_` functions. The following parts are
the most interesting ones of this code:

- The [`curl_multi_init`](https://www.php.net/manual/en/function.curl-multi-init.php) method initializes a curl multi
handle, to which we can add multiple usual curl handles, and execute them in parallel later.
- In the `for` loop curl handles are created, set up, and then added to the curl multi handle using
[`curl_multi_add_handle`](https://www.php.net/manual/en/function.curl-multi-add-handle.php).
- The `do-while` loop is then responsible for actually executing those requests, and that part was the most confusing to
me. [`curl_multi_exec`](https://www.php.net/manual/en/function.curl-multi-exec.php) executes all those requests, but it
does not block, instead the second parameter is a reference that can be interpreted as a flag indicating if some
requests are still running. This flag is used as the loop condition, however, **without another call to
[`curl_multi_select`](https://www.php.net/manual/en/function.curl-multi-select.php) this would be a [busy
wait](https://en.wikipedia.org/wiki/Busy_waiting)**. `curl_multi_select` is actually the blocking operation, which
blocks until any of the multi handle's requests has made progress. To me it feels weird that this is happening for any
request, especially since the method does not tell which one has made progress. This is the reason for still putting
this in a loop, which means that after the loop all requests will have finished.
- Finally there is another `for` loop which will output some message. In here the usual curl handles (not the multi
handle!) must be used again. In this example this is `curl_getinfo` again to retrieve the status code for each handle.
Interestingly, if you would want to get the content of a request, you have to use
[`curl_multi_getcontent`](https://www.php.net/manual/en/function.curl-multi-getcontent.php) and also pass the curl
handle for a single request. That's probably because `curl_exec` usually returns the response body, something that is
not working with multi handles, since `curl_exec` is not called in the code.

Even though this works, it is kind of a weird API in my opinion. However, the following output shows that its usage pays
off in terms of performance:

```plaintext
$ php 03_multi_curl.php
Response code for request to https://example.com/ is 200
Response code for request to https://example.com/1 is 404
Response code for request to https://example.com/2 is 404
Response code for request to https://example.com/3 is 404
Response code for request to https://example.com/4 is 404
Response code for request to https://example.com/5 is 404
Response code for request to https://example.com/6 is 404
Response code for request to https://example.com/7 is 404
Response code for request to https://example.com/8 is 404
Response code for request to https://example.com/9 is 404
All requests took 0.499s
```

**This is even much faster than the previous example, taking a third of the time on my machine.** It approximately takes
the amount of time the slowest of all requests takes, because by then all other requests will already have finished.

## Batching parallelized curl requests

But unfortunately there is a limit to this: you cannot start an infinite amount of requests at the same time. Apparently
my machine can handle 10 requests in parallel, but starting with some number of requests it would probably make sense to
batch requests. The following example is going to assume that this number is 3, i.e. we will only send 3 requests at a
time. In addition, the curl handles should be reused like in our first step of improvement.

The following code shows how to implement such a batching mechanism with curl in PHP:

```php
<?php

$urls = [
    'https://example.com/',
    'https://example.com/1',
    'https://example.com/2',
    'https://example.com/3',
    'https://example.com/4',
    'https://example.com/5',
    'https://example.com/6',
    'https://example.com/7',
    'https://example.com/8',
    'https://example.com/9',
];

$total_start = microtime(true);

$multi_handle = curl_multi_init();
$batch_size = 3;

$handles = [];
for ($i = 0; $i < $batch_size; ++$i) {
    $handles[$i] = curl_init();
    curl_setopt($handles[$i], CURLOPT_RETURNTRANSFER, true);
}

$batch = [];
foreach ($urls as $index => $url) {
    $batch[] = $url;

    if (count($batch) % $batch_size !== 0 && $index < count($urls) - 1) {
    continue;
    }

    for ($i = 0; $i < count($batch); ++$i) {
    curl_multi_add_handle($multi_handle, $handles[$i]);
    curl_setopt($handles[$i], CURLOPT_URL, $batch[$i]);
    }

    $running = null;
    do {
    curl_multi_exec($multi_handle, $running);
    curl_multi_select($multi_handle);
    } while ($running > 0);

    for ($i = 0; $i < count($batch); ++$i) {
    $response_code = curl_getinfo($handles[$i], CURLINFO_HTTP_CODE);

    echo "Response code for request to {$batch[$i]} is {$response_code}\n";

    curl_multi_remove_handle($multi_handle, $handles[$i]);
    }

    $batch = [];
}

$total_duration = number_format(microtime(true) - $total_start, 3);
echo "All requests took {$total_duration}s\n";
```

The structure is a bit different than the previous examples, even though there is only one new method
(`curl_multi_remove_handle`) being used:

- The first `for` loop sets up three curl handles that will be used for all requests being sent.
- Then the first part of the `foreach` is responsible for batching (up until the `continue` statement, which prevents
the following code to be executed if the batch is not properly filled).
- If a batch is filled, another `for` loop will add the correct number of handles to the multi handle and set the URL
for that handle.
- Afterwards the same loop with `curl_multi_exec` and `curl_multi_select` as in the previous example is used to execute
the requests for the current batch.
- The following `for` loop outputs the information and removes the handle from the multi handle using
[`curl_multi_remove_handle`](https://www.php.net/manual/en/function.curl-multi-remove-handle.php).

It might be tempting to call `curl_multi_add_handle` just once for each handle in the first `for` loop where they are
being initialized and do not call `curl_multi_remove_handle` after each batch in order to further improve performance.
However, it turns out that this would have an undesired side effect: For some reason `curl_multi_exec` will then reuse
the information from the already received responses, i.e. there would only 3 requests being sent instead of the
necessary 10. Therefore these repeated calls to `curl_multi_add_handle` and `curl_multi_remove_handle` are absolutely
necessary.

The result is not as fast as the previous example, since this approach only makes sense if many more requests are being
sent, and not all of them can be sent at the same time. Still, here are the numbers:

```php
$ php 04_chunking_parallel_requests.php
Response code for request to https://example.com/ is 200
Response code for request to https://example.com/1 is 404
Response code for request to https://example.com/2 is 404
Response code for request to https://example.com/3 is 404
Response code for request to https://example.com/4 is 404
Response code for request to https://example.com/5 is 404
Response code for request to https://example.com/6 is 404
Response code for request to https://example.com/7 is 404
Response code for request to https://example.com/8 is 404
Response code for request to https://example.com/9 is 404
All requests took 0.801s
```

But the bottom line is that parallelizing the HTTP requests can result in a substantial performance improvement. I hope
that my findings can help others struggling with the same issues.
