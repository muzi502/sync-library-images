#!/bin/bash
set -eo pipefail

GREEN_COL="\\033[32;1m"
RED_COL="\\033[1;31m"
YELLOW_COL="\\033[33;1m"
NORMAL_COL="\\033[0;39m"

REGISTRY_DOMAIN=$1
: ${REGISTRY_DOMAIN:="registry.local"}
REGISTRY_LIBRARY="${REGISTRY_DOMAIN}/library"
REPO_PATH=$2
: ${REPO_PATH:=${PWD}}

NEW_TAG=$(date +"%Y%m%d%H%M")
TMP_DIR="/tmp/docker-library"
UPSTREAM="https://github.com/docker-library/official-images"

SKIPE_IMAGES="windowsservercore"

cd ${REPO_PATH}
mkdir -p ${TMP_DIR}

diff_images() {
    git remote remove upstream &> /dev/null || true
    git remote add upstream ${UPSTREAM}
    git fetch --tag
    git fetch --all
    CURRENT_COMMIT=$(git log -1 upstream/master --format='%H')
    LAST_TAG=$(git tag -l | egrep --only-matching -E '^([[:digit:]]{12})' | sort -nr | head -n1)
    : ${LAST_TAG:=$(git log upstream/master --format='%H' | tail -n1)}
    IMAGES=$(git diff --name-only --ignore-space-at-eol --ignore-space-change \
    --diff-filter=AM ${LAST_TAG} ${CURRENT_COMMIT} library | xargs -L1 -I {} sed "s|^|{}:|g" {} \
    | sed -n "s| ||g;s|library/||g;s|:Tags:|:|p;s|:SharedTags:|:|p" | sort -u | sed "/${SKIPE_IMAGES}/d")
}

skopeo_copy() {
    let CURRENT_NUM=1+${CURRENT_NUM}
    echo -e "$YELLOW_COL Progress: ${CURRENT_NUM}/${TOTAL_NUMS} $NORMAL_COL"
    if skopeo copy --insecure-policy --src-tls-verify=false --dest-tls-verify=false -q docker://$1 docker://$2; then
        echo -e "$GREEN_COL Sync $1 successful $NORMAL_COL"
        echo ${name}:${tags} >> ${TMP_DIR}/${NEW_TAG}-successful.list
        return 0
    else
        echo -e "$RED_COL Sync $1 failed $NORMAL_CO"
        echo ${name}:${tags} >> ${TMP_DIR}/${NEW_TAG}-failed.list
        return 1
    fi
}

sync_images() {
    if [ -s images.list ]; then
        IMAGES=$(echo ${IMAGES} | grep -E $(cat images.list | tr '\n' '|' | sed 's/|$//'));
    fi
    IFS=$'\n'
    CURRENT_NUM=0
    TOTAL_NUMS=$(echo ${IMAGES} | tr ',' ' ' | wc -w)
    for image in ${IMAGES}; do
        name="$(echo ${image} | cut -d ':' -f1)"
        tags="$(echo ${image} | cut -d ':' -f2 | cut -d ',' -f1)"

        if skopeo_copy docker.io/${name}:${tags} ${REGISTRY_LIBRARY}/${name}:${tags}; then
            for tag in $(echo ${image} | cut -d ':' -f2 | tr ',' '\n'); do
                skopeo_copy ${REGISTRY_LIBRARY}/${name}:${tags} ${REGISTRY_LIBRARY}${name}:${tag}
            done
        fi
    done
    unset IFS
}

gen_repo_tag() {
    if git rebase upstream/master; then
        git tag ${NEW_TAG} --force
        git push origin sync --force
        git push origin --tag --force
    fi
}

diff_images
sync_images
gen_repo_tag
