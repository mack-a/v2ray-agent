# Fork Repository Declaration Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the fork repository legally clear and operationally explicit by documenting upstream provenance, maintainer ownership, and the fork's installation/update entry points without changing runtime behavior.

**Architecture:** Keep upstream license and attribution intact, then add a small set of repo-level declaration files that separate legal provenance from fork-specific maintenance notes. `README.md` remains the public front door, while `FORK-ORIGIN.md`, `UPSTREAM-SYNC.md`, and `CHANGELOG.md` carry the durable maintenance metadata. This keeps the fork easy to understand, easy to sync, and compliant with upstream licensing.

**Tech Stack:** Markdown documentation, Git, existing repository files.

---

### Task 1: Add a fork provenance section to the README files

**Files:**
- Modify: `README.md`
- Modify: `documents/en/README_EN.md`

- [ ] **Step 1: Prepare the exact README wording**

Add this block near the top of `README.md`, immediately after the project title or opening paragraph:

```md
## Fork Notice

This repository is a maintained fork of `mack-a/v2ray-agent`.

- Upstream project: https://github.com/mack-a/v2ray-agent
- Current fork maintainer: sciman
- Installation and update entry points in this fork point to `sciman-top/v2ray-agent`
- Original author rights, license terms, and upstream attribution remain preserved
```

Add this equivalent block to `documents/en/README_EN.md`:

```md
## Fork Notice

This repository is a maintained fork of `mack-a/v2ray-agent`.

- Upstream project: https://github.com/mack-a/v2ray-agent
- Current fork maintainer: sciman
- Installation and update entry points in this fork point to `sciman-top/v2ray-agent`
- Original author rights, license terms, and upstream attribution remain preserved
```

- [ ] **Step 2: Apply the README edits**

Insert the fork notice without removing the existing install commands, usage notes, or license references. Keep the upstream issue links only where they are part of the preserved attribution; otherwise prefer the fork's own issue link where the repository is talking about the maintained fork.

- [ ] **Step 3: Verify the README surfaces the fork identity correctly**

Run:

```bash
rg -n "Fork Notice|Upstream project|Current fork maintainer|sciman-top/v2ray-agent" README.md documents/en/README_EN.md
```

Expected:

```text
README.md:...:## Fork Notice
README.md:...:Current fork maintainer: sciman
documents/en/README_EN.md:...:## Fork Notice
documents/en/README_EN.md:...:Current fork maintainer: sciman
```

- [ ] **Step 4: Commit**

```bash
git add README.md documents/en/README_EN.md
git commit -m "docs: add fork provenance notice to readmes"
```

### Task 2: Add a repository origin file

**Files:**
- Create: `FORK-ORIGIN.md`

- [ ] **Step 1: Create the file with explicit upstream provenance**

Use this content:

```md
# Fork Origin

This repository is a maintained fork of `mack-a/v2ray-agent`.

## Upstream

- Upstream repository: https://github.com/mack-a/v2ray-agent
- Upstream purpose: original coexistence script project

## Fork Maintainer

- Maintainer: sciman
- Fork repository: https://github.com/sciman-top/v2ray-agent
- Fork branch: `sciman-v2ray-agent`

## Scope of This Fork

- Preserve upstream license and attribution
- Keep installation and update entry points pointing to this fork
- Make compatibility, maintenance, and operational improvements
- Avoid rewriting upstream history or removing original author rights
```

- [ ] **Step 2: Verify the file content and links**

Run:

```bash
rg -n "Upstream repository|Fork Maintainer|Fork branch|Preserve upstream license" FORK-ORIGIN.md
```

Expected:

```text
FORK-ORIGIN.md:...:Upstream repository: https://github.com/mack-a/v2ray-agent
FORK-ORIGIN.md:...:Maintainer: sciman
FORK-ORIGIN.md:...:Fork branch: `sciman-v2ray-agent`
```

- [ ] **Step 3: Commit**

```bash
git add FORK-ORIGIN.md
git commit -m "docs: add fork origin provenance file"
```

### Task 3: Add an upstream synchronization policy file

**Files:**
- Create: `UPSTREAM-SYNC.md`

- [ ] **Step 1: Create the synchronization guidance**

Use this content:

