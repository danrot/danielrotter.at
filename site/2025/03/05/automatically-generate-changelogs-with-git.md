---
layout:
    post: true
title: Automatically generate changelogs with git
excerpt: Generating changelogs is a rather tedious task for developers. But with a bit of discipline it becomes a one-line script.

tags:
  - git
---

One of the rather tedious tasks of a developer is to generate changelogs. I cannot imagine that anybody enjoys going
through the project history and try to reverse engineer what has happened since the last release. But the good news is
that with a bit of discipline it is quite straightforward to generate those changelogs from your version control
history. The examples in this blog post will use [git](https://git-scm.com/), but I guess every (mature) version control
system will have similar commands as the ones being used here.

The explained process only works if some rules are followed while using git:

- All code in your `main` or `master` branch is contributed by merging [GitHub pull
requests](https://docs.github.com/en/pull-requests)
- The commits of pull requests are squashed during the commit
- The title of your pull requests are written well enough to be used as changelog entries

*You might make the general idea also work in other circumstances, as long as there is at least some consistency, but
this post assumes these pre-conditions.*

This process basically enables developers to use the version control history as a changelog. Squashing is not absolutely
necessary, but I have yet to work in a team where the commit messages without squashing are written well enough for this
to work, although it is theorethically possible. I guess it is just unlikely that people also review the commit messages
in a pull request.

Anyway, when following these rules the output of the [`git log` command](https://git-scm.com/docs/git-log) already looks
quite promising (I pasted only the first part of the output):

```plaintext
$ git log
commit f582a707e7b28aa444a737146c0626810242fd13 (HEAD -> master, danrot/master, danrot/HEAD)
Author: Daniel Rotter <daniel.rotter@gmail.com>
Date:   Wed Feb 5 22:16:45 2025 +0100

    Write blog posts about indirections (#46)

commit bd7d3bbf43412926ccaeafbe63219366e6b21123
Author: Daniel Rotter <daniel.rotter@gmail.com>
Date:   Sun Nov 24 15:02:48 2024 +0100

    Fix images when CSS is not loaded (#45)

commit 1e5932c0d83099fba9ed467aab5ed3f3e406394e
Author: Daniel Rotter <daniel.rotter@gmail.com>
Date:   Sun Nov 24 11:20:57 2024 +0100

    Fix sitemap in robots.txt (#44)

commit 449ae6c390d083879b5b139954e3eda04ce36b2c
Author: Daniel Rotter <daniel.rotter@gmail.com>
Date:   Sat Nov 23 19:37:32 2024 +0100

    Add 404 page (#43)
```

The first thing that needs fixing is returning the correct list of commits, since the `git log` command will just return
all commits within the current repository. In order to do that, we can pass a so-called [revision
range](https://git-scm.com/docs/gitrevisions):

```plaintext
$ git log 1e5932c0d83099fba9ed467aab5ed3f3e406394e..HEAD
commit f582a707e7b28aa444a737146c0626810242fd13 (HEAD -> master, danrot/master, danrot/HEAD)
Author: Daniel Rotter <daniel.rotter@gmail.com>
Date:   Wed Feb 5 22:16:45 2025 +0100

    Write blog posts about indirections (#46)

commit bd7d3bbf43412926ccaeafbe63219366e6b21123
Author: Daniel Rotter <daniel.rotter@gmail.com>
Date:   Sun Nov 24 15:02:48 2024 +0100

    Fix images when CSS is not loaded (#45)
```

The `1e5932c0d83099fba9ed467aab5ed3f3e406394e..HEAD` notation includes all commits that can be reached from `HEAD` (i.e.
the commit you are currently on) but not from `1e5932c0d83099fba9ed467aab5ed3f3e406394e`, for which reason this time
only two commits are shown. Keep in mind that this notation can also be used with tags, so if you have a tag for your
last release you could also use something like `1.0..HEAD`.

For changelogs we probably do not need most of the information included in the default output of the `git log` command.
Luckily, there is a `--format` option that allows to configure the output. In this example we only want to use the
subject line of the squashed merge commit, which will be the GitHub pull request title. For that we can use the `%s`
placeholder, which stands for the subject line of a commit message.

So, based on the example above, the following command can be used to get only the subject lines of all commits for a
given revision range:

```plaintext
$ git log 1e5932c0d83099fba9ed467aab5ed3f3e406394e..HEAD --format=%s
Write blog posts about indirections (#46)
Fix images when CSS is not loaded (#45)
```

Depending on the structure of the project, this might already be good enough. Just replace the commit hash with another
commit hash or a tag each time the changelog is generated.

However, consider that this really includes all commits. Especially if you are using a branching model like [git
flow](https://nvie.com/posts/a-successful-git-branching-model/) the version history includes commits that might not be
that interesting for a changelog, e.g. commits merging in a `develop` branch. One way of fixing this is to use `grep`
(or a similar tool) to filter out unwanted messages. This depends a bit on the way you are doing things, but one way
this could be solved if you are using GitHub, is to filter for a pull request number at the end of the commit message
(e.g. the "(#46)" part in the last commit shown above). Manual commits usually do not have that part, which means we can
filter for that using an extended regular expression (which forces us to use the `-E` parameter of `grep`):

```plaintext
$ git log 1e5932c0d83099fba9ed467 aab5ed3f3e406394e..HEAD --format="%s" | grep -E '\(#[0-9]+\)$'
Write blog posts about indirections (#46)
Fix images when CSS is not loaded (#45)
```

The regular expression `\(#[0-9]+\)$` search for literal `(`(which must be escaped by a backslash),
followed by a `#`. Then `[0-9]+` searches for at least one digit. Then there should be another literal `)`(again escaped
by a backslash). Finally the regular expression ends with a `$`, which means that after the expression the line must be
finished, which causes to not match such a pattern at the beginning or in the middle of the commit messages's subject
line.

Last but not least, you can make use of `sed` to bring these commit messages in a format that you can directly copy e.g.
into a markdown file and do some slight adjustments. Personally I like to have the pull request number at the beginning.
All of this can be achived using the following command:

```plaintext
$ git log 1e5932c0d83099fba9ed467aab5ed3f3e406394e..HEAD --format="%s" | grep -E '\(#[0-9]+\)$' | sed -E 's/(.*)\((.*)\)/- \2 \1/'
- #46 Write blog posts about indirections 
- #45 Fix images when CSS is not loaded
```

The only part that changed compared to the previous example is the last part using `sed`. Again, `-E` lets us use
extended regular expressions. The passed argument is key to what we are trying to do here.
[`sed`](https://en.wikipedia.org/wiki/Sed) stands for stream editor, and the passed argument is a small script that
`sed` executes on its input. The `s` part of the command tells `sed` that it should do a search and replace operation,
whereby `/` is used a delimiter. So `s/foo/bar` would replace all occurences of `foo` with `bar`. It gets really
interesting when you use capturing groups (this is done by placing something into brackets), since you can make use of
the capturing group in the replace part of the operation. This is done by using a backslash followed by the number of
the capture group.

With that knowledge, let's break down the `sed` operation `s/(.*)\((.*)\)/- \2 \1/`:

- `s` starts the search and replace operation followed by a `/` as a delimiter
- `(.*)\((.*)\)` defines two capturing groups by using the unescaped brackets
    - `(.*)` looks for an arbitrary number (`*`) of any character (`.`) and stores it in a capturing group, which then
    contains most of the commit message's subject line
    - `\((.*)\)` looks for literal brackets in the texts (`\(` and `\)`), which also contains an arbitray text (`.*`),
    but only the text without the enclosing brackets will be stored in the second capturing group, which is the number
    referencing the pull request
- The `- \2 \1` enclosed in slashes replaces the search result with a literal `-` (which stands for a list in markdown)
followed by the second capturing group (the commit message) and the first capturing group (the pull request number).

As you can see, the command line allows you to write relatively complex one-liners. However, that is exactly what I like
about it. Using that command you can now generate your changelog from a (relatively structured) git commit history,
without the need for any additional tools (`grep` and `sed` are available on almost all unix-based systems, and when you
develop software you most likely have `git` installed as well).
