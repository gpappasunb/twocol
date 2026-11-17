--[[
twocol: a Pandoc/Quarto Lua filter that builds a two-column layout from a
single div. The columns are separated by a horizontal rule (--- or * * *):
the content above it goes to the left column, the content below it to the
right column.

    ::: {.twocol width="40%,60%" align="top,center"}
    Content left

    ---

    Content right
    :::

The result is Pandoc's standard `columns`/`column` structure, so it works
in every format that supports columns (Beamer, LaTeX, HTML, Reveal.js).

Attributes take one value for both columns, or two comma-separated values,
the first for the left column and the second for the right column.

All formats:

  width       Column width, e.g. "40%,60%". In a stacked layout (see
              below), the height of each panel instead.
  size        Alias of width.
  align       Vertical alignment: top, top-baseline, center, bottom.
  direction   vertical (default): the panels side by side, as columns.
              horizontal: the panels stacked, the first above the second.
  stack       "true" is the same as direction="horizontal".

A stacked layout in HTML and Reveal.js gives each panel the full width; in
Reveal.js, a `width`/`size` makes the block take the height left on the
slide and shares it between the panels. In every other format (Beamer,
LaTeX, ...), a stacked layout is just the first part followed by the
second, with no columns.

HTML and Reveal.js only (removed from every other output format, so they
never change Beamer or LaTeX output):

  fit           none, contain or cover. In a fitted column, each image that
                stands alone in its paragraph (or a figure) is sized to the
                space left in the column; in Reveal.js the block takes the
                height left on the slide. contain shows the whole image,
                cover fills the space and crops the image.
  left-bg, right-bg         Column background colour.
  left-fg, right-fg         Column text colour.
  left-border, right-border Column border colour, or "none".
  border        Border colour (or "none") for both columns.

An image marked `.r-stretch` inside a column is a shortcut for
fit="contain" on that column (unless `fit` sets that column explicitly).
Images with an explicit width or height are never resized.

Every other attribute and class is kept on the outer `columns` div.

Defaults: in HTML output each column is 50% wide and top-aligned. Other
formats get no defaults, so Pandoc's own column defaults apply.

Author: Georgios Pappas Jr
Institution: University of Brasilia (UnB) - Brazil
Version: 1.2.0
--]]

-- The class of the div that triggers the filter
local DIVNAME = "twocol"

local FIT_MODES = { none = true, contain = true, cover = true }
local FIT_ALIASES = { ["true"] = "contain", yes = "contain", ["false"] = "none", no = "none", [""] = "none" }

-- Attributes consumed by the filter (never forwarded to the outer div)
local COLUMN_ATTRS = { "width", "align", "fit" }
local COLOUR_PROPS = { "bg", "fg", "border" }

-- CSS used in HTML output. Kept here, not in a separate file, so that the
-- filter works the same with plain Pandoc and with Quarto.
local CSS = [[
/* twocol: colours (left-bg, right-fg, border, ...). :where() gives these
   rules no specificity, so a theme's own column styles always win. */
:where(.twocol > .column) {
  background: var(--col-bg, transparent);
  color: var(--col-fg, inherit);
  border: var(--col-border, none);
}
:where(.twocol > .column.twocol-boxed) {
  padding: 0.5em;
  border-radius: 6px;
  box-sizing: border-box;
}
/* twocol: fitted images, any HTML page: fill the column width */
.twocol > .column.twocol-fit .twocol-fit-img {
  width: 100%;
  height: auto;
}
/* twocol: stacked panels (direction="horizontal" or stack="true") */
.columns.twocol.twocol-stack {
  display: flex;
  flex-direction: column;
}
.columns.twocol.twocol-stack > .column {
  width: 100%;
  min-height: 0;
}
/* twocol, Reveal.js: a block with fitted images, or with sized stacked
   panels (twocol-fill), takes the height left on the slide */
.reveal .slides section:has(> .twocol.twocol-fill) {
  display: flex !important;
  flex-direction: column;
}
.reveal .slides section[style*="display: none"]:has(> .twocol.twocol-fill) {
  display: none !important;
}
.reveal .slides section > .columns.twocol.twocol-fill {
  display: flex;
  flex: 1 1 0;
  min-height: 0;
  align-items: stretch;
}
/* A stacked panel without a size: its content height, or, when it has a
   fitted image, all the height left. A size is set inline as flex-basis. */
.reveal .slides .columns.twocol.twocol-stack > .column {
  flex: 0 0 auto;
}
.reveal .slides .columns.twocol.twocol-stack > .column.twocol-fit {
  flex: 1 1 0;
}
.reveal .slides .columns.twocol > .column.twocol-fit {
  display: flex;
  flex-direction: column;
  min-height: 0;
}
.reveal .slides .columns.twocol > .column.twocol-fit :has(.twocol-fit-img) {
  display: flex;
  flex-direction: column;
  flex: 1 1 0;
  min-height: 0;
  width: 100%;
  margin: 0;
}
.reveal .slides .columns.twocol > .column.twocol-fit .twocol-fit-img {
  flex: 1 1 0;
  min-height: 0;
  width: 100% !important;
  height: auto !important;
  max-width: none;
  max-height: none;
  object-fit: contain;
  margin: 0;
}
.reveal .slides .columns.twocol > .column.twocol-fit-cover .twocol-fit-img {
  object-fit: cover;
}
/* In a figure, keep the picture right above its caption */
.reveal .slides .columns.twocol > .column.twocol-fit figure .twocol-fit-img {
  object-position: center bottom;
}
]]

