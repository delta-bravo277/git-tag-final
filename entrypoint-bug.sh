#!/bin/bash

set -o pipefail

# config
default_semvar_bump=${DEFAULT_BUMP:-none}
default_branch=main 
with_v=${WITH_V:-false}
source=${SOURCE:-.}
initial_version=${INITIAL_VERSION:-0.0.0}
tag_context=${TAG_CONTEXT:-repo}
major_string_token=${MAJOR_STRING_TOKEN:-#major}
minor_string_token=${MINOR_STRING_TOKEN:-#minor}
patch_string_token=${PATCH_STRING_TOKEN:-#patch}
none_string_token=${NONE_STRING_TOKEN:-#none}
branch_history=compare

git config --global --add safe.directory /github/workspace

cd "${GITHUB_WORKSPACE}/${source}" || exit 1

echo "*** CONFIGURATION ***"
echo -e "\tDEFAULT_BUMP: ${default_semvar_bump}"
echo -e "\tDEFAULT_BRANCH: ${default_branch}"
echo -e "\tWITH_V: ${with_v}"
echo -e "\tINITIAL_VERSION: ${initial_version}"
echo -e "\tTAG_CONTEXT: ${tag_context}"
echo -e "\tMAJOR_STRING_TOKEN: ${major_string_token}"
echo -e "\tMINOR_STRING_TOKEN: ${minor_string_token}"
echo -e "\tPATCH_STRING_TOKEN: ${patch_string_token}"
echo -e "\tNONE_STRING_TOKEN: ${none_string_token}"
echo -e "\tBRANCH_HISTORY: ${branch_history}"


setOutput() {
    echo "${1}=${2}" >> "${GITHUB_OUTPUT}"
}


# fetch all tags
git fetch --tags

tagFormat="^v?[0-9]+\.[0-9]+\.[0-9]+$"

case "$tag_context" in
    *repo*) 
        tag="$(git for-each-ref --sort=-v:refname | cut -d '/' -f 3- | grep -E "$tagFormat" | head -n 1)"
        ;;
    *branch*) 
        tag="$(git tag --list --merged HEAD --sort=-v:refname | grep -E "$tagFormat" | head -n 1)"
        ;;
    * ) echo "Unrecognised context"
        exit 1;;
esac

# set INITIAL_VERSION
if [ -z "$tag" ]
then
    if $with_v
    then
        tag="v$initial_version"
    else
        tag="$initial_version"
    fi
fi

# get current commit hash for tag
tag_commit=$(git rev-list -n 1 "$tag")
# get current commit hash
commit=$(git rev-parse HEAD)

# skip if there are no new commits
if [ "$tag_commit" == "$commit" ]
then
    echo "No new commits since previous tag. Skipping..."
    setOutput "new_tag" "$tag"
    setOutput "tag" "$tag"
    exit 0
fi


# get the merge commit message looking for #bumps
declare -A history_type=( 
    ["last"]="$(git show -s --format=%B)" \
    ["full"]="$(git log "${default_branch}"..HEAD --format=%B)" \
    ["compare"]="$(git log "${tag_commit}".."${commit}" --format=%B)" \
)
log=${history_type[${branch_history}]}
printf "History:\n---\n%s\n---\n" "$log"

case "$log" in
    *$major_string_token* ) new=$(semver -i major "$tag"); part="major";;
    *$minor_string_token* ) new=$(semver -i minor "$tag"); part="minor";;
    *$patch_string_token* ) new=$(semver -i patch "$tag"); part="patch";;
    *$none_string_token* ) 
        echo "Default bump was set to none. Skipping..."
        setOutput "old_tag" "$tag"
        setOutput "new_tag" "$tag"
        setOutput "tag" "$tag"
        setOutput "part" "$default_semvar_bump"
        exit 0;;
    * ) 
        if [ "$default_semvar_bump" == "none" ]
        then
            echo "Default bump was set to none. Skipping..."
            setOutput "old_tag" "$tag"
            setOutput "new_tag" "$tag"
            setOutput "tag" "$tag"
            setOutput "part" "$default_semvar_bump"
            exit 0 
        else 
            new=$(semver -i "${default_semvar_bump}" "$tag")
            part=$default_semvar_bump 
        fi 
        ;;
esac

if $with_v
then
    new="v$new"
fi
    echo -e "Bumping tag ${tag} - New tag ${new}"


# set outputs
setOutput "new_tag" "$new"
setOutput "part" "$part"
setOutput "tag" "$new" 
setOutput "old_tag" "$tag"



# create local git tag
git tag "$new"

# push new tag ref to github
repo_name=$GITHUB_REPOSITORY
git_refs_url=$(jq .repository.git_refs_url "$GITHUB_EVENT_PATH" | tr -d '"' | sed 's/{\/sha}//g')

echo "*** pushing tag $new to repo $repo_name ***"

# git_tag_ref=$(git show-ref --tags | cut -d ' ' -f 2- | sort -r | head -n 1)


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

if [ "${git_ref_posted}" = "refs/tags/${new}" ]
# if [ "${git_tag_ref}" = "refs/tags/${new}" ]
then
    exit 0
else
    echo "::error::Tag was not created properly."
    exit 1
fi
