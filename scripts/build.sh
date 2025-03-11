#!/usr/bin/env bash
set -eo pipefail
[[ "${DEBUG}" == "true" ]] && set -x

: ${MAVEN_BUILDER_IMAGE:=maven:3.6.3-jdk-8-slim} #maven:3.9.9-eclipse-temurin-17
: ${KAFKA_VERSION:=7.8.0}
: ${KAFKA_SP_VERSION:=11.2.16}
: ${KAFKA_API_VERSION:=3.9.0}
: ${KAFKA_S3_VERSION:=10.2.16}

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

function usage ()
{
    echo 1>&2 "Usage: ${SOURCE} [Options] [<extension path>]"
    echo 1>&2 "Build keycloak (${KEYCLOAK_VERSION}) extension."
    echo 1>&2 "Options:"
    echo 1>&2 "  -h, --help"
    echo 1>&2 "      Shows this help message and exits."
    echo 1>&2 "  -c, --cache <cache path>"
    echo 1>&2 "      Folder were maven cache is stored (useful to reuse between executions)."
    echo 1>&2 "  -k, --kafka <kafka version>"
    echo 1>&2 "      Kafka version to compile the extension."
    echo 1>&2 "  -sp, --kafka-storage-partitioner <kafka SP version>"
    echo 1>&2 "      connect-storage-partitioner version to compile the extension."
    echo 1>&2 "  -api, --kafka-api <kafka API version>"
    echo 1>&2 "      connect-api version to compile the extension."
    echo 1>&2 "  -s3, --kafka-s3 <kafka S3 version>"
    echo 1>&2 "      connect-s3 version to compile the extension."
}


LIST_LONG_OPTIONS=(
  "help"
  "cache:"
  "kafka:"
  "kafka-storage-partitioner:"
  "kafka-api:"
  "kafka-s3:"
)
LIST_SHORT_OPTIONS=(
  "h"
  "c:"
  "k:"
  "sp:"
  "api:"
  "s3:"

)

opts=$(getopt \
    --longoptions "$(printf "%s," "${LIST_LONG_OPTIONS[@]}")" \
    --options "$(printf "%s", "${LIST_SHORT_OPTIONS[@]}")" \
    --name "${SOURCE}" \
    -- "$@"
)

eval set -- $opts

extension=""
m2_cache="$(dirname "${SCRIPT_DIR}")/data"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c | --cache )
        m2_cache=$(realpath "$2")
        shift 2
        ;;
    -k | --kafka )
        KAFKA_VERSION="$2"
        shift 2
        ;;
    -sp | --kafka-storage-partitioner )
        KAFKA_SP_VERSION="$2"
        shift 2
        ;;
    -api | --kafka-api )
        KAFKA_API_VERSION="$2"
        shift 2
        ;;
    -s3 | --kafka-s3 )
        KAFKA_S3_VERSION="$2"
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

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

extension=$(realpath "$1")

if [[ ! -d "${m2_cache}" ]]; then
    mkdir -p "${m2_cache}"
fi

mvn_cmd="mvn -Duser.home=/maven-config -Dkafka.connect.version=${KAFKA_VERSION} -Dkafka.connect-storage-partitioner.version=${KAFKA_SP_VERSION} -Dkafka.connect-api.version=${KAFKA_API_VERSION} -Dkafka.connect-s3.version=${KAFKA_S3_VERSION} clean package"
user_uid=$(id -u ${USER})
user_gid=$(id -g ${USER})

docker run --rm --name maven-project-builder \
    -v ${extension}:/usr/src/mymaven \
    -v ${m2_cache}:/maven-config \
    -u ${user_uid}:${user_gid} \
    -w /usr/src/mymaven \
    -e MAVEN_CONFIG=/maven-config/.m2 \
    ${MAVEN_BUILDER_IMAGE} ${mvn_cmd}