---
layout:
    post: true
title: Batch fixing date of images based on filename in fish
excerpt: I was confronted with a large amount of images, all of which did not have the correct date attached to them. Fortunately I was able to fix them by relying on the filename.
tags:
    - cli
    - fish
    - regex
    - linux
---

I wanted to upload a bunch of photos to an online photo album, but unfortunately the photos did not have the correct
date attached to them. So when the photos were uploaded, they all ended up being displayed as taken in the wrong month.
Luckily, all these photos were using a filename that contained the date and time at which they were taken. So I decided
to write a small script using [fish](https://fishshell.com/), which I am going to explain in the rest of this blog post.

*Note that the same idea can be applied in other shells like [bash](https://www.gnu.org/software/bash/) as well,
although the syntax differs slightly.*

The first question to answer is how to change the date of the photo. In my case it was good enough to change the
modified date of the file, since the online photo album apparently relied on that date. This can be done using the `-d`
flag of the `touch` command. If you want to set the modified date of a photo to the 24th of October 2025 at 21:35:53 you
can use the following command:

```plaintext
touch -d '2025-10-24T21:35:52' photo.jpg
```

Even though many people use the `touch` command to create files, it can also be used to update the modified date of an
existing file. But of course that is very cumbersome and tedious if it needs to be done for hundreds or thousands of
files. So the idea is to write a loop that does that for all pictures automatically.

However, there is another step to take first. We need to find a way to infer the date from the filename, which we can
try with a hard coded filename first. I am going to use `echo` to pipe a filename to
[`rg`](https://github.com/BurntSushi/ripgrep) and will then use regular expressions to transform the filename to a date
string as required by the `touch` command.

```plaintext
echo '20250101_000010.jpg' | rg '(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})' --only-matching --replace '${1}-${2}-${3}T${4}:${5}:${6}'
```

Here comes a very quick description of the regex. It makes use of the `\d` character class, which matches any digit.
The number in square brackets behind that is how many digits it will match. So `\d{4}` matches **exactly four digits**
and `\d{2}` matches **exactly two digits**. By putting these between parenthesis they will end up in a so-called
capturing group, which means that they can addressed indepentently.

The `--only-matching` part will make sure that `rg` outputs only the part that matches the regex, and not the characters
before or after (which it usually does, but it will highlight the actual match).

Then the `--replace` options is used to replace the match with something else, and it can make use of the capturing
groups for that. `${1}` contains the value of the first capturing group (which is the year in my example), `${2}`
contains the value of the second capturing group (which is the month in my example), etc. So by using
`--replace ${1}-${2}-${3}T${4}:${5}:${6}` `rg` will return a formatted date string based on the value passed to it (the
filename in this case).

*Note that you usually can also use `$1` here, but it does not work properly with the `T` in the middle, therefore the
curly braces are needed.*

Now that can be combined with a `for` loop in fish [like in my other blog post about executing multiple commands in
fish](/2020/05/13/execute-commands-for-multiple-files-in-fish.html). I used the glob `*.{jpg,mp4}` to find all pictures
and videos in the current working directory and then use the filename as a variable. The command from above will be used
to get the argument for the `-d` parameter using [fish's command
substitution](https://fishshell.com/docs/current/language.html#command-substitution) with the `$()` syntax. That means
that the command within the parenthesis will be executed and its output will be used in its place. So the final script
looks like this:

```plaintext
for file in *.{jpg,mp4}
    touch -d $(echo $file | rg '(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})' --only-matching --replace '${1}-${2}-${3}T${4}:${5}:${6}') $file
end
```

The previous `touch` command is executed for every `jpg` and `mp4` file in that folder, but the `-d` parameter uses
command substitution to get the date based on the filename using the previous `rg` command. Also, it uses the `$file`
variable for the second argument of the `touch` command representing the filename and instead of the hardcoded `echo`
string.

This way all photos ended up with the correct date without spending a lot of time setting them manually. If you want to
do this yourself, keep in mind that the regex needs some adjustments depending on your filename schema.
