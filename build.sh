#!/bin/bash
set -euo pipefail

# ==== ARGUMENTS ====
if [ $# -ne 5 ]; then
    echo "Usage: $0 <git_repo_dir> <version> <os_tag> <topdir> <nproc>"
    echo "Example: $0 /path/to/cvmfs_spack trunk el9 /cvmfs/ara.opensciencegrid.org/trunk/el9 8"
    exit 1
fi

GIT_REPO_DIR="$1"
VERSION="$2"
OS_TAG="$3"
DESTDIR="$4"
NPROC="$5"
SPACK_VERSION="v1.0.0"

# ==== CONFIGURATION STUFF ====

# NB: for spack, MISC_DIR is the *view* directory
# That is: where we want it to put the *view* on the dependencies
MISC_DIR="${DESTDIR}/misc_build" 
ARA_BUILD_DIR="${DESTDIR}/ara_build"
SOURCE_DIR="${DESTDIR}/source"

# where spack should go
# and a name for the spack environment
# and tell spack how to find the yaml file
# and set up some temporary files for spack, to contain its cache blast radius
YAML_SOURCE="${GIT_REPO_DIR}/builders/${VERSION}/${VERSION}.yaml"
SPACK_DIR="${DESTDIR}/.spack_internals/spack_${VERSION}_${OS_TAG}_${SPACK_VERSION}"
ENV_NAME="${VERSION}_${OS_TAG}"
SPACK_USER_CONFIG="/scratch/spack_user_config_${VERSION}_${OS_TAG}_${SPACK_VERSION}"
SPACK_USER_CACHE="/scratch/spack_user_cache_${VERSION}_${OS_TAG}_${SPACK_VERSION}"
SPACK_TMPDIR="/scratch/spack_tmpdir_${VERSION}_${OS_TAG}_${SPACK_VERSION}"

# number of processors, and the make arguments for ARA custom scripts
export MAKE_ARGS="--make_arg -j$NPROC"

# log everything to screen
echo "=============================================="
echo "=============================================="
echo "=============================================="
echo "[+] Using OS tag:            $OS_TAG"
echo "[+] Using version:           $VERSION"
echo "[+] Git GIT_REPO_DIR:        $GIT_REPO_DIR"
echo "[+] Using DESTDIR:           $DESTDIR"
echo "[+] Using MISC_DIR:          $MISC_DIR"
echo "[+] Using ARA_BUILD_DIR:     $ARA_BUILD_DIR"
echo "[+] Using SOURCE_DIR:        $SOURCE_DIR"
echo "[+] Using SPACK_DIR:         $SPACK_DIR"
echo "[+] Using USER CONFIG:       $SPACK_USER_CONFIG"
echo "[+] Using USER CACHE:        $SPACK_USER_CACHE"
echo "[+] Using SPACK_TMPDIR:      $SPACK_TMPDIR"
echo "[+] Build with NPROC         $NPROC"
echo "=============================================="
echo "=============================================="
echo "=============================================="
echo # just clear the queue
echo
echo

# ==== STEP 1: Clone Spack if Needed ====
if [ ! -d "$SPACK_DIR" ]; then
    echo "[+] Cloning Spack into $SPACK_DIR..."
    mkdir -p "$(dirname "$SPACK_DIR")"
	  git clone --depth=1 --branch "$SPACK_VERSION" https://github.com/spack/spack.git "$SPACK_DIR"
fi
# Set paths, and set up directories, BEFORE sourcing Spack
# the "before spack" is extra important because if we don't set the config and caches
# before sourcing spack, they don't get set right
export SPACK_USER_CONFIG_PATH="$SPACK_USER_CONFIG"
export SPACK_USER_CACHE_PATH="$SPACK_USER_CACHE"
export SPACK_TMPDIR="$SPACK_TMPDIR"
export TMPDIR="$SPACK_TMPDIR"
mkdir -p "$SPACK_USER_CONFIG"
mkdir -p "$SPACK_USER_CACHE"
mkdir -p "$SPACK_TMPDIR"
mkdir -p "$SOURCE_DIR"
mkdir -p "$ARA_BUILD_DIR"
mkdir -p "$MISC_DIR"
source "$SPACK_DIR/share/spack/setup-env.sh"

# ==== STEP 2: Upgrade GCC ====
spack compiler add # find the compilers we have so far
spack compilers
BOOTSTRAP_COMPILER=$(spack compilers | grep "gcc@" | head -1 | grep -o 'gcc@[0-9.]*')
echo "[+] Will use $BOOTSTRAP_COMPILER to bootstrap gcc@15.2.0"
if ! spack compilers | grep -q gcc@15.2.0; then
    # install the compiler we want, and force rebuild binutils
    # along with telling it to ignore any fancy optimizations
    # that might not be available globally
    echo "[+] Bootstrapping gcc@15.2.0..."
    spack install --add -j "$NPROC" "gcc@15.2.0 %${BOOTSTRAP_COMPILER} +binutils ^zlib-ng~opt"
    spack compiler find $(spack location -i gcc@15.2.0)
fi
spack compilers

# ==== STEP 3: Create Environment (with view), and activate ====
echo "[+] Creating and activating Spack environment..."
if [ ! -d "$SPACK_ROOT/var/spack/environments/$ENV_NAME" ]; then
    spack env create "$ENV_NAME" "$YAML_SOURCE" --with-view "$MISC_DIR"
fi
spack env activate "$ENV_NAME"

# ==== STEP 4: Concretize and Install Full Stack ====
echo "[+] Starting concretization..."
spack concretize --fresh --reuse
echo "[+] Concretization finished. Starting installation..."
spack install -j "$NPROC"

# build healpix now, before we pip install healpy (healpix will bring in libsharp)
${GIT_REPO_DIR}/builders/${VERSION}/build_healpix.sh --source "$SOURCE_DIR" --build "$ARA_BUILD_DIR" --root "$MISC_DIR" --deps "$MISC_DIR" $MAKE_ARGS || error 104 "Failed healpix build"


# ==== STEP 5: Install Python Needs ====
export PIP_CACHE_DIR=$SPACK_USER_CACHE_PATH # set pip cache (again, contain the blast radius...)
# need these to make sure pip installs healpy correctly by building it against
# our copy of cfitsio
export LDFLAGS="-L$MISC_DIR/lib -Wl,-rpath,$MISC_DIR/lib"
export CPPFLAGS="-I$MISC_DIR/include"
export PKG_CONFIG_PATH="$MISC_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
python3 -m pip install --upgrade pip
pip3 install gnureadline healpy \
    iminuit tqdm matplotlib numpy pandas pynverse astropy \
    scipy uproot awkward libconf \
    tinydb tinydb-serialization aenum pymongo dash plotly \
    toml peakutils configparser filelock pre-commit

# ==== STEP 6: Now we need some ARA specific stuff ====

ROOT_COMPILER=$(spack find --format '{compiler}' root | head -1)
echo "ROOT was built with: $ROOT_COMPILER"
spack load $ROOT_COMPILER

# Manually add GCC's library path since spack load didn't do it
GCC_PREFIX=$(spack location -i $ROOT_COMPILER)
export LD_LIBRARY_PATH="$GCC_PREFIX/lib64:$GCC_PREFIX/lib:$LD_LIBRARY_PATH"

echo "LD_LIBRARY_PATH after fix: $LD_LIBRARY_PATH"
echo "PATH: $PATH"

${GIT_REPO_DIR}/builders/${VERSION}/build_libRootFftwWrapper.sh --source "$SOURCE_DIR" --build "$ARA_BUILD_DIR" --root "$MISC_DIR" --deps "$MISC_DIR" $MAKE_ARGS || error 108 "Failed libRootFftwWrapper build"
${GIT_REPO_DIR}/builders/${VERSION}/build_AraRoot.sh --source "$SOURCE_DIR" --build "$ARA_BUILD_DIR" --root "$MISC_DIR" --deps "$MISC_DIR" || error 109 "Failed AraRoot build"
${GIT_REPO_DIR}/builders/${VERSION}/build_AraSim.sh --source "$SOURCE_DIR" --build "$ARA_BUILD_DIR" --root "$MISC_DIR" --deps "$MISC_DIR" $MAKE_ARGS || error 110 "Failed AraSim build"
${GIT_REPO_DIR}/builders/${VERSION}/build_libnuphase.sh --source "$SOURCE_DIR" --build "$ARA_BUILD_DIR" --root "$MISC_DIR" --deps "$MISC_DIR" || error 111 "Failed libnuphase build"
${GIT_REPO_DIR}/builders/${VERSION}/build_nuphaseroot.sh --source "$SOURCE_DIR" --build "$ARA_BUILD_DIR" --root "$MISC_DIR" --deps "$MISC_DIR" || error 112 "Failed nuphaseroot build"

# ==== STEP 6: Create Setup Script ====

cat > ${DESTDIR}/setup.sh << 'EOF'
#!/bin/sh
# Setup script for trunk version of the ARA software

export ARA_SETUP_DIR="PATH_PLACEHOLDER_REPLACE_ME"
# If the fake path in ARA_SETUP_DIR wasn't replaced, try the working directory
if [ ! -d "$ARA_SETUP_DIR" ]; then
	export ARA_SETUP_DIR=$(pwd)
fi

export ARA_UTIL_INSTALL_DIR="${ARA_SETUP_DIR%/}/ara_build"
export ARA_DEPS_INSTALL_DIR="${ARA_SETUP_DIR%/}/misc_build"
export ARA_ROOT_DIR="${ARA_SETUP_DIR%/}/source/AraRoot"
export ARA_ROOT_LIB_DIR="${ARA_UTIL_INSTALL_DIR%/}/lib"
export ARA_SIM_DIR="${ARA_SETUP_DIR%/}/source/AraSim"
export ARA_SIM_LIB_DIR="${ARA_UTIL_INSTALL_DIR%/}/lib"
export NUPHASE_INSTALL_DIR="$ARA_UTIL_INSTALL_DIR"

# Executables and library stuff that we compiled
export PATH="$ARA_UTIL_INSTALL_DIR/bin:$ARA_DEPS_INSTALL_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$ARA_UTIL_INSTALL_DIR/lib:$ARA_UTIL_INSTALL_DIR/lib/root:$ARA_DEPS_INSTALL_DIR/lib:$LD_LIBRARY_PATH"
export DYLD_LIBRARY_PATH="$ARA_UTIL_INSTALL_DIR/lib:$ARA_DEPS_INSTALL_DIR/lib:$DYLD_LIBRARY_PATH"

# detect and set python (Find the python3.* site-packages directory)
SITE_PACKAGES=$(find "${ARA_DEPS_INSTALL_DIR}/lib" -maxdepth 1 -type d -name 'python3.*' -print -quit 2>/dev/null)
if [ -n "$SITE_PACKAGES" ] && [ -d "${SITE_PACKAGES}/site-packages" ]; then
    export PYTHONPATH="${SITE_PACKAGES}/site-packages${PYTHONPATH:+:$PYTHONPATH}"
else
    echo "Warning: Could not find Python site-packages directory in ${ARA_DEPS_INSTALL_DIR}/lib" >&2
fi

# Do stuff that would have been done in what thisroot.sh would add, but via the view)
export ROOTSYS="$ARA_DEPS_INSTALL_DIR"
export PYTHONPATH="$ARA_DEPS_INSTALL_DIR/lib/python$PYVER/site-packages${PYTHONPATH:+:$PYTHONPATH}"
for d in "$ARA_DEPS_INSTALL_DIR/lib/root" "$ARA_DEPS_INSTALL_DIR/lib64/root"; do
  if [ -d "$d" ]; then
    case ":$PYTHONPATH:" in
      *:"$d":*) : ;;  # already present
      *) export PYTHONPATH="$d${PYTHONPATH:+:$PYTHONPATH}";;
    esac
  fi
done

# exports for CMake
export CMAKE_PREFIX_PATH="$ARA_DEPS_INSTALL_DIR"
export CC="$ARA_DEPS_INSTALL_DIR/bin/gcc"
export CXX="$ARA_DEPS_INSTALL_DIR/bin/g++"
export FC="$ARA_DEPS_INSTALL_DIR/bin/gfortran"

# exports for stuff besides CMake
export SQLITE_ROOT="$ARA_DEPS_INSTALL_DIR"
export GSL_ROOT="$ARA_DEPS_INSTALL_DIR"
export GSLDIR="$ARA_DEPS_INSTALL_DIR"
export FFTWSYS="$ARA_DEPS_INSTALL_DIR"
export BOOST_ROOT="$ARA_DEPS_INSTALL_DIR/include"

EOF

# Now replace the placeholder with the actual value
sed -i "s|PATH_PLACEHOLDER_REPLACE_ME|$DESTDIR|g" ${DESTDIR}/setup.sh
