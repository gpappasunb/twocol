# 🌒 Quarto/Pandoc filter to create columns

## Introduction

A [Pandoc](https://www.pandoc.org) [Pandoc Lua
filter](https://pandoc.org/lua-filters.html) that provides an easier
notation to create columns in documents, especially for Beamer or
reveal.js presentations.

In [Quarto](https://www.quarto.org), the traditional way of creating columns in a markdown document is by using the special [fenced Div](https://pandoc.org/demo/example33/8.18-divs-and-spans.html) 
`.columns` :

``` markdown
:::: {.columns}

::: {.column width="40%"}
Left contents...
:::

::: {.column width="60%"}
Right contents...
:::

::::
```

This special [Quarto
syntax](https://quarto.org/docs/presentations/beamer.html#multiple-columns)
contains several customization options and is an effective way to
produce two-column sections inside documents (HTML, LaTeX) or slides
(Beamer).

However, it is somewhat cumbersome in the sense that the user should pay
extra attention to the number of consecutive colons (:) starting the div
blocks, in this case 4 for `.columns` and 3 for `.column`, but any consistently different number can be applied to both.

This filter simplifies this notation using a new div called
`twocol` and an [horizontal rule](https://riptutorial.com/markdown/example/2522/horizontal-rules) as the column separator. For instance, the code above turns into:

``` markdown
::: twocol

Left contents...

---

Right contents...

:::
```

Line 1  
The block name

Line 5  
The column delimiter is a horizontal rule

Formatting can be changed by passing the options `align` or `width`.
These should be given by a comma-separated string, with the left and right columns' values, respectively. In this case, the Div syntax is the following:

``` markdown
::: {.twocol width="40%,60%" align="l,r"}

Left contents...

* * *

Right contents...

:::
```

> [!NOTE]
>
> Also, notice the alternative way to represent the horizontal rule (at
> least three `-` or `*` with optional spaces within).

The parameters are:

| Parameter | Description                           |
|:----------|:--------------------------------------|
| `align`   | l=Left, r=Right, c=Center, d=Default  |
| `width`   | Column width percentage e.g “30%,70%” |

Other parameters included are forwarded to the *column* environment.

## Installation and execution

### Pandoc

Save the file `twocol` to `~/.pandoc/filters` (default directory for
pandoc filters) or any other directory. Run using one of the following
syntaxes:

``` bash
pandoc -s test.md -t html -L twocol.lua
pandoc -s test.md -t html --lua-filter=twocol.lua
pandoc -s test.md -t html -L ~/myfilters/twocol.lua
```

The last alternative refers to the filter installed in a custom
location.

### Quarto

    quarto install extension gpappasunb/twocol

Add the filter to the document metadata:

``` markdown
---
filters:
  - twocol.lua
---
```

# Author

    Prof. Georgios Pappas Jr
    Computational Genomics group
    University of Brasilia (UnB) - Brazil
