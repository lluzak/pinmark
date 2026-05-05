---
title: Home
layout: default
nav_order: 1
---

# Pinmark

Pin-style UI annotations that flow into Claude Code via MCP.

[Get started](#quickstart){: .btn .btn-primary .mr-2 }
[GitHub](https://github.com/lluzak/pinmark){: .btn }

> **Status:** early but usable. API may shift before 1.0 — pin a version in
> your Gemfile.

## Why Pinmark?

You spot something off in the browser — a misaligned card, a copy bug, the
wrong shade of orange. Normally you'd switch contexts: open the editor, hunt
for the component, type the prompt, paste a screenshot, describe the spot.

Pinmark closes that loop. Click the element on the page, type the comment,
keep working. Claude Code reads the queue over MCP and edits the right file —
because each annotation already carries its source `file:line`, the component
class, and the DOM selector.

## What you get

- Floating "Enable annotations" activator that survives Turbo navigation.
- Click-to-pin overlay with popover, side panel, on-page pin markers, marquee
  select, hover label, and a dual-highlight context for component vs. element.
- `<!-- pinmark:begin/end -->` HTML markers around every Phlex / ViewComponent
  / ERB partial render — automatically.
- File-backed atomic queue. Survives reloads, no database needed.
- Rack-mountable MCP HTTP server, in-process with your Rails app.
- Four MCP tools so Claude Code can list, resolve, and clear annotations.

## Quickstart

```bash
# 1. Add the gem (development group)
bundle add pinmark --group development

# 2. Wire it into your app
bin/rails generate pinmark:install

# 3. Boot the server, then point Claude Code at the in-process MCP endpoint
bin/rails server
claude mcp add pinmark --transport http \
  http://localhost:3000/dev/pinmark/annotations/mcp

# 4. Open any page, click "Enable annotations", drop a pin, type a comment.
#    Then ask Claude Code: "list pending annotations and fix them."
```

The generator handles routes and importmap pinning. The remaining manual
steps (Current attribute, Session concern, layout partials, optional Phlex
include) are listed in [Configuration]({{ '/configuration/' | relative_url }}).

## Documentation

| Doc | What's in it |
|-----|--------------|
| [Architecture]({{ '/architecture/' | relative_url }}) | End-to-end data flow, lifecycle of an annotation, file layout. |
| [Configuration]({{ '/configuration/' | relative_url }}) | Every config knob, the `Pinmark.active?` predicate, environment behavior. |
| [MCP tools]({{ '/mcp-tools/' | relative_url }}) | Full MCP tool reference: input schemas, sample output, prompt patterns. |
| [Troubleshooting]({{ '/troubleshooting/' | relative_url }}) | Common gotchas and how to debug them. |

## License

MIT — see [LICENSE.txt](https://github.com/lluzak/pinmark/blob/main/LICENSE.txt).
