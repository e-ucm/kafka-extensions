#!/usr/bin/env bash
set -eo pipefail
[[ "${DEBUG}" == "true" ]] && set -x

: ${BUILD_VERSION:=1.0.0}

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

function usage ()
{
    echo 1>&2 "Usage: ${SOURCE} [Options]"
    echo 1>&2 "Build all keycloak extensions in this repository (${BUILD_VERSION})."
    echo 1>&2 "Options:"
    echo 1>&2 "  -h, --help"
    echo 1>&2 "      Shows this help message and exits."
    echo 1>&2 "  -b, --build <build version>"
    echo 1>&2 "      Build version to compile the extension."
}

LIST_LONG_OPTIONS=(
  "help"
  "build:"
)
LIST_SHORT_OPTIONS=(
  "h"
  "b:"
)

opts=$(getopt \
    --longoptions "$(printf "%s," "${LIST_LONG_OPTIONS[@]}")" \
    --options "$(printf "%s", "${LIST_SHORT_OPTIONS[@]}")" \
    --name "${SOURCE}" \
    -- "$@"
)

eval set -- $opts

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b | --build )
        BUILD_VERSION="$2"
        shift 2
        ;;
    --)
      shift
      break
      ;;
    *)
      usage
      exit 1
      ;;
    esac
done

if [[ -d "$SCRIPT_DIR/builds-$BUILD_VERSION" ]]; then 
  rm -rf "$SCRIPT_DIR/builds-$BUILD_VERSION"
fi
mkdir "$SCRIPT_DIR/builds-$BUILD_VERSION"

#!/bin/bash


projects=("simva-kafka-connect-json-partitioner" "simva-kafka-connect-json-format")

for i in "${!projects[@]}"; do
    project=${projects[$i]};
    kafka_version="7.8.0"
    $SCRIPT_DIR/build.sh --kafka $kafka_version --kafka-storage-partitioner 11.0.2 --kafka-api 3.9.0 --kafka-s3 10.2.16 "$SCRIPT_DIR/../$project"
    cp $SCRIPT_DIR/../${project}/target/es.e-ucm.simva.kafka.$project-$BUILD_VERSION.jar $SCRIPT_DIR/builds-$BUILD_VERSION/es.e-ucm.simva.kafka.$project-kafka${kafka_version%%.*}-$BUILD_VERSION.jar
done

projects=("simva-kafka-connect-json-partitioner")

for i in "${!projects[@]}"; do
    project=${projects[$i]};
    kafka_version="5.5.0"
    $SCRIPT_DIR/build.sh --kafka $kafka_version --kafka-storage-partitioner $kafka_version --kafka-api 3.9.0 --kafka-s3 $kafka_version "$SCRIPT_DIR/../$project"
    cp $SCRIPT_DIR/../${project}/target/es.e-ucm.simva.kafka.$project-$BUILD_VERSION.jar $SCRIPT_DIR/builds-$BUILD_VERSION/es.e-ucm.simva.kafka.$project-kafka${kafka_version%%.*}-$BUILD_VERSION.jar
done

pushd "$SCRIPT_DIR/builds-$BUILD_VERSION"
sha256sum ./* > "$SCRIPT_DIR/builds-$BUILD_VERSION/SHA256SUMS"
popd