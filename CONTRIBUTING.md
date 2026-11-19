# Contributing

Thanks for helping make Fedora feel more familiar without losing what makes it
Fedora.

## Before you start

- Read [README.md](README.md), [docs/architecture.md](docs/architecture.md) and
  [docs/extensions.md](docs/extensions.md).
- Test destructive changes on a disposable Fedora GNOME VM.
- Do not add copied Ubuntu/Yaru artwork, third-party binaries or external
  repositories.
- Keep Fedora's repositories, DNF, RPM, kernel, systemd and `/etc/os-release`
  untouched.

## Development setup

There is no build step:

```bash
git clone <repository> ubuntuify-fedora
cd ubuntuify-fedora
bash tests/run.sh
```

Useful checks:

```bash
bash -n ubuntuify bin/ubuntuify
for file in src/*.sh src/*/*.sh tests/*.sh tests/*/*.sh; do
  bash -n "$file" || exit 1
done
python3 -m py_compile src/core/state.py src/core/gvariant.py \
  src/core/artwork.py src/extensions/ego_helper.py
```

If available, run `shellcheck` on the changed Bash files. Fix real warnings
instead of adding blanket suppressions.

## Style

### Bash

- `#!/usr/bin/env bash` and `set -Eeuo pipefail` in launchers/test files.
- `snake_case` functions prefixed `uf_`; globals `UF_UPPER`.
- Quote all expansions, including array expansions.
- Use `command -v`/`uf_have` before invoking optional tools.
- Keep functions focused; the architecture notes explain why.
- Diagnostics go to stderr through `uf_info`/`uf_warn`/etc. A function used in
  command substitution must not print human-readable text to stdout.
- Never add `eval`, `curl | bash`, or unquoted `rm -rf`.
- Use `uf_setting`/`uf_gs_set` rather than raw `gsettings set`. Every setting
  must be schema/key/range checked and recorded for rollback.
- Check optional settings and return `2` for "skipped/unavailable" where the
  component contract expects it.

### Python

- Python 3 standard library only.
- Use `argparse`, explicit argument lists (never `shell=True`), type hints where
  useful and clear error messages.
- Keep helpers deterministic; `artwork.py` uses a fixed seed.

### User-facing text

- Use the existing `[INFO]`, `[OK]`, `[WARN]`, `[ERROR]`, `[SKIP]` vocabulary.
- Do not claim "100% Ubuntu" or "identical to Ubuntu".
- Explain fallbacks and known Fedora packaging gaps honestly.
- Do not assume English, a US keyboard, a US locale or a specific desktop
  background.

## Tests

Add a focused unit test for logic changes and update integration tests for CLI
behavior. The harness is in `tests/lib/harness.sh`; mocks are in
`tests/mocks/`; fixtures are in `tests/fixtures/`.

```bash
bash tests/unit/test_gsettings.sh
bash tests/run.sh
```

Guidelines:

- Never touch the real `HOME`, dconf or installed packages from a test.
- Use the harness sandbox and mocks.
- Test both the success path and the missing-schema/key fallback.
- Do not weaken assertions or skip tests to make a failure disappear.
- For a visual change, include the manual VM verification steps in the PR.

See [docs/testing.md](docs/testing.md) for the VM workflow.

## Adding a component

1. Add the name, title, alias (if useful) and apply order in
   `src/components.sh`.
2. Implement `uf_<name>_apply` in a focused module and source it from
   `src/lib.sh`.
3. Use `uf_setting` for each GSettings key; return `2` when the component is
   deliberately skipped.
4. Add it to the relevant profiles and `config/ubuntu-defaults.conf` if it has
   options.
5. Add a unit/integration test and update README/docs.

## Adding an extension

Follow [docs/extensions.md](docs/extensions.md), add Fedora/EGO metadata to
`config/extensions.conf`, use `uf_ext_component_guard` and test on the current
Fedora release. Do not hard-code a UUID that changes per release; list
candidates instead.

## Commit messages

Use a concise conventional-style subject:

```text
feat: add Fedora environment detection
fix: skip missing GSettings keys
test: cover component restore
docs: document extension fallback
```

Keep unrelated changes out of the same commit. Explain *why* in the body when
the change is not obvious.

## Pull requests

Include:

- what changed and why;
- Fedora and GNOME versions tested;
- whether a VM was used and which components were exercised;
- tests run (`bash tests/run.sh`, static checks);
- known limitations or follow-ups.

Be respectful. This is a community project; disagreements about design are
fine, personal attacks are not.
