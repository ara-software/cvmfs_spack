#!/bin/bash
set -euo pipefail

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


# in cvmfs, we bind BUILD_DIR to INSTALL_DIR
# so that we can temporarily write to BUILD_DIR,
# but the install scripts *think* they are writing to INSTALL_DIR
# so that we can rsync them to their final destination at the end
# and everything looks alright

BUILD_SCRIPT="./build.sh"
OS_TAGS=("el9")

for OS in "${OS_TAGS[@]}"; do
    IMAGE="./osg_${OS}.sif"

    echo "[+] Building for $OS using image: $IMAGE"
    apptainer exec \
        -B "$SCRATCH_DIR":/tmp\
        -B "$BUILD_DIR":"$INSTALL_DIR" \
        -B /var:/var \
        -B "$PWD":"$PWD" \
        "$IMAGE" \
        "$BUILD_SCRIPT" "$OS" "$INSTALL_DIR"
done