-- Set when a twocol div is converted for HTML output: the CSS is added once.
local css_needed = false

-------------------
-- Helper functions
-------------------

--- True when the output is an HTML format (including Reveal.js).
local function html_output()
  if type(quarto) == "table" and quarto.doc and quarto.doc.is_format then
    return quarto.doc.is_format("html")
  end
  for _, name in ipairs({ "html", "revealjs", "slidy", "slideous", "dzslides", "s5", "epub" }) do
    if FORMAT:match(name) then
      return true
    end
  end
  return false
end

local function warn(message)
  io.stderr:write("[twocol] WARNING: " .. message .. "\n")
end

--- Splits a string at commas and trims each part.
local function comma_separated_values(str)
  local acc = pandoc.List({})
  for substr in str:gmatch("([^,]*)") do
    acc[#acc + 1] = substr:gsub("^%s*", ""):gsub("%s*$", "")
  end
  return acc
end

--- "left,right" -> { left = "left", right = "right" }; one value is used
-- for both columns.
local function split_attributes(attr)
  local values = comma_separated_values(attr)
  local left = values[1]
  local right = #values > 1 and values[2] or left
  return { left = left, right = right }
end

--- Elements start_idx..end_idx of a list, as a new pandoc.List.
local function slice(list, start_idx, end_idx)
  local sliced = pandoc.List({})
  for i = start_idx, end_idx or #list do
    sliced:insert(list[i])
  end
  return sliced
end

--- Normalises a fit value; unknown values warn and become "none".
local function fit_mode(value)
  local mode = value:lower()
  mode = FIT_ALIASES[mode] or mode
  if not FIT_MODES[mode] then
    warn('unknown fit value "' .. value .. '", expected none, contain or cover; using none')
    return "none"
  end
  return mode
end

local TRUE_VALUES = { ["true"] = true, yes = true, ["1"] = true }
local FALSE_VALUES = { ["false"] = true, no = true, ["0"] = true, [""] = true }

--- Reads stack/direction (and removes them): true for a stacked layout.
local function stacked_layout(attrs)
  local stack, direction = attrs.stack, attrs.direction
  attrs.stack, attrs.direction = nil, nil

  local from_stack
  if stack then
    local value = stack:lower()
    if TRUE_VALUES[value] then
      from_stack = true
    elseif FALSE_VALUES[value] then
      from_stack = false
    else
      warn('unknown stack value "' .. stack .. '", expected true or false; using false')
      from_stack = false
    end
  end

  local from_direction
  if direction then
    local value = direction:lower()
    if value == "horizontal" then
      from_direction = true
    elseif value == "vertical" then
      from_direction = false
    else
      warn('unknown direction "' .. direction .. '", expected vertical or horizontal; using vertical')
      from_direction = false
    end
  end

  if from_stack ~= nil and from_direction ~= nil and from_stack ~= from_direction then
    warn('stack="' .. stack .. '" and direction="' .. direction .. '" disagree; using direction')
    return from_direction
  end
  if from_direction ~= nil then
    return from_direction
  end
  return from_stack == true
end

--- Collects the per-column options from the div attributes and removes
-- them, so that only the other attributes stay in `attrs`.
local function process_attributes(attrs)
  local sides = { left = {}, right = {} }

  -- size is an alias of width
  if attrs.size then
    if attrs.width then
      warn('both width="' .. attrs.width .. '" and size="' .. attrs.size .. '" given; using width')
    else
      attrs.width = attrs.size
    end
    attrs.size = nil
  end

  for _, name in ipairs(COLUMN_ATTRS) do
    if attrs[name] then
      local split = split_attributes(attrs[name])
      sides.left[name] = split.left
      sides.right[name] = split.right
      attrs[name] = nil
    end
  end

  for _, side in ipairs({ "left", "right" }) do
    for _, prop in ipairs(COLOUR_PROPS) do
      local key = side .. "-" .. prop
      if attrs[key] then
        sides[side][prop] = attrs[key]
        attrs[key] = nil
      end
    end
  end

  local border = attrs.border
  attrs.border = nil

  return sides, border, attrs
end

--- Value of a `--col-border` custom property: "none" or a colour.
local function border_style(value)
  if value == "none" then
    return "--col-border: none"
  end
  return "--col-border: 1px solid " .. value
end

--- True when the image has an explicit size, which fitting must respect.
local function has_size(img)
  return img.attributes.width ~= nil or img.attributes.height ~= nil
end

--- True when some image in the blocks has the class r-stretch.
local function has_stretch_image(blocks)
  local found = false
  pandoc.Blocks(blocks):walk({
    Image = function(img)
      if img.classes:includes("r-stretch") then
        found = true
      end
    end,
  })
  return found
end

--- Marks an image as fitted: drops r-stretch (Reveal.js would otherwise
-- try to stretch it to the whole slide) and adds twocol-fit-img.
local function mark_fit_image(img)
  if has_size(img) then
    return img
  end
  img.classes = img.classes:filter(function(c)
    return c ~= "r-stretch"
  end)
  if not img.classes:includes("twocol-fit-img") then
    img.classes:insert("twocol-fit-img")
  end
  return img
end

--- The image of a paragraph that holds only one image (and spaces).
local function lone_image(block)
  if block.t ~= "Para" and block.t ~= "Plain" then
    return nil
  end
  local image
  for _, inline in ipairs(block.content) do
    if inline.t == "Image" then
      if image then
        return nil
      end
      image = inline
    elseif inline.t ~= "Space" and inline.t ~= "SoftBreak" then
      return nil
    end
  end
  return image
end

--- Marks the images of a fitted column. A lone image is taken out of its
-- paragraph, so that it is a direct child of the column; a figure keeps
-- its structure (image and caption).
local function mark_fit_blocks(blocks)
  local result = pandoc.List({})
  for _, block in ipairs(blocks) do
    local image = lone_image(block)
    if image then
      result:insert(pandoc.Plain({ mark_fit_image(image) }))
    elseif block.t == "Figure" then
      result:insert(block:walk({ Image = mark_fit_image }))
    else
      result:insert(block)
    end
  end
  return result
end

--------------------------
-- Column builders
--------------------------

--- HTML: width and colours go into one inline style (Pandoc writes a
-- `width` attribute as a style too, and keeps only one of the two when
-- both are present).
local function html_column(content, class_name, side, stacked)
  local classes = pandoc.List({ "column", class_name })

  local fit = side.fit and fit_mode(side.fit) or "none"
  if fit == "none" and not side.fit and has_stretch_image(content) then
    fit = "contain"
  end
  if fit ~= "none" then
    classes:insert("twocol-fit")
    classes:insert("twocol-fit-" .. fit)
    content = mark_fit_blocks(content)
  end

  -- Side by side, width is the column width. Stacked, every panel is full
  -- width and width is the panel height (a flex-basis, which can shrink to
  -- leave room for the gap between the panels).
  local style
  if stacked then
    style = { "width:100%" }
    if side.width then
      style[#style + 1] = "flex: 0 1 " .. side.width
    end
  else
    style = { "width:" .. (side.width or "50%") }
  end
  if side.bg then
    style[#style + 1] = "--col-bg: " .. side.bg
  end
  if side.fg then
    style[#style + 1] = "--col-fg: " .. side.fg
  end
  if side.border then
    style[#style + 1] = border_style(side.border)
  end
  if side.bg or side.border then
    classes:insert("twocol-boxed")
  end

  local kv = { style = table.concat(style, "; ") .. ";", align = side.align or "top" }
  return pandoc.Div(content, pandoc.Attr("", classes, kv))
end

--- Other formats (Beamer, LaTeX, ...): only width and align, exactly what
-- Pandoc's own column syntax takes. No defaults, no styling.
local function plain_column(content, class_name, side)
  local kv = {}
  if side.width then
    kv.width = side.width
  end
  if side.align then
    kv.align = side.align
  end
  return pandoc.Div(content, pandoc.Attr("", { "column", class_name }, kv))
end

--------------------------
-- Filter functions
--------------------------

function Div(div)
  if not div.classes:includes(DIVNAME) then
    return nil
  end

  -- The horizontal rule separates the columns
  local ruler_pos
  for i, el in ipairs(div.content) do
    if el.t == "HorizontalRule" then
      ruler_pos = i
      break
    end
  end
  if not ruler_pos then
    return nil
  end

  local html = html_output()
  local stacked = stacked_layout(div.attributes)
  local sides, border, attrs = process_attributes(div.attributes)
  local left_content = slice(div.content, 1, ruler_pos - 1)
  local right_content = slice(div.content, ruler_pos + 1)

  -- Stacked, outside HTML: the first part, then the second, no columns
  if stacked and not html then
    local blocks = left_content .. right_content
    if div.identifier ~= "" then
      return pandoc.Div(blocks, pandoc.Attr(div.identifier))
    end
    return blocks
  end

  -- The outer div keeps the user's classes (twocol, onlytextwidth, ...)
  local outer_classes = pandoc.List({ "columns" })
  outer_classes:extend(div.classes)

  local columns
  if html then
    css_needed = true
    columns = pandoc.List({
      html_column(left_content, "left-content", sides.left, stacked),
      html_column(right_content, "right-content", sides.right, stacked),
    })
    if stacked then
      outer_classes:insert("twocol-stack")
    end
    -- In Reveal.js, the block takes the height left on the slide when an
    -- image is fitted, or when stacked panels have a size
    local fitted = columns[1].classes:includes("twocol-fit") or columns[2].classes:includes("twocol-fit")
    if fitted or (stacked and (sides.left.width or sides.right.width)) then
      outer_classes:insert("twocol-fill")
    end
    -- A whole-block border is inherited by both columns, unless a column
    -- sets its own left-border/right-border
    if border then
      local style = attrs.style or ""
      if style ~= "" and not style:match(";%s*$") then
        style = style .. ";"
      end
      attrs.style = (style ~= "" and style .. " " or "") .. border_style(border) .. ";"
    end
  else
    columns = pandoc.List({
      plain_column(left_content, "left-content", sides.left),
      plain_column(right_content, "right-content", sides.right),
    })
  end

  return pandoc.Div(columns, pandoc.Attr(div.identifier, outer_classes, attrs))
end

--- Adds the CSS once, for HTML output that has at least one twocol div.
function Pandoc(doc)
  if not css_needed then
    return nil
  end
  local style = "<style>\n" .. CSS .. "</style>"

  if type(quarto) == "table" and quarto.doc and quarto.doc.include_text then
    quarto.doc.include_text("in-header", style)
    return nil
  end

  local block = pandoc.MetaBlocks({ pandoc.RawBlock("html", style) })
  local includes = doc.meta["header-includes"]
  if includes == nil then
    doc.meta["header-includes"] = pandoc.MetaList({ block })
  elseif pandoc.utils.type(includes) == "List" then
    includes:insert(block)
    doc.meta["header-includes"] = includes
  else
    doc.meta["header-includes"] = pandoc.MetaList({ includes, block })
  end
  return doc
end
