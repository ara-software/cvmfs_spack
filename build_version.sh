#!/bin/bash
set -euo pipefail

# ==== ARGUMENTS ====
if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <os>"
    echo "Example: $0 trunk alma9"
    exit 1
fi

VERSION="$1"
OS="$2"
IMAGE="./${OS}.sif"
NPROC=40


# the final real path where we want files to be installed
# DESTDIR="/cvmfs/rnog.opensciencegrid.org/software"
DESTDIR="/scratch/brianclark/ara_cvmfs_demo/${VERSION}/${OS}"
mkdir -p $DESTDIR

# a scratch directory where spack can put intermediate build files
SCRATCH_DIR="/scratch/brianclark/ara_scratch/${VERSION}/${OS}"
mkdir -p $SCRATCH_DIR

# the temporary spot where we are going to build and actually write files
BUILD_DIR="/scratch/brianclark/ara_build/${VERSION}/${OS}"
mkdir -p $BUILD_DIR

BUILD_SCRIPT="./build.sh"
GIT_REPO_DIR="./"

# in cvmfs, we bind BUILD_DIR to DESTDIR
# so that we can temporarily write to BUILD_DIR,
# but the install scripts *think* they are writing to DESTDIR
# so that we can rsync them to their final destination at the end
# and everything looks alright

echo "[+] Building $VERSION for $OS using image: $IMAGE"
apptainer exec -c \
    -H $PWD \
    -B "$SCRATCH_DIR":/scratch\
    -B "$BUILD_DIR":"$DESTDIR" \
    -B "$SCRATCH_DIR":/var \
    -B "$PWD":"$PWD" \
    "$IMAGE" \
    "$BUILD_SCRIPT" "$GIT_REPO_DIR" "$VERSION" "$OS" "$DESTDIR" "$NPROC"
