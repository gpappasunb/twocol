# 🌒 Quarto/Pandoc filter to create columns

## Introduction

A [Pandoc](https://www.pandoc.org) [Pandoc Lua
filter](https://pandoc.org/lua-filters.html) that provides an easier
notation to create columns in documents, especially for Beamer or
reveal.js presentations. It works in every format that supports Pandoc
columns.

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

Formatting can be changed with attributes. Each one takes either a single
value, used for both columns, or two comma-separated values, for the left and
right columns:

``` markdown
::: {.twocol width="40%,60%" align="top,center"}

Left contents...

* * *

Right contents...

:::
```

> [!NOTE]
>
> Also, notice the alternative way to represent the horizontal rule (at
> least three `-` or `*` with optional spaces within).

### Attributes for every format

| Attribute | Description |
|:----------|:------------|
| `width`   | Column width, e.g. `"30%,70%"`. In a stacked layout, the panel heights instead |
| `size`    | Alias of `width` |
| `align`   | Vertical alignment: `top`, `top-baseline`, `center` or `bottom` |
| `direction` | `vertical` (default): panels side by side. `horizontal`: panels stacked |
| `stack`   | `true` is the same as `direction="horizontal"` |

Other attributes and classes are kept on the outer `columns` div, so
Pandoc's own column options still work, for example `.onlytextwidth` or
`totalwidth="8cm"` in Beamer.

Defaults: in HTML each column is 50% wide and top-aligned. Other formats get
no defaults, so Pandoc's own defaults apply (in Beamer, two columns of
`0.48\linewidth`).

### Stacked panels

With `direction="horizontal"`, or `stack="true"`, the two parts are stacked:
the content above the rule goes on top, the content below it underneath.

``` markdown
::: {.twocol direction="horizontal" size="30%,70%"}
Top panel

---

Bottom panel
:::
```

- In HTML and Reveal.js each panel takes the full width. Without a size,
  each panel takes the height of its content.
- `width` (or its alias `size`) sets the panel heights. In Reveal.js, the
  block then takes the height left on the slide and shares it between the
  panels. In other HTML output, the heights cannot be set, because the page
  has no fixed height.
- A fitted image (`fit`, below) in a panel without a size takes all the
  height left on the slide.
- A panel with a size does not grow with its content: text taller than the
  panel runs outside it. Keep sized panels short, or leave out the size.
- In every other format (Beamer, LaTeX, Word, ...) a stacked block is just
  the first part followed by the second, with no columns.

If `stack` and `direction` disagree, `direction` is used; if both `width` and
`size` are given, `width` is used. The filter prints a warning in both cases.

### Attributes for HTML and Reveal.js only

These are removed from every other format, so they never change Beamer or
LaTeX output.

| Attribute | Description |
|:----------|:------------|
| `fit`     | `none`, `contain` or `cover`: fit the images of a column to its space (see below) |
| `left-bg`, `right-bg` | Column background colour |
| `left-fg`, `right-fg` | Column text colour |
| `left-border`, `right-border` | Column border colour, or `none` |
| `border`  | Border colour, or `none`, for both columns |

``` markdown
::: {.twocol left-bg="#fdf2e9" left-fg="#7a3b0a" right-border="#145a32"}
A coloured column

---

A column with a border
:::
```

### Fitting images to a column

With `fit`, each image that stands alone in its paragraph, and each figure
(an image with a caption), is sized to the space left in its column. The
image keeps its proportions.

- In Reveal.js, the two-column block takes the height left on the slide,
  below the title and any text above it. A fitted image takes the height
  left in its column, below any text above it, and never runs off the
  slide.
- In other HTML output, a fitted image fills the column width.

``` markdown
::: {.twocol width="40%,60%" fit="none,contain"}
- Some text
- More text

---

![A caption](figure.png)
:::
```

The values are:

| Value | Effect |
|:------|:-------|
| `none` | No fitting (default) |
| `contain` | The whole image is visible, as large as the space allows |
| `cover` | The image fills the space and is cropped |

Notes:

- An image marked `.r-stretch` inside a column, as in Reveal.js, is a
  shortcut for `fit="contain"` on that column.
- Images with an explicit `width` or `height` are not resized.
- Several fitted images in one column share its height.

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

Install the latest release in the folder of your document or project:

``` bash
quarto add gpappasunb/twocol
```

To install a specific version, add its tag. Every version is listed on the
[releases page](https://github.com/gpappasunb/twocol/releases), with its zip
file:

``` bash
quarto add gpappasunb/twocol@v1.2.0
```

Add the filter to the document metadata:

``` markdown
---
filters:
  - twocol
---
```

## Releasing a new version

1. Change `twocol.lua` and copy it to `_extensions/twocol/twocol.lua`: the
   two files must be identical.
2. Set the new `version` in `_extensions/twocol/_extension.yaml`, and commit.
3. Tag the commit with the same version and push the tag:

   ``` bash
   git tag -a v1.3.0 -m "twocol 1.3.0"
   git push origin main v1.3.0
   ```

Pushing the tag runs `.github/workflows/release.yml`. It checks that the tag
matches the version and that the two filter files are identical, then
publishes a GitHub release with the extension zip.

# Author

    Prof. Georgios Pappas Jr
    Computational Genomics group
    University of Brasilia (UnB) - Brazil
