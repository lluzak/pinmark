# MCP tool reference

Pinmark exposes four MCP tools. All four take no positional args (other than
`mark_addressed`'s `id`) and return `text` content with a JSON body.

The endpoint is `http://localhost:PORT/dev/pinmark/annotations/mcp` (or
whatever path you mounted the engine at). Register it once with Claude Code:

```bash
claude mcp add pinmark --transport http \
  http://localhost:3000/dev/pinmark/annotations/mcp
```

## `list_pending_annotations`

Returns every annotation with `status="pending"`.

**Input:** none.

**Output:**

```json
{
  "count": 2,
  "annotations": [
    {
      "id": "8f2c1b6e-5d3a-4f9e-9b1c-1a2d3e4f5a6b",
      "node_id": "pm-3",
      "component": "Storefront::Cart::Item",
      "source": "app/components/storefront/cart/item.rb:14",
      "selector": "ul > li:nth-child(2) > button",
      "text_excerpt": "Remove",
      "comment": "this button should be red",
      "page_path": "/cart",
      "captured_at": "2026-05-04T11:59:58Z",
      "ancestry": [
        { "id": "pm-1", "component": "Storefront::Layout", "source": "app/components/storefront/layout.rb:8" },
        { "id": "pm-2", "component": "Storefront::Cart",   "source": "app/components/storefront/cart.rb:10" },
        { "id": "pm-3", "component": "Storefront::Cart::Item", "source": "app/components/storefront/cart/item.rb:14" }
      ]
    }
  ]
}
```

Each entry contains everything needed to find and edit the source:

- `source` — `file:line` of the component class. Open it directly.
- `selector` — relative DOM selector inside that component, useful when the
  component renders many similar elements.
- `text_excerpt` — visible text near the click, helpful for disambiguating.
- `ancestry` — the full chain of components that contained the click target,
  in render order. Use it when the leaf component is generic (a `Button`) and
  the real fix lives in the parent.
- `comment` — the user's note.

## `list_resolved_annotations`

Same shape as `list_pending_annotations`, but only entries with
`status="addressed"`. Each entry adds an `addressed_at` ISO-8601 timestamp.

Use it for:

- An end-of-session audit ("show me everything Claude Code touched").
- Undo support — flip `status` back to pending by hand if you want to redo.

## `mark_addressed`

Mark a single annotation as addressed.

**Input:**

```json
{ "id": "8f2c1b6e-5d3a-4f9e-9b1c-1a2d3e4f5a6b" }
```

**Output (success):**

```json
{ "ok": true, "id": "8f2c1b6e-...", "already_addressed": false }
```

**Output (unknown id):**

```json
{ "ok": false, "error": "No annotation with id=8f2c1b6e-..." }
```

Idempotent: calling it on an already-addressed id returns `ok: true,
already_addressed: true` without modifying the queue.

## `clear_addressed`

Drop every entry whose `status="addressed"` from the queue file.

**Input:** none.

**Output:**

```json
{ "ok": true, "removed": 12, "remaining": 3 }
```

`remaining` is the count of pending entries left after the purge.

## Suggested prompt patterns

Pinmark's tools are small on purpose, so the prompts you give Claude Code do
the heavy lifting. Some patterns that work well:

### Triage and fix in one pass

```
Use list_pending_annotations to read every open Pinmark note.
Group them by source file. For each file, apply the smallest possible fix
that addresses the comment, then call mark_addressed for that annotation.
Don't touch annotations whose comment isn't actionable yet — just leave them
pending.
```

### Cross-reference with a design system

```
Read the pending annotations. For any that mention color, spacing, or radius,
check the value against tokens in app/assets/tailwind/tokens.css and prefer
the token over a literal value. After each fix, mark_addressed.
```

### Audit + undo

```
Show me everything in list_resolved_annotations from the last hour.
For each one, check whether the source file actually changed at the linked
file:line in git. If it didn't, flag it — the annotation might have been
marked addressed prematurely.
```

### Cleanup

```
Run clear_addressed and tell me how many entries were removed.
```

## Programmatic access (no Claude Code)

The same JSON file is at `Rails.root.join("tmp/pinmark/queue.json")`. If you
want to script against it from a Rake task or a one-off `rails runner`:

```ruby
queue = Pinmark::Mcp::Queue.new
queue.pending          # array of pending entries
queue.addressed        # array of addressed entries
queue.mark_addressed("uuid-here")
queue.clear_addressed
```

The MCP layer is just a transport over those primitives.
