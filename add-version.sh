#!/bin/bash -e

# Use this script to rebuild the Dockerfiles and all variants for a particular
# release. Before running this, you must first delete the existing release
# directory.
#
# TODO: to conform with other similar setups, this likely needs to become
# "update.sh" and be taught how to derive the latest version (e.g. 1.2.0) from
# a given release (e.g. 1.2) and assemble a .travis.yml file dynamically.
#
# See other repos (e.g. httpd, cassandra) for update.sh examples.

function usage() {
    echo >&2 "usage: $0 -r flink-release -f flink-version"
}

function error() {
    local msg="$1"
    if [ -n "$2" ]; then
        local code="$2"
    else
        local code=1
    fi
    echo >&2 "$msg"
    exit "$code"
}

flink_release= # Like 1.2
flink_version= # Like 1.2.0

while getopts r:f:h arg; do
  case "$arg" in
    r)
      flink_release=$OPTARG
      ;;
    f)
      flink_version=$OPTARG
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done

if [ -z "$flink_release" ] || [ -z "$flink_version" ]; then
    usage
    exit 1
fi

if [[ ! "$flink_version" =~ ^$flink_release\.+ ]]; then
    error "Flink release must be prefix of version"
fi

# Defaults, can vary between versions
source_variants=( debian )
scala_versions=( 2.11 2.12 )
gpg_key=

# Version-specific variants (example)
# if [ "$flink_release" = "x.y" ]; then
#     scala_versions=( 2.10 2.11 2.12 )
# fi

# No real need to cull old versions
if [ "$flink_version" = "1.8.0" ]; then
    gpg_key="F2A67A8047499BBB3908D17AA8F4FD97121D7293"
elif [ "$flink_version" = "1.8.1" ]; then
    gpg_key="8FEA1EE9D0048C0CCC70B7573211B0703B79EA0E"
elif [ "$flink_version" = "1.8.2" ]; then
    gpg_key="E2C45417BED5C104154F341085BACB5AEFAE3202"
elif [ "$flink_version" = "1.9.0" ]; then
    gpg_key="1C1E2394D3194E1944613488F320986D35C33D6A"
elif [ "$flink_version" = "1.9.1" ]; then
    gpg_key="E2C45417BED5C104154F341085BACB5AEFAE3202"
else
    error "Missing GPG key ID for this release"
fi

if [ -d "$flink_release" ]; then
    error "Directory $flink_release already exists; delete before continuing"
fi

mkdir "$flink_release"

echo -n >&2 "Generating Dockerfiles..."
for source_variant in "${source_variants[@]}"; do
    for scala_version in "${scala_versions[@]}"; do
        dir="$flink_release/scala_${scala_version}-${source_variant}"

        mkdir "$dir"
        cp docker-entrypoint.sh "$dir/docker-entrypoint.sh"

        sed \
            -e "s/%%FLINK_VERSION%%/$flink_version/" \
            -e "s/%%SCALA_VERSION%%/$scala_version/" \
            -e "s/%%GPG_KEY%%/$gpg_key/" \
            "Dockerfile-$source_variant.template" > "$dir/Dockerfile"
    done
done
echo >&2 " done."
