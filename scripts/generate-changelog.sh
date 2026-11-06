#!/usr/bin/env bash
set -euo pipefail

# Generates structured Markdown release notes and a cumulative CHANGELOG.md
# from git history using Conventional Commits.
#
# Usage:
#   bash scripts/generate-changelog.sh [--tag vX.Y.Z] [--release-notes FILE] [--changelog FILE] [--repo OWNER/REPO]

TAG=""
RELEASE_NOTES_OUT=""
CHANGELOG_OUT=""
REPO="${GITHUB_REPOSITORY:-MatthieuD134/AirSwitch}"

while [ $# -gt 0 ]; do
    case "$1" in
        --tag)
            TAG="${2:-}"
            shift 2
            ;;
        --release-notes)
            RELEASE_NOTES_OUT="${2:-}"
            shift 2
            ;;
        --changelog)
            CHANGELOG_OUT="${2:-}"
            shift 2
            ;;
        --repo)
            REPO="${2:-}"
            shift 2
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

if [ -z "$TAG" ]; then
    TAG="$(git describe --tags --match 'v[0-9]*' --exact-match HEAD 2>/dev/null || echo "Unreleased")"
fi

valid_tag_re='^(Unreleased|v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?)$'
if ! [[ "$TAG" =~ $valid_tag_re ]]; then
    printf 'Error: invalid release tag "%s"\n' "$TAG" >&2
    exit 1
fi

valid_repo_re='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
if ! [[ "$REPO" =~ $valid_repo_re ]]; then
    printf 'Error: invalid repository identifier "%s"\n' "$REPO" >&2
    exit 1
fi

resolve_commit_for_ref() {
    local ref="$1"
    if git rev-parse -q --verify "${ref}^{commit}" >/dev/null 2>&1; then
        git rev-parse "${ref}^{commit}"
    else
        git rev-parse HEAD
    fi
}

find_previous_tag() {
    local target_commit="$1"
    local current_tag="$2"
    local is_prerelease=0
    if [[ "$current_tag" == *-* ]]; then
        is_prerelease=1
    fi

    local merged_tags
    merged_tags="$(git -c versionsort.suffix=- tag --merged "$target_commit" -l 'v[0-9]*' --sort=-version:refname)"

    local seen_current=0
    if ! git rev-parse -q --verify "refs/tags/$current_tag" >/dev/null 2>&1; then
        # Target tag does not exist on disk yet; the newest eligible merged tag is the baseline
        seen_current=1
    fi

    local candidate
    while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        if [ "$seen_current" -eq 0 ]; then
            if [ "$candidate" = "$current_tag" ]; then
                seen_current=1
            fi
            continue
        fi

        if [ "$is_prerelease" -eq 0 ] && [[ "$candidate" == *-* ]]; then
            continue
        fi

        printf '%s\n' "$candidate"
        return
    done <<< "$merged_tags"

    printf '\n'
}