```md
# Upstream Sync Policy

This fork is based on `mack-a/v2ray-agent` and is intended to stay compatible with upstream changes whenever practical.

## Sync Source

- Upstream source: `https://github.com/mack-a/v2ray-agent`
- Fork source: `https://github.com/sciman-top/v2ray-agent`
- Fork branch: `sciman-v2ray-agent`

## Sync Rules

1. Pull upstream changes before introducing unrelated fork-specific edits.
2. Keep upstream licensing, author attribution, and copyright notices intact.
3. Record fork-specific operational changes in `CHANGELOG.md`.
4. Keep install and update URLs pointed at the fork unless explicitly reverting to upstream.
5. Avoid mixing upstream sync commits with fork branding commits when a clean split is possible.
```

- [ ] **Step 2: Verify the policy file is self-contained**

Run:

```bash
rg -n "Sync Source|Sync Rules|sciman-v2ray-agent|mack-a/v2ray-agent" UPSTREAM-SYNC.md
```

Expected:

```text
UPSTREAM-SYNC.md:...:Sync Source
UPSTREAM-SYNC.md:...:Sync Rules
UPSTREAM-SYNC.md:...:`sciman-v2ray-agent`
UPSTREAM-SYNC.md:...:`mack-a/v2ray-agent`
```

- [ ] **Step 3: Commit**

```bash
git add UPSTREAM-SYNC.md
git commit -m "docs: add upstream synchronization policy"
```

### Task 4: Add a fork changelog template

**Files:**
- Create: `CHANGELOG.md`

- [ ] **Step 1: Create the changelog skeleton**

Use this content:

```md
# Changelog

All notable changes to this fork will be documented here.

## Unreleased

### Added
- Fork provenance documentation
- Fork install and update entry points

### Changed
- Repository URLs updated to point at the `sciman-v2ray-agent` branch

### Fixed
- Operational maintenance changes recorded in the fork history

## Notes

- Upstream compatibility is preserved whenever possible
- Original upstream author attribution remains intact
- License terms continue to follow the upstream repository
```

- [ ] **Step 2: Verify the changelog is a legal and maintenance aid, not a rewrite of upstream history**

Run:

```bash
rg -n "Unreleased|Fork provenance|Original upstream author attribution|License terms" CHANGELOG.md
```

Expected:

```text
CHANGELOG.md:...:Unreleased
CHANGELOG.md:...:Fork provenance documentation
CHANGELOG.md:...:Original upstream author attribution remains intact
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add fork changelog template"
```

### Task 5: Final consistency check

**Files:**
- Review: `LICENSE`
- Review: `README.md`
- Review: `documents/en/README_EN.md`
- Review: `FORK-ORIGIN.md`
- Review: `UPSTREAM-SYNC.md`
- Review: `CHANGELOG.md`

- [ ] **Step 1: Confirm upstream legal text is still present**

Run:

```bash
rg -n "license|copyright|mack-a|Upstream project|Original author rights" LICENSE README.md documents/en/README_EN.md FORK-ORIGIN.md UPSTREAM-SYNC.md CHANGELOG.md
```

Expected:

```text
LICENSE:...  # upstream license text remains
README.md:...Upstream project: https://github.com/mack-a/v2ray-agent
FORK-ORIGIN.md:...Preserve upstream license and attribution
UPSTREAM-SYNC.md:...Keep upstream licensing, author attribution, and copyright notices intact
```

- [ ] **Step 2: Confirm fork entry points all match the fork branch**

Run:

```bash
rg -n "sciman-top/v2ray-agent/sciman-v2ray-agent|github.com/sciman-top/v2ray-agent/tree/sciman-v2ray-agent" README.md documents/en/README_EN.md FORK-ORIGIN.md UPSTREAM-SYNC.md CHANGELOG.md install.sh shell/install_en.sh
```

Expected:

```text
README.md:...sciman-top/v2ray-agent/sciman-v2ray-agent
documents/en/README_EN.md:...sciman-top/v2ray-agent/sciman-v2ray-agent
install.sh:...github.com/sciman-top/v2ray-agent/tree/sciman-v2ray-agent
shell/install_en.sh:...github.com/sciman-top/v2ray-agent/tree/sciman-v2ray-agent
```

- [ ] **Step 3: Commit**

```bash
git add LICENSE README.md documents/en/README_EN.md FORK-ORIGIN.md UPSTREAM-SYNC.md CHANGELOG.md
git commit -m "docs: finalize fork declaration structure"
```
