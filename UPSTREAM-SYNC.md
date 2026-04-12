# Upstream Sync Guide

This repository is a maintained fork of `mack-a/v2ray-agent`.

## Sources

- Upstream repository: https://github.com/mack-a/v2ray-agent
- Fork repository: https://github.com/sciman-top/v2ray-agent
- Active branch: `sciman-v2ray-agent`

## Sync Rules

1. Pull upstream changes before making unrelated fork-specific edits.
2. Keep upstream license text, copyright notices, and attribution intact.
3. Record fork-specific maintenance, compatibility, and operational changes in `CHANGELOG.md`.
4. Keep installation and update URLs pointed at this fork unless a revert to upstream is explicitly intended.
5. Prefer separating upstream sync commits from branding or provenance commits when practical.

## Suggested Workflow

1. Fetch upstream changes from `mack-a/v2ray-agent`.
2. Merge or rebase the upstream changes into this branch.
3. Resolve conflicts without removing upstream rights or license information.
4. Verify the fork-specific entry points still point to `sciman-top/v2ray-agent`.
5. Summarize the fork-only impact in `CHANGELOG.md`.

## Notes

- This document defines sync practice only.
- It does not replace the upstream license or the repository `LICENSE` file.