render_section_for_range() {
    local heading_tag="$1"
    local target_commit="$2"
    local prev_tag="$3"
    local commit_date="$4"

    local range_spec="$target_commit"
    if [ -n "$prev_tag" ]; then
        local prev_commit
        prev_commit="$(git rev-parse "${prev_tag}^{commit}")"
        range_spec="${prev_commit}..${target_commit}"
    fi

    local commit_list
    commit_list="$(git rev-list --no-merges --reverse "$range_spec")"

    local breaking_items=""
    local feat_items=""
    local fix_items=""
    local perf_refactor_items=""
    local build_ci_docs_items=""
    local other_items=""

    local sha
    while IFS= read -r sha; do
        [ -z "$sha" ] && continue

        local short_sha subject body
        short_sha="$(git show -s --format=%h "$sha")"
        subject="$(git show -s --format=%s "$sha")"
        body="$(git show -s --format=%b "$sha")"

        # Skip automated release version commits
        local release_chore_re='^chore\(release\):'
        local release_tag_re='^Release[[:space:]]+v[0-9]'
        if [[ "$subject" =~ $release_chore_re ]] || [[ "$subject" =~ $release_tag_re ]]; then
            continue
        fi

        local type=""
        local scope=""
        local bang=""
        local desc="$subject"
        local cc_re='^([a-zA-Z]+)(\(([^)]+)\))?(!)?:[[:space:]]*(.+)$'

        if [[ "$subject" =~ $cc_re ]]; then
            type="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
            scope="${BASH_REMATCH[3]}"
            bang="${BASH_REMATCH[4]}"
            desc="${BASH_REMATCH[5]}"
        fi

        local formatted_line
        if [ -n "$scope" ]; then
            formatted_line="- **${scope}**: ${desc} (${short_sha})"
        else
            formatted_line="- ${desc} (${short_sha})"
        fi

        if [ -n "$bang" ] || [[ "$body" == *"BREAKING CHANGE:"* ]] || [[ "$body" == *"BREAKING-CHANGE:"* ]]; then
            breaking_items+="${formatted_line}"$'\n'
            continue
        fi

        case "$type" in
            feat)
                feat_items+="${formatted_line}"$'\n'
                ;;
            fix)
                fix_items+="${formatted_line}"$'\n'
                ;;
            perf|refactor)
                perf_refactor_items+="${formatted_line}"$'\n'
                ;;
            build|ci|docs|test|chore|style)
                build_ci_docs_items+="${formatted_line}"$'\n'
                ;;
            *)
                other_items+="${formatted_line}"$'\n'
                ;;
        esac
    done <<< "$commit_list"

    printf '## %s (%s)\n\n' "$heading_tag" "$commit_date"

    local has_any=0

    if [ -n "$breaking_items" ]; then
        printf '### ⚠️ Breaking Changes\n%s\n' "$breaking_items"
        has_any=1
    fi
    if [ -n "$feat_items" ]; then
        printf '### ✨ Features\n%s\n' "$feat_items"
        has_any=1
    fi
    if [ -n "$fix_items" ]; then
        printf '### 🐛 Bug Fixes\n%s\n' "$fix_items"
        has_any=1
    fi
    if [ -n "$perf_refactor_items" ]; then
        printf '### ⚡️ Improvements & Refactoring\n%s\n' "$perf_refactor_items"
        has_any=1
    fi
    if [ -n "$build_ci_docs_items" ]; then
        printf '### 🛠 Maintenance & CI\n%s\n' "$build_ci_docs_items"
        has_any=1
    fi
    if [ -n "$other_items" ]; then
        printf '### 📦 Other Changes\n%s\n' "$other_items"
        has_any=1
    fi

    if [ "$has_any" -eq 0 ]; then
        printf -- '- Maintenance and version bump updates.\n\n'
    fi

    if [ -n "$prev_tag" ] && [ "$heading_tag" != "Unreleased" ]; then
        printf '**Full Changelog**: https://github.com/%s/compare/%s...%s\n' "$REPO" "$prev_tag" "$heading_tag"
    fi
}

TARGET_COMMIT="$(resolve_commit_for_ref "$TAG")"
TARGET_DATE="$(git show -s --format=%cs "$TARGET_COMMIT")"
PREV_TAG="$(find_previous_tag "$TARGET_COMMIT" "$TAG")"

RELEASE_NOTES_CONTENT="$(render_section_for_range "$TAG" "$TARGET_COMMIT" "$PREV_TAG" "$TARGET_DATE")"

if [ -n "$RELEASE_NOTES_OUT" ]; then
    mkdir -p "$(dirname "$RELEASE_NOTES_OUT")"
    printf '%s\n' "$RELEASE_NOTES_CONTENT" > "$RELEASE_NOTES_OUT"
fi

if [ -n "$CHANGELOG_OUT" ]; then
    mkdir -p "$(dirname "$CHANGELOG_OUT")"
    TAG_LIST="$(git -c versionsort.suffix=- tag --merged "$TARGET_COMMIT" -l 'v[0-9]*' --sort=-version:refname)"
    {
        printf '# Changelog\n\n'
        if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
            printf '%s\n\n' "$RELEASE_NOTES_CONTENT"
        fi

        while IFS= read -r current_t; do
            [ -z "$current_t" ] && continue
            t_commit="$(git rev-parse "${current_t}^{commit}")"
            t_date="$(git show -s --format=%cs "$t_commit")"
            t_prev="$(find_previous_tag "$t_commit" "$current_t")"
            render_section_for_range "$current_t" "$t_commit" "$t_prev" "$t_date"
            printf '\n'
        done <<< "$TAG_LIST"
    } > "$CHANGELOG_OUT"
fi

if [ -z "$RELEASE_NOTES_OUT" ] && [ -z "$CHANGELOG_OUT" ]; then
    printf '%s\n' "$RELEASE_NOTES_CONTENT"
fi
