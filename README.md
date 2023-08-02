### action.yaml

This is a YAML file for a GitHub action called "Github Tag" that creates a tag for a repository. The action is authored by "Custom Github Action" and runs using Docker. It has three outputs: "new_tag", which is the generated tag; "tag", which is the latest tag after running the action; and "part", which is the part of the version that was bumped. The action also includes branding information, with an icon of a git-merge and a color of purple.

It is created to be integrated into a GitHub workflow, allowing developers to automatically tag their code when certain conditions are met. Overall, this action provides a way to manage versions and releases of a software project and can help streamline the development process.

### Dockerfile

This is a Dockerfile that sets up an environment for a GitHub action called "Github Tag". The Docker image is based on the Node.js 16 Alpine image. The Dockerfile contains several LABELs that provide metadata for the image, including the repository URL, homepage URL, and maintainer information.

The Dockerfile also installs several dependencies needed for the action to run, including bash, git, curl, jq, and the semver Node.js package. Finally, the Dockerfile copies an entrypoint script called "entrypoint.sh" into the image, which will be executed when the Docker container starts. The entrypoint script is responsible for running the action's logic, which presumably involves creating a tag for a GitHub repository.

### entrypoint.sh

This script is a bash script used to manage version tagging on GitHub. The script can be used to determine the next version to tag based on the type of changes in the codebase, such as whether they are major, minor or patch changes, and then tag the release with the appropriate version number.

The script accepts a variety of configuration options, such as the default branch to use, whether to include a "v" prefix in the tag, whether the initial version number to use if no tags have been created yet.

The script uses git commands to determine the latest tag and commit hash, and then checks if there are any new commits since the last tag. If there are new commits, it uses the configuration options to determine the next version number to use, creates a new tag, and pushes it to the repository.


### Custom Tag Github Action

This custom GitHub action that automates versioning and tagging. It requires a GITHUB_TOKEN environment variable and provides several optional environment variables for customization. The action will bump the version number in the latest tag with either a minor bump or a custom bump specified by a commit message containing #major or #patch. It then pushes the new tag to GitHub. If triggered on the default branch, it creates a release tag. If triggered on any other branch, it creates a prerelease tag with a suffix and number. The action also provides outputs for the new tag, the latest tag, and the part of the version that was bumped.

This action can save time and effort in managing versioning and tagging for GitHub repositories. It offers customization options for different workflows and can be easily integrated into a repo by adding it as an action. It provides automatic version bumping and tagging, freeing developers from having to manually perform these tasks. The outputs can be used in subsequent steps of a workflow to further automate the development process. Overall, this action can help streamline versioning and tagging for GitHub repos and make the development process more efficient.

## Bump
"Bump" refers to incrementing the version number of a software project. The action automatically determines the appropriate type of bump (major, minor, or patch) based on the commit messages in the latest changes.