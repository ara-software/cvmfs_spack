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


# the final real path where we want files to be installed
# INSTALL_DIR="/cvmfs/rnog.opensciencegrid.org/software"
INSTALL_DIR="/scratch/brianclark/ara_cvmfs_demo"

# a scratch directory where spack can put intermediate build files
SCRATCH_DIR="/scratch/brianclark/ara_scratch"
mkdir -p $SCRATCH_DIR

# the temporary spot where we are going to build and actually write files
# BUILD_DIR="/tmp/rnog_build"
BUILD_DIR="/scratch/brianclark/ara_build"
mkdir -p $BUILD_DIR

BUILD_SCRIPT="./build.sh"

# in cvmfs, we bind BUILD_DIR to INSTALL_DIR
# so that we can temporarily write to BUILD_DIR,
# but the install scripts *think* they are writing to INSTALL_DIR
# so that we can rsync them to their final destination at the end
# and everything looks alright

echo "[+] Building $VERSION for $OS using image: $IMAGE"
apptainer exec \
    -B "$SCRATCH_DIR":/tmp\
    -B "$BUILD_DIR":"$INSTALL_DIR" \
    -B /var:/var \
    -B "$PWD":"$PWD" \
    "$IMAGE" \
    "$BUILD_SCRIPT" "$VERSION" "$OS" "$INSTALL_DIR"
