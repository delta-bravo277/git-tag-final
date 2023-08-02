#!/bin/bash

set -o pipefail

# config
default_semvar_bump=${DEFAULT_BUMP:-minor}
default_branch=${DEFAULT_BRANCH:-$GITHUB_BASE_REF} # get the default branch from github runner env vars
with_v=${WITH_V:-false}
# release_branches=${RELEASE_BRANCHES:-master,main}
# custom_tag=${CUSTOM_TAG:-}
source=${SOURCE:-.}
dryrun=${DRY_RUN:-false}
initial_version=${INITIAL_VERSION:-0.0.0}
tag_context=${TAG_CONTEXT:-repo}
# prerelease=${PRERELEASE:-false}
# suffix=${PRERELEASE_SUFFIX:-beta}
verbose=${VERBOSE:-false}
major_string_token=${MAJOR_STRING_TOKEN:-#major}
minor_string_token=${MINOR_STRING_TOKEN:-#minor}
patch_string_token=${PATCH_STRING_TOKEN:-#patch}
none_string_token=${NONE_STRING_TOKEN:-#none}
branch_history=${BRANCH_HISTORY:-compare}

git config --global --add safe.directory /github/workspace

cd "${GITHUB_WORKSPACE}/${source}" || exit 1

echo "*** CONFIGURATION ***"
echo -e "\tDEFAULT_BUMP: ${default_semvar_bump}"
echo -e "\tDEFAULT_BRANCH: ${default_branch}"
echo -e "\tWITH_V: ${with_v}"
# echo -e "\tRELEASE_BRANCHES: ${release_branches}"
# echo -e "\tCUSTOM_TAG: ${custom_tag}"
echo -e "\tSOURCE: ${source}"
echo -e "\tDRY_RUN: ${dryrun}"
echo -e "\tINITIAL_VERSION: ${initial_version}"
echo -e "\tTAG_CONTEXT: ${tag_context}"
# echo -e "\tPRERELEASE: ${prerelease}"
# echo -e "\tPRERELEASE_SUFFIX: ${suffix}"
echo -e "\tVERBOSE: ${verbose}"
echo -e "\tMAJOR_STRING_TOKEN: ${major_string_token}"
echo -e "\tMINOR_STRING_TOKEN: ${minor_string_token}"
echo -e "\tPATCH_STRING_TOKEN: ${patch_string_token}"
echo -e "\tNONE_STRING_TOKEN: ${none_string_token}"
echo -e "\tBRANCH_HISTORY: ${branch_history}"

if $verbose; then
    set -x
fi

setOutput() {
    echo "${1}=${2}" >> "${GITHUB_OUTPUT}"
}

current_branch=$(git rev-parse --abbrev-ref HEAD)

# Fetch tags
git fetch --tags

tagFmt="^v?[0-9]+\.[0-9]+\.[0-9]+$"

# Get latest tag that looks like a semver (with or without v)
case "$tag_context" in
    *repo*) 
        tag="$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' | grep -E "$tagFmt" | head -n 1)"
        ;;
    *branch*) 
        tag="$(git tag --list --merged HEAD --sort=-v:refname | grep -E "$tagFmt" | head -n 1)"
        ;;
    * ) echo "Unrecognised context"
        exit 1;;
esac

# If there are none, start tags at INITIAL_VERSION
if [ -z "$tag" ]; then
    if $with_v; then
        tag="v$initial_version"
    else
        tag="$initial_version"
    fi
fi

# Get current commit hash for tag
tag_commit=$(git rev-list -n 1 "$tag")
# Get current commit hash
commit=$(git rev-parse HEAD)

# Skip if there are no new commits
if [ "$tag_commit" == "$commit" ]; then
    echo "No new commits since previous tag. Skipping..."
    setOutput "new_tag" "$tag"
    setOutput "tag" "$tag"
    exit 0
fi

# Sanitize default_branch
if [ -z "${default_branch}" ] && [ "$branch_history" == "full" ]; then
    default_branch=$(git branch -rl '*/master' '*/main' | cut -d / -f2)
    if [ -z "${default_branch}" ]; then
        echo "::error::DEFAULT_BRANCH must not be null, something has gone wrong."
        exit 1
    fi
fi

# Get the merge commit message
log=$(git log "${default_branch}"..HEAD --format=%B)
printf "History:\n---\n%s\n---\n" "$log"

case "$log" in
    *$major_string_token* ) new=$(semver -i major "$tag"); part="major";;
    *$minor_string_token* ) new=$(semver -i minor "$tag"); part="minor";;
    *$patch_string_token* ) new=$(semver -i patch "$tag"); part="patch";;
    * ) new=$(semver -i patch "$tag"); part="patch";;
esac

if $with_v; then
    new="v$new"
fi

echo "Bumping tag ${tag} - New tag ${new}"

# Set outputs
setOutput "new_tag" "$new"
setOutput "part" "$part"
setOutput "tag" "$new"

# Dry run exit without real changes
if $dryrun; then
    exit 0
fi

# Create local git tag
git tag "$new"

# Push new tag ref to GitHub
dt=$(date '+%Y-%m-%dT%H:%M:%SZ')
full_name=$GITHUB_REPOSITORY
git_refs_url=$(jq .repository.git_refs_url "$GITHUB_EVENT_PATH" | tr -d '"' | sed 's/{\/sha}//g')

echo "$dt: **pushing tag $new to repo $full_name"

git_refs_response=$(
curl -s -X POST "$git_refs_url" \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF

{
  "ref": "refs/tags/$new",
  "sha": "$commit"
}
EOF
)

git_ref_posted=$( echo "${git_refs_response}" | jq .ref | tr -d '"' )

echo "::debug::${git_refs_response}"
if [ "${git_ref_posted}" = "refs/tags/${new}" ]; then
    exit 0
else
    echo "::error::Tag was not created properly."
    exit 1
fi
