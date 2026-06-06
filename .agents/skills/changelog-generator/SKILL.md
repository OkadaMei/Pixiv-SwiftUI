---
name: changelog-generator
description: Generate user-facing changelogs from git history between two versions. Use this when the user asks to summarize changes, create release notes, or generate a changelog between releases.
---

# Changelog Generator Skill

Generate a user-facing changelog from git history between two versions. Use this when the user asks to summarize changes, create release notes, or generate a changelog between releases.

## Version Resolution

1. Ask the user for the two versions (from -> to) if not specified.
2. If only one version is given (e.g., "changelog for v0.14.0"), treat it as `from`, and `to` defaults to `HEAD`.
3. If no version is given at all, ask the user which version range they want.
4. Resolve each version by checking in this order:
   - **Git tags** matching `v<version>` (e.g., `v0.14.0`). Use `git tag --list 'v*'` to list tags.
   - **Commit messages** containing version strings (e.g., "chore: bump version to 0.14.3"). Search with `git log --oneline --grep="bump version"`.
   - If neither matches, ask the user for clarification.

## Generating the Log

Once both references are resolved:

```bash
git log --oneline <from-ref>..<to-ref>
```

Examine each commit message. Classify commits into categories. Merge multiple commits that logically belong to the same change into a single list item.

## Changelog Format

- Write in **Simplified Chinese** (简体中文).
- Use **no emoji** unless the emoji is part of the actual code changes.
- Structure by **second-level Markdown headings** (`##`) for categories.
- Default categories: `## 新功能` (feat), `## 优化` (perf, refactor), `## 问题修复` (fix). Add custom categories when the content fits better (e.g., `## 本地化`, `## 样式调整`, `## 依赖更新`).
- Under each heading, use an **unordered list** (`-`) for each change item.
- Each item ends with the contributor in parentheses: `(@username)`. Use `git log --format="%an" <from-ref>..<to-ref>` or `git shortlog -sne <from-ref>..<to-ref>` to determine contributors. If multiple contributors worked on related commits, list all: `(@user1, @user2)`.
- If the author is the project owner and sole contributor, you may omit the contributor annotation.

## Audience & Scope

The changelog is for **app users**, not developers. Therefore:

- **Skip purely technical commits** (e.g., CI config changes, dependency version bumps that don't affect behavior, internal refactoring, linting fixes, documentation-only changes) **unless** the user explicitly asks to include them.
- Describe changes in user-facing terms. For example, "perf: replace KFImage with lightweight loader" becomes "优化图片加载性能，减少内存占用".
- When a single user-facing feature was built across multiple commits, merge them into one item.

## Examples

Given commits:
```
a1b2c3 feat: add bookmark visibility toggle in collection page
d4e5f6 fix: restore glass blur background on IllustCard tags
g7h8i9 perf: replace shadow() with CardShadowView for better performance
j0k1l2 chore: bump version to 0.14.3
```

Output:
```
## 新功能

- 收藏页新增公开/非公开筛选切换功能 (@user)

## 优化

- 优化 IllustCard 标签毛玻璃背景及阴影渲染性能 (@user)

## 问题修复

- 修复 IllustCard 标签毛玻璃背景丢失的问题 (@user)
```

Given commits with skip logic applied:
```
a1b2c3 feat: add bookmark visibility toggle
d4e5f6 chore: exclude pixez-flutter in swiftlint
g7h8i9 chore: bump version to 0.14.3
```

Output (lint config change and version bump are skipped as technical):
```
## 新功能

- 收藏页新增公开/非公开筛选切换功能 (by @user)
```

## Verification

After generating the changelog, verify:
1. All categories make sense for the changes listed.
2. No emoji was included.
3. Purely technical commits were excluded (unless user requested inclusion).
4. Related commits are merged into single items.
5. Each item is described from the user's perspective.
