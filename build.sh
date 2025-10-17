#!/bin/bash
set -euo pipefail

# ==== ARGUMENTS ====
if [ $# -ne 3 ]; then
    echo "Usage: $0 <version> <os_tag> <topdir>"
    echo "Example: $0 trunk el9 /cvmfs/myorg/software"
    exit 1
fi

VERSION="$1"
OS_TAG="$2"
TOPDIR="$3"
SPACK_VERSION="v1.0.0"

# ==== CONFIGURATION STUFF ====

# where spack should go
# and a name for the spack environment
# and tell spack how to find the yaml file
# and set up some temporary files for spack, to contain its cache blast radius
SPACK_DIR="${TOPDIR}/${VERSION}/.spack_internals/spack_${VERSION}_${OS_TAG}_${SPACK_VERSION}"
ENV_NAME="${VERSION}_${OS_TAG}"
YAML_SOURCE="./versions/${VERSION}/${VERSION}.yaml"
SPACK_USER_CONFIG="/tmp/spack_user_config_${VERSION}_${OS_TAG}_${SPACK_VERSION}"
SPACK_USER_CACHE="/tmp/spack_user_cache_${VERSION}_${OS_TAG}_${SPACK_VERSION}"

# what will become "misc_build" (for spack, this is the *view* directory)
VIEWDIR="${TOPDIR}/${VERSION}/${OS_TAG}/misc_build"

# what will become the "source"
SOURCEDIR="${TOPDIR}/${VERSION}/${OS_TAG}/source"

# number of processors, and the make arguments for ARA custom scripts
NPROC=32
export MAKE_ARGS="--make_arg -j$NPROC"

# log everything to screen so we can see it
echo "[+] Using OS tag:        $OS_TAG"
echo "[+] Using TOPDIR:        $TOPDIR"
echo "[+] Using VIEWDIR:       $VIEWDIR"
echo "[+] Using SOURCEDIR:     $SOURCEDIR"
echo "[+] Using SPACK DIR:     $SPACK_DIR"
echo "[+] Using USER CONFIG:   $SPACK_USER_CONFIG"
echo "[+] Using USER CACHE:    $SPACK_USER_CACHE"
echo "[+] Build with NPROC=    $NPROC"

# ==== STEP 1: Clone Spack if Needed ====
if [ ! -d "$SPACK_DIR" ]; then
    echo "[+] Cloning Spack into $SPACK_DIR..."
    mkdir -p "$(dirname "$SPACK_DIR")"
	  git clone --depth=1 --branch "$SPACK_VERSION" https://github.com/spack/spack.git "$SPACK_DIR"
fi
# Set paths BEFORE sourcing Spack
export SPACK_USER_CONFIG_PATH="$SPACK_USER_CONFIG"
export SPACK_USER_CACHE_PATH="$SPACK_USER_CACHE"
mkdir -p "$SPACK_USER_CONFIG"
mkdir -p "$SPACK_USER_CACHE"
mkdir -p "$SOURCEDIR"
mkdir -p "$VIEWDIR"
source "$SPACK_DIR/share/spack/setup-env.sh"

# ==== STEP 2: Upgrade GCC first ====
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
spack env create "$ENV_NAME" "$YAML_SOURCE" --with-view "$VIEWDIR"
spack env activate "$ENV_NAME"

# ==== STEP 4: Concretize and Install Full Stack ====
echo "[+] Starting concretization..."
spack concretize --fresh --reuse
echo "[+] Concretization finished. Starting installation..."
spack install -j "$NPROC"

# ==== STEP 5: Install Python Needs ====
echo "[+] Installing final pip packages..."
python3 -m pip install --upgrade pip
pip3 install gnureadline healpy \
    iminuit tqdm matplotlib numpy pandas pynverse astropy \
    scipy uproot awkward libconf \
    tinydb tinydb-serialization aenum pymongo dash plotly \
    toml peakutils configparser filelock pre-commit

# # # ==== STEP 6: Now we need some ARA specific stuff ====

# # # which cmake
# # ./versions/${VERSION}/build_libRootFftwWrapper.sh --source "$OTHER_SCRATCH_SPACE" --build "$VIEWDIR" --root "$VIEWDIR" --deps "$VIEWDIR" $MAKE_ARGS || error 108 "Failed libRootFftwWrapper build"
# # ./versions/${VERSION}/build_AraRoot.sh --source "$OTHER_SCRATCH_SPACE" --build "$VIEWDIR" --root "$VIEWDIR" --deps "$VIEWDIR" || error 109 "Failed AraRoot build"
# # ./versions/${VERSION}/build_AraSim.sh --source "$SOURCE_DIR" --build "$ARA_BUILD_DIR" --root "$ROOT_BUILD_DIR" --deps "$DEPS_BUILD_DIR" $MAKE_ARG || error 110 "Failed AraSim build"
# # ./build_libnuphase.sh --source "$SOURCE_DIR" --build "$ARA_BUILD_DIR" --root "$ROOT_BUILD_DIR" --deps "$DEPS_BUILD_DIR" $SKIP_ARG || error 111 "Failed libnuphase build"
# # ./build_nuphaseroot.sh --source "$SOURCE_DIR" --build "$ARA_BUILD_DIR" --root "$ROOT_BUILD_DIR" --deps "$DEPS_BUILD_DIR" $SKIP_ARG || error 112 "Failed nuphaseroot build"

# # # ==== STEP 6: Create Setup Script ====
# # echo "[+] Creating setup script..."
# # PYVER=$("$VIEWDIR/bin/python3" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
# # SETUP_SCRIPT="$TOPDIR/setup_${OS_TAG}.sh"

# # cat > "$SETUP_SCRIPT" <<EOS
# # #!/bin/bash
# # if [ -n "\${ZSH_VERSION:-}" ]; then _SRC="\${(%):-%N}"; else _SRC="\${BASH_SOURCE[0]:-\$0}"; fi
# # export MYPROJ_ROOT="\$(cd "\$(dirname "\$_SRC")/$OS_TAG" && pwd)"

# # # Executables from the view
# # export PATH="\$MYPROJ_ROOT/bin:\$PATH"

# # # Some exports for CMake
# # export CMAKE_PREFIX_PATH="\$MYPROJ_ROOT\${CMAKE_PREFIX_PATH:+:\$CMAKE_PREFIX_PATH}"
# # export CC="\$MYPROJ_ROOT/bin/gcc"
# # export CXX="\$MYPROJ_ROOT/bin/g++"
# # export FC="\$MYPROJ_ROOT/bin/gfortran"

# # # Optional convenience vars some scripts still look for
# # export ROOTSYS="\$MYPROJ_ROOT"
# # export GSLDIR="\$MYPROJ_ROOT"

# # # Python modules installed into the view
# # export PYTHONPATH="\$MYPROJ_ROOT/lib/python$PYVER/site-packages\${PYTHONPATH:+:\$PYTHONPATH}"

# # # PyROOT modules (what thisroot.sh would add, but via the view)
# # for d in "\$MYPROJ_ROOT/lib/root" "\$MYPROJ_ROOT/lib64/root"; do
# #   if [ -d "\$d" ]; then
# #     case ":\$PYTHONPATH:" in
# #       *:"\$d":*) : ;;  # already present
# #       *) export PYTHONPATH="\$d\${PYTHONPATH:+:\$PYTHONPATH}";;
# #     esac
# #   fi
# # done

# # export LD_LIBRARY_PATH="\$MYPROJ_ROOT/lib:\$MYPROJ_ROOT/lib64\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
# # export LD_LIBRARY_PATH="\$MYPROJ_ROOT/lib/root:\$LD_LIBRARY_PATH"
# # EOS

# # chmod +x "$SETUP_SCRIPT"
# # echo "[✓] Setup script written to: $SETUP_SCRIPT"
