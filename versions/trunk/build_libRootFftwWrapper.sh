#!/bin/sh
# Build script for libRootFftwWrapper

# Set script parameters
PACKAGE_NAME="libRootFftwWrapper"
DOWNLOAD_LINK="https://github.com/nichol77/libRootFftwWrapper/archive/master.tar.gz"
PACKAGE_DIR_NAME="libRootFftwWrapper"


usage() {
	echo "usage: $0 [-h] [-d destination] [-s destination] [-b destination] [-r directory] [--deps directory] [--make_arg argument] [--skip_download, --skip_build] [--clean_source]"
	echo "  -h, --help                      display this help message"
	echo "  -d, --dest destination          set the destination directory (containing source and build directories)"
	echo "  -s, --source destination        set the source destination directory"
	echo "  -b, --build destination         set the build destination directory"
	echo "  -r, --root directory            set the root build directory"
	echo "  --deps directory                set the dependency build directory"
	echo "  --make_arg argument             additional argument to be passed to make"
	echo "  --clean_source                  remove source directory after build"
}

# Parse command line options
SKIP_DOWNLOAD=false
SKIP_BUILD=false
CLEAN_SOURCE=false
while [ "$1" != "" ]; do
	case $1 in
		-h | --help )
			usage
			exit
		;;
		-d | --dest )
			shift
			DEST="$1"
		;;
		-s | --source )
			shift
			SOURCE_DIR="$1"
		;;
		-b | --build )
			shift
			BUILD_DIR="$1"
		;;
		-r | --root )
			shift
			ROOT_BUILD_DIR="$1"
		;;
		--deps )
			shift
			DEPS_BUILD_DIR="$1"
		;;
		--clean_source)
			CLEAN_SOURCE=true
		;;
		* )
			usage
			exit 1
		;;
	esac
	shift
done

if [ "$DEST" != "" ]; then
	if [ -z "$SOURCE_DIR" ]; then
		SOURCE_DIR="${DEST%/}/source/"
	fi
	if [ -z "$BUILD_DIR" ]; then
		BUILD_DIR="${DEST%/}/build/"
	fi
fi

if [ -z "$DEPS_BUILD_DIR" ]; then
	DEPS_BUILD_DIR="$BUILD_DIR"
fi

if [ -z "$ROOT_BUILD_DIR" ]; then
	ROOT_BUILD_DIR="$BUILD_DIR"
fi

if [ ! -d "$SOURCE_DIR" ]; then
	echo "Invalid source destination directory: $SOURCE_DIR"
	exit 2
fi
if [ ! -d "$BUILD_DIR" ]; then
	echo "Invalid build destination directory: $BUILD_DIR"
	exit 3
fi
if [ ! -d "$DEPS_BUILD_DIR" ]; then
	echo "Invalid dependency build directory: $DEPS_BUILD_DIR"
	exit 4
fi
if [ ! -d "$ROOT_BUILD_DIR" ]; then
	echo "Invalid root build directory: $ROOT_BUILD_DIR"
	exit 5
fi


# Download and unzip the package
cd "$SOURCE_DIR"
if [ $SKIP_DOWNLOAD = false ]; then
	echo "Downloading $PACKAGE_NAME to $SOURCE_DIR"
	wget "$DOWNLOAD_LINK" -O "$PACKAGE_DIR_NAME.tar.gz" || exit 11
	echo "Extracting $PACKAGE_NAME"
	mkdir "$PACKAGE_DIR_NAME"
	tar -xzf "$PACKAGE_DIR_NAME.tar.gz" -C "$PACKAGE_DIR_NAME" --strip-components=1 || exit 12
	rm "$PACKAGE_DIR_NAME.tar.gz"
fi

# Set required environment variables
if [ $SKIP_BUILD = false ]; then
	export ARA_UTIL_INSTALL_DIR="${DEPS_BUILD_DIR%/}"
	export ARA_DEPS_INSTALL_DIR="${DEPS_BUILD_DIR%/}"
	export LD_LIBRARY_PATH="$ARA_DEPS_INSTALL_DIR/lib:$LD_LIBRARY_PATH"
	export DYLD_LIBRARY_PATH="$ARA_DEPS_INSTALL_DIR/lib:$DYLD_LIBRARY_PATH"
	export PATH="$ARA_DEPS_INSTALL_DIR/bin:$PATH"
	. "${ROOT_BUILD_DIR%/}"/bin/thisroot.sh || exit 21
	export SQLITE_ROOT="$ARA_DEPS_INSTALL_DIR"
	export GSL_ROOT="$ARA_DEPS_INSTALL_DIR"
	export FFTWSYS="$ARA_DEPS_INSTALL_DIR"
	export CMAKE_PREFIX_PATH="$ARA_DEPS_INSTALL_DIR"
fi

# Run package installation
if [ $SKIP_BUILD = false ]; then
	echo "Compiling $PACKAGE_NAME"
	cd "$PACKAGE_DIR_NAME"
	sed -i 's:^find_package(FFTW REQUIRED):#find_package(FFTW REQUIRED)\
set(FFTW_LIBRARIES "$ENV{FFTWSYS}/lib/libfftw3.so.3.6.9")\
set(FFTW_INCLUDES "$ENV{FFTWSYS}/include"):' CMakeLists.txt
	echo "Installing $PACKAGE_NAME"
	make || exit 32
	make install || exit 33
fi

# Clean up source directory if requested
if [ $CLEAN_SOURCE = true ]; then
	echo "Removing $PACKAGE_NAME source directory from $SOURCE_DIR"
	cd "$SOURCE_DIR"
	rm -rf "$PACKAGE_DIR_NAME"
fi

echo "$PACKAGE_NAME installed in $BUILD_DIR"
