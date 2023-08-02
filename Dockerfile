FROM node:16-alpine
LABEL "repository"="https://github.com/sanketl-talentica/github-actions-tag"
LABEL "homepage"="https://github.com/sanketl-talentica/github-actions-tag"
LABEL "maintainer"="Custom Github Action"

RUN apk --no-cache add bash git curl jq && npm install -g semver

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["bash", "/entrypoint.sh"]
