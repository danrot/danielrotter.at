---
layout:
    post: true
title: Use git submodules and make for simple code sharing
excerpt: Simple code often does not require complicated packaging mechanisms. Reusing established tools like Git and make seem perfect for this use case.

tags:
    - html
    - css
    - javascript
    - git
    - pandoc
    - graphviz
    - make
---

Based on the [presentation template explained in an earlier blog
post](/2020/03/28/creating-highly-customizable-html-presentation-with-markdown-and-pandoc.html) I have built quite a
few presentations, so it was time to reevaluate that approach. Two problems caused issues multiple times, so naturally,
I wanted to fix them:

- **Whenever I adjusted the styling of my presentations I had to repeat that for all of my presentations** since I
only built a template that was copied for every presentation
- **Including the building of graphviz within pandoc lead to high build times**, which is exactly the problem I wanted
to avoid with the move away from [`mdx-deck`](https://github.com/jxnblk/mdx-deck)

## Extract and share common code into a separate Git repository

The solution to the first problem is kind of obvious, the HTML, CSS, and JS code responsible for the look and behavior
of the presentation needs to be extracted. The question is **where this code should be located** and **how it is
included in all of my presentations**.

Since we are talking about HTML, CSS, and JS code, the first thing that comes to mind is NPM. **But the code is really
minimal and publishing an NPM package comes with an overhead.** Additionally, I am not a big NPM fan, since the way it
is handling packages and the tool itself always felt a bit clumsy to me (how often have you deleted the `node_modules`
folder, reinstalled all package, and suddenly everything was working?).

Therefore I was looking for another solution that allows me to reuse code without using NPM. I like other package
managers much better, but using them might feel weird, since they are targeted at other programming languages, and I am
not really aware of a language-independent package manager. So I decided to just use
[**Git submodules**](https://git-scm.com/book/en/v2/Git-Tools-Submodules) for these files.
So I created a [separate repository for the shared presentation code](https://github.com/danrot/markdown-presentation)
including the CSS, JS, and a small markdown file that allows me to test the package independently. There is also a
`Makefile` included that knows how to build the presentation since I also don't want to copy that information into all
my presentations (otherwise there might some adapting be necessary every time the package is restructured).

The `Makefile` can then be referenced by the `Makefile` of the repository containing my presentation (will show that in
a second). To make that possible **the `Makefile` of the shared presentation code will contain a variable referencing
the path to itself**:

```makefile
MARKDOWN_PRESENTATION_DIR=.

all:
        pandoc\
            slides.md\
            -o slides.html\
            -s\
            --self-contained\
            --section-divs\
            -c $(MARKDOWN_PRESENTATION_DIR)/slides.css\
            -A $(MARKDOWN_PRESENTATION_DIR)/slides_before_body.html
```

The command itself has already been explained in more detail in my [previous blog
post](/2020/03/28/creating-highly-customizable-html-presentation-with-markdown-and-pandoc.html), the important
difference now is that the files `slides.css` and `slides_before_body.html` are not referenced directly anymore, but
the `MARKDOWN_PRESENTATION_DIR` is used. This is necessary because this `Makefile` will be called by another
`Makefile` from a different path. **To correctly reference these files the other `Makefile` has to override the
`MARKDOWN_PRESENTATION_DIR` variable**, which it can do when referencing it using the `-f` flag.

```makefile
all: presentation

presentation:
        $(MAKE) MARKDOWN_PRESENTATION_DIR=markdown-presentation\
            -f markdown-presentation/Makefile
```

This `Makefile` makes use of the `MAKE` variable instead of directly using the `make` command and overrides the
`MARKDOWN_PRESENTATION_DIR` to tell the shared repository how the path has to be adapted to find the `slides.css` and
`slides_before_body.html` from the path where `make` has been called. It assumes that the shared code repository is
located at `markdown-presentation`, which can be done by adding it as a submodule:

```bash
git submodule add\
    git@github.com:danrot/markdown-presentation.git\
    markdown-presentation
```

This way everything shared by all presentations is in a separate repository, and there is no need to adjust all my
presentations just because I have fixed a bug in the `slides.css` file. If I have to do something like that, I can fix
that in my [`markdown-presentation`](https://github.com/danrot/markdown-presentation) repository, and update all of my
presentations using a single command in each one of them:

```bash
git submodule update --remote
```

## Decrease build time by using the file system as a cache

The second issue was about the long build times because I have built the `codeblock-filter.lua` (as explained in my
[previous blog post](/2020/03/28/creating-highly-customizable-html-presentation-with-markdown-and-pandoc.html)), which
passed all `graphviz` code blocks to the `graphviz` command and generated diagrams based on this code. If a
presentation contains many different diagrams rendered this way, this could take quite some time. Also, this happened
every time `make` was executed, because **the result of the `graphviz` code was not cached**.

So the idea was to rely on the dependency capabilities of `make`, but this was not as straightforward as imagined. The
following `Makefile` is the result used in all my presentations (so that part is not shared at the moment, maybe I'll
realize in the future that this was a bad idea):

```makefile
all: presentation

presentation: ${addsuffix .svg, ${wildcard diagrams/*.dot}}
        $(MAKE) MARKDOWN_PRESENTATION_DIR=markdown-presentation\
            -f markdown-presentation/Makefile

diagrams/%.dot.svg: diagrams/%.dot
        dot -T svg -O $^
```

Let's go through this file step by step:

In general, each defined target in `make` can define targets (or files) this target depends on. The easiest example of
that is the `all` target above, which says it depends on the `presentation` target. So when `make all` is executed, it
will also execute the `presentation` target.

Before explaining the second line, I should probably elaborate a bit on the idea of how to integrate the `graphviz`
images. There is a [`diagrams`
folder](https://github.com/danrot/presentation-template/tree/8c493d8270f68b403ccead4547a681b9190a30b8/diagrams) in each
of my presentations, which will contain files with a `.dot` ending. These files contain the `graphviz` instructions.
**`make` should create a file with a `.dot.svg` ending for each of the `.dot` files in the same folder**, which in turn
can be included in the presentation. So the presentation will include some markdown like this:

```markdown
![test](diagram/test.dot.svg)
```

So first of all the `presentation` target needs to define all files it depends on, which will be simplified to all
files containing the `.dot.svg` ending in the `diagrams` folder. Referencing these files is not that easy, since these
files will be ignored by git because they can always be regenerated. For that reason, we have to use some of the [file
name functions from `make`](https://www.gnu.org/software/make/manual/html_node/File-Name-Functions.html). First, the
`wildcard` function is used to generate a list of all files ending with `.dot` with the command
`${wildcard diagrams/*.dot}`. But this is not the file the presentation is actually depending on, instead, it should
depend on the generated SVG. Using the `addsuffix` function a suffix can be added to all entries being passed to it,
which will be the wildcard expression from before. **So by using `${addsuffix .svg, ${wildcard diagrams/*.dot}}` we get
a list of files ending in `.dot.svg` for every `.dot` file in the `diagrams` folder.** This way `make` knows which
files the presentation is dependant on.

But as mentioned before, these files do not exist yet, but they are recognized by the next target. It is using
something similar as a wildcard, the `%` sign representing a
[pattern](https://www.gnu.org/software/make/manual/html_node/Pattern-Intro.html#Pattern-Intro). `diagrams/%.dot.svg`
will therefore match everything listed as a dependency for the `presentation` target. The string matching the `%` sign
is called the "stem" and will be equal for both sides. So the `presentation` dependency list e.g. contains
`diagrams/test.dot.svg`, then the "stem" is recognized as `test`. The `%` sign in the dependency list will be also
matching `test` and therefore result in `diagrams/test.dot`. The latter will also be what the `%^` variable is holding.
So the `dot` command seen above will result in `dot -T svg -O diagrams/test.dot`, which will create the file
`diagrams/test.dot.svg` (not because that is the name of the target, but because the `dot` will append the suffix
corresponding to the type it is generating). Using this dependency tree `make` will know which commands to execute to
produce the final presentation.

**The best thing about this is that `make` knows which commands it can skip.** Imagine that the file
`diagrams.dot.svg`, which the presentation depends on, already exists. In that case, `make` will not execute the `dot`
command for that file, unless the last modified date of the source file `diagrams/test.dot` is later than the one from
the `diagrams/test.dot.svg` file. **This results in drastically reduced build times if the `.dot` files have already
been generated and have not been adapted since the last generation.**

## Conclusion

Both of the problems I have mentioned in the introduction have been solved. Stylistic or behavioural adjustments only
need to be done once and all my presentations can be updated easily afterwards by executing a single command. Build
time has also been reduced by only generating images if nothing has changed.

However, I think it is very important to mention that [this approach does not work for projects with a more complex
dependency structure](https://github.blog/open-source/git/working-with-submodules/). Git submodules will always install
the latest version of the repository, and it is not possible to define dependencies or conflicts between multiple
submodules. I still think that for a use case like the one above it is a pretty good fit, since it is pretty
straightforward. I hope that this kind of setup can also be of some help for your simplistic (at least in terms of
dependencies) projects!
