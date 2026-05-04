# Contributing to Pinmark

Thanks for considering a contribution. Pinmark is intentionally small — every
addition should earn its place. The notes below cover the local loop and what
we look for in a pull request.

## Local development loop

```bash
git clone https://github.com/lluzak/pinmark.git
cd pinmark
bundle install
bundle exec rspec
```

The full suite runs in well under a second. CI runs the same suite on Ruby
3.2, 3.3, and 3.4.

## Trying changes against a host app

The fastest feedback loop is a `path:` reference from a real host app:

```ruby
# host_app/Gemfile
gem "pinmark", path: "../pinmark", group: :development
```

For the JS side, point the host's `package.json` at the gem checkout:

```json
"pinmark": "file:../pinmark"
```

Run `bundle install` and `yarn install` (or `npm install`) in the host. Edits
to the gem are reflected immediately.

## Tests

Specs live under `spec/`:

- `spec/lib/pinmark/**` — unit specs for the library code (Tracker, Wrapper,
  hooks, MCP queue, source locator).
- `spec/views/pinmark/**` — render specs for the activator and overlay
  partials.
- `spec/requests/pinmark/**` — request specs for the controller and the MCP
  HTTP endpoint.
- `spec/dummy/` — a minimal Rails app used as the test host.

Add a spec for any behavioral change. Coverage gaps we know about:

- ERB partial hook (`lib/pinmark/hooks/erb_partial.rb`) — currently no spec.
- Source locator edge cases (anonymous classes, classes loaded from gems).

## Code style

- Run `bundle exec rubocop` before opening a PR. The CI lint job is currently
  non-blocking, but we want to keep the diff clean.
- Don't add `# rubocop:disable` comments — fix the offense or push back on the
  rule in a separate PR.
- Comments should explain *why*, not *what*. Identifiers should carry the
  *what*.
- No new abstractions for hypothetical future requirements. If the new code is
  three similar lines, leave it as three lines until a fourth case shows up.

## Pull requests

- Keep the diff focused. One feature or fix per PR.
- Update `CHANGELOG.md` under an `## Unreleased` heading if your change
  affects host-visible behavior.
- Update relevant docs (`README.md`, `docs/`) if you change the install steps,
  config surface, or MCP tool shapes.
- Mention the host scenario you tested (Rails version, renderer, asset
  pipeline) — Pinmark touches enough plumbing that "works in dummy app"
  isn't always sufficient.
- We use [Conventional Commits](https://www.conventionalcommits.org/) for
  commit messages: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.

## Releasing (maintainers)

1. Bump `lib/pinmark/version.rb`.
2. Update `CHANGELOG.md` with the new version + date.
3. `bundle install` to refresh `Gemfile.lock`.
4. Commit, tag (`git tag v0.x.y`), push (`git push --follow-tags`).
5. `gem build pinmark.gemspec && gem push pinmark-0.x.y.gem`.

## Reporting issues

Use the troubleshooting checklist in
[docs/troubleshooting.md](docs/troubleshooting.md) to gather context before
filing. The most useful issues include the page's `view-source:` so we can see
whether the render hooks fired.
