#!/bin/bash
set -e
cd `dirname $0`
##################### CONFIG ZONE ##########################

LOCAL_REGISTRY="registry.example.com/trivy"
PUSH_TO_LOCAL_REGISTRY="no"

TRIVYDBV2="ghcr.io/aquasecurity/trivy-db:2"
TRIVYJAVADBV1="ghcr.io/aquasecurity/trivy-java-db:1"

# how many days the old db will store
KEEP_OLD_DAY="3"
####################### LOG ZONE ############################
LOGTAG="MAIN"
IS_RUN_BACKGROUD="no"
case $(ps -o stat= -p $$) in
  *+*) IS_RUN_BACKGROUD="no" ;;
  *) IS_RUN_BACKGROUD="yes" ;;
esac

function show_msg() {
  CURTIME=$(date "+%Y-%m-%d %H:%M:%S")
  if [ ${IS_RUN_BACKGROUD} == "yes" ] ; then
    echo "[${CURTIME}][${LOGTAG}] $1"
  else
    echo -e "\033[1;32m[${CURTIME}][${LOGTAG}] $1\033[0m"
  fi
}
show_msg "IS_RUN_BACKGROUD: ${IS_RUN_BACKGROUD}"

################################################################

function update_trivy() {
  LOGTAG="Trivy"
  URL_PREFIX="https://github.com/aquasecurity/trivy/releases"
  LOCATION="Location: ${URL_PREFIX}/tag/"

  NEW_VERSION=$(curl -sI ${URL_PREFIX}/latest | grep -i "${LOCATION}" | sed "s#${LOCATION}##" | tr -d '\r')
  show_msg "Trivy latest version is: [$NEW_VERSION]"
  if [ ! -d trivy/${NEW_VERSION} ] ; then
    show_msg "Downloading ${NEW_VERSION}..."
    mkdir -p  trivy/${NEW_VERSION}
    pushd trivy/${NEW_VERSION} >/dev/null
    wget -q ${URL_PREFIX}/download/${NEW_VERSION}/trivy_${NEW_VERSION:1}_Linux-64bit.rpm
    wget -q ${URL_PREFIX}/download/${NEW_VERSION}/trivy_${NEW_VERSION:1}_Linux-64bit.deb
    popd >/dev/null
    show_msg "Downloaded"
  else
   show_msg "Up to date."
  fi
}


###################################################################
## Get DB/metadata.json NextUpdate filed And Convert it to Epoch ##
## param1: DB path (trivydb or trivy-java-db)                    ##
###################################################################
function get_db_next_update_epoch() {
  NEXT_UPDATE_TIME=$(tar -O -xf $1 metadata.json | jq '.NextUpdate' | tr -d '"')
  NEXT_UPDATE_EPOCH=$(date -d "${NEXT_UPDATE_TIME} +0000" +%s)
  echo ${NEXT_UPDATE_EPOCH}
}

###################################################################
## Get DB/metadata.json UpdatedAt filed                          ##
## param1: DB path (trivydb or trivy-java-db)                    ##
###################################################################
function get_db_update_at() {
  UPDATE_AT=$(tar -O -xf $1 metadata.json | jq '.UpdatedAt' | tr -d '"')
  DATE_STRING=$(date -d "${UPDATE_AT} +0000" +%Y%m%d%H%M%S)
  echo ${DATE_STRING}
}

###################################################################
## Download and Push DB to Local Registry (trivydb/trivy-java-db)##
## param1: DB path (trivydb or trivy-java-db)                    ##
## param2: containter name(trivy-db:2 or trivy-java-db:1)        ##
###################################################################
function download_and_push_db() {

  if [ -f latest.tar.gz ] ; then
    CURRENT_EPOCH=$(date +%s)
    NEXT_UPDATE_EPOCH=$(get_db_next_update_epoch latest.tar.gz)
    if [ ${NEXT_UPDATE_EPOCH} -lt ${CURRENT_EPOCH} ] ; then
      show_msg "New Version Avaliable: ${NEXT_UPDATE_EPOCH}(`date -d@${NEXT_UPDATE_EPOCH}`)"
    else
      show_msg "Up to date"
      return
    fi
  else
    show_msg "First Update"
  fi

  oras pull $1
  MANIFEST=$(oras manifest fetch $1)
  FILENAME=$(echo  "${MANIFEST}" | jq '.layers[0].annotations."org.opencontainers.image.title"' | tr -d '"')
  MEDIATYPE=$(echo "${MANIFEST}" | jq '.layers[0].mediaType' | tr -d '"')
  show_msg "mediaType: ${MEDIATYPE}"
  DIGEST=$(echo    "${MANIFEST}" | jq '.layers[0].digest'    | tr -d '"')
  DIGEST_METHOD=${DIGEST%:*}
  DIGEST_VALUE=${DIGEST#*:}
  VERITY_VALUE=$(${DIGEST_METHOD}sum ${FILENAME} | awk '{print $1}' | tr -d '\r')
  if [ ${DIGEST_VALUE} == ${VERITY_VALUE} ] ; then
    show_msg "${DIGEST_METHOD} verity: SUCCESS"
  else
    show_msg "${DIGEST_METHOD} verity: FAIL"
    exit 127
  fi

  if [ ${PUSH_TO_LOCAL_REGISTRY} == "yes" ] ; then
    oras push --export-manifest manifest.json ${LOCAL_REGISTRY}/$2 ${FILENAME}
    jq ".layers[0].mediaType=\"${MEDIATYPE}\"" manifest.json > new_manifest.json
    oras manifest push ${LOCAL_REGISTRY}/$2 new_manifest.json
    rm -f manifest.json new_manifest.json
  fi
  
  NEWNAME=$(get_db_update_at ${FILENAME})
  mv ${FILENAME} ${NEWNAME}.tar.gz
  if [ -f latest.tar.gz ] ; then
    rm -f latest.tar.gz 
  fi
  ln -s ${NEWNAME}.tar.gz latest.tar.gz
  
  # delete old files
  find . -name '*.tar.gz' -mtime +${KEEP_OLD_DAY} -delete
}


function update_trivy_db() {
  LOGTAG="TrivyDB v2"
  STORE_DIR="trivy-db"
  
  mkdir -p ${STORE_DIR}
  pushd ${STORE_DIR} >/dev/null
  download_and_push_db ${TRIVYDBV2} trivy-db:2
  popd > /dev/null
}

function update_trivy_java_db() {
  LOGTAG="TrivyJavaDB"
  STORE_DIR="trivy-java-db"

  mkdir -p  ${STORE_DIR}
  pushd ${STORE_DIR} >/dev/null
  download_and_push_db ${TRIVYJAVADBV1} trivy-java-db:1
  popd > /dev/null
}

###################################################################


update_trivy

update_trivy_db

update_trivy_java_db

###################################################################

LOGTAG="MAIN"
show_msg "Done"
