# AGENTS.md — homebrew-tap

Homebrew tap publishing the nanohype CLIs. Install surface only: every formula
here is a build artifact of the CLI's own repo, and this repo holds no source.

## Install

```sh
brew tap nanohype/tap
brew install nanohype/tap/cloudgov
```

Or without tapping first: `brew install nanohype/tap/<tool>`.

## Formulae are generated — do not hand-edit

`Formula/*.rb` is written by GoReleaser from the producing repo's release
pipeline. `Formula/cloudgov.rb` comes from the `brews:` block in
[`nanohype/cloudgov`](https://github.com/nanohype/cloudgov)'s `.goreleaser.yaml`,
which opens a PR here on each release (`pull_request.enabled: true`, because
`main` requires a PR).

**A fix applied to a formula in this repo survives until the next release, then
silently regresses.** Anything wrong with a formula's `desc`, `test`, `install`
body, license, or homepage is a change to the producing repo's `.goreleaser.yaml`
— not to the file here.

Two consequences worth knowing before you touch anything:

- The `README.md` tool table mirrors each formula's `desc`. When a `desc` changes
  upstream, the table changes with it, in the same PR.
- CI deliberately does not block on two generator-side findings. See below.

## What CI checks

`.github/workflows/ci.yml`, on every PR and every push to `main`:

| Check | Blocking | Covers |
| --- | --- | --- |
| `brew style` | yes | formula RuboCop, plus shellcheck + shfmt over `script/` (§) |
| `brew audit --online --except=version` | yes | formula correctness, reachable homepage and URLs |
| `script/strict-audit.sh` | yes | `brew audit --strict`, allowing only known generator findings |
| `brew install` + `brew test` | yes | the runner's platform installs and the binary runs |
| `script/verify-artifact-checksums.sh` | yes | **every** declared `sha256` against its published artifact |

(§) The shell rules `brew style` applies come from Homebrew's own
`.shellcheckrc` and its shfmt settings, not from any config in this repo. The
same `shellcheck` or `shfmt` invoked directly against a plain clone will not
agree with it. Run the checks through `brew style` — and `brew style --fix` to
settle shfmt layout — rather than reproducing the rules by hand.

Two things about that setup are deliberate and easy to "fix" wrongly:

**`--except=version` is permanent, not a workaround.** GoReleaser always emits
`version` in the formulae it generates, and `brew audit` calls that redundant
with the version it scans from the URL. It fails with no flags at all — not
strict-only, not online-only — so every formula this tap will ever receive
carries it. Dropping the flag turns the gate red on correct formulae.

**`script/strict-audit.sh` allows one known finding and fails on any other.**
`brew audit --strict` reports `Formula/cloudgov.rb:48` using `"#{bin}/cloudgov"`
where it wants `bin/"cloudgov"`. That one *is* fixable, in cloudgov's
`.goreleaser.yaml` `brews[].test` block, so the fix belongs upstream rather than
in a generated file the next release overwrites.

The step is blocking rather than `continue-on-error`. A permanently-failing
advisory step renders "1 problem" and "3 problems" identically, so a second,
real finding would hide behind the expected one. The script asserts which
findings are expected instead: known ones pass, anything new fails the build,
and once cloudgov ships the fix a clean run says so and asks to be simplified
away.

**Never symlink the checkout into `Library/Taps` to run these locally.** A
symlinked tap resolves and audits without complaint but silently skips audit's
RuboCop cops — the same checkout reports one finding as a symlink and two as a
real directory. Use `cp -R` or a clone, as CI does.

## Renovate

`renovate.json` extends the org preset and sets
`enabledManagers: ["github-actions"]`. Renovate manages the pinned action SHAs in
`.github/workflows/` and nothing else.

The scope is an allowlist rather than an `ignorePaths` denylist on purpose:
Renovate detects `Formula/*.rb` as a `homebrew` manager, and formula versions
belong to GoReleaser. An allowlist cannot be widened by accident into a state
where both try to bump the same file.

## Adding a CLI to this tap

1. Add a `brews:` block to the CLI's `.goreleaser.yaml` targeting
   `nanohype/homebrew-tap` with `pull_request.enabled: true`.
2. Release it. GoReleaser opens the formula PR here.
3. Add the tool to the `README.md` table, description matching the formula's
   `desc`.
