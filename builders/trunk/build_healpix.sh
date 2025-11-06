#!/bin/sh
# Build script for healpix

# Set script parameters
PACKAGE_NAME="healpix"
DOWNLOAD_LINK="https://sourceforge.net/projects/healpix/files/Healpix_3.83/Healpix_3.83_2024Nov13.tar.gz/download"
PACKAGE_DIR_NAME="healpix"

usage() {
	echo "usage: $0 [-h] [-d destination] [-s destination] [-b destination] [-r directory] [--deps directory] [--make_arg argument] [--skip_download, --skip_build] [--clean_source]"
	echo "  -h, --help                      display this help message"
	echo "  -d, --dest destination          set the destination directory (containing source and build directories)"
	echo "  -s, --source destination        set the source destination directory"
	echo "  -b, --build destination         set the build destination directory"
	echo "  -r, --root directory            set the root build directory"
	echo "  --deps directory                set the dependency build directory"
	echo "  --make_arg argument             additional argument to be passed to make"
	echo "  --skip_download                 $PACKAGE_NAME exists pre-downloaded at the source destination"
	echo "  --skip_build                    $PACKAGE_NAME has already been built at the build destination"
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
		--make_arg )
			shift
			MAKE_ARG="$1"
		;;
		--skip_download )
			SKIP_DOWNLOAD=true
		;;
		--skip_build )
			SKIP_BUILD=true
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
	# Remove existing directory if it exists
	if [ -d "$PACKAGE_DIR_NAME" ]; then
		rm -rf "$PACKAGE_DIR_NAME"
	fi
	mkdir "$PACKAGE_DIR_NAME"
	tar -xzf "$PACKAGE_DIR_NAME.tar.gz" -C "$PACKAGE_DIR_NAME" --strip-components=1 || exit 12
	rm "$PACKAGE_DIR_NAME.tar.gz"
fi

# Set required environment variables
if [ $SKIP_BUILD = false ]; then
	export ARA_UTIL_INSTALL_DIR="${BUILD_DIR%/}"
	export ARA_DEPS_INSTALL_DIR="${DEPS_BUILD_DIR%/}"
	export ARA_ROOT_DIR="${SOURCE_DIR%/}/$PACKAGE_DIR_NAME"
	export LD_LIBRARY_PATH="$ARA_DEPS_INSTALL_DIR/lib:$LD_LIBRARY_PATH"
	export DYLD_LIBRARY_PATH="$ARA_DEPS_INSTALL_DIR/lib:$DYLD_LIBRARY_PATH"
	# . "${ROOT_BUILD_DIR%/}"/bin/thisroot.sh || exit 21
	export PATH="$ARA_DEPS_INSTALL_DIR/bin:$PATH"
	export PKG_CONFIG_PATH="$ARA_DEPS_INSTALL_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
fi

# Run package installation
if [ $SKIP_BUILD = false ]; then
	echo "Compiling $PACKAGE_NAME"
	cd "$PACKAGE_DIR_NAME"

	# First, build and install libsharp which is bundled inside healpix
	echo "Building libsharp..."
	cd src/common_libraries/libsharp
	autoreconf -i --force || exit 22
	
	echo "Configuring libsharp..."
	./configure --prefix="$ARA_DEPS_INSTALL_DIR" \
		CFLAGS="-fPIC -O3" || exit 23
	
	echo "Compiling libsharp..."
	make "$MAKE_ARG" || exit 24
	
	echo "Installing libsharp..."
	make install "$MAKE_ARG" || exit 25
	
	# Go back to main healpix directory
	cd ../../..

	# Now prepare and build the C++ portion
	echo "Preparing healpix C++..."
	cd src/cxx
	autoreconf -i --force || exit 26

	# Configure with cfitsio and libsharp from dependencies
	echo "Configuring $PACKAGE_NAME..."
	./configure --prefix="$ARA_DEPS_INSTALL_DIR" \
		LDFLAGS="-L$ARA_DEPS_INSTALL_DIR/lib" \
		CPPFLAGS="-I$ARA_DEPS_INSTALL_DIR/include" \
		CXXFLAGS="-fPIC -O3" \
		CFLAGS="-fPIC -O3" || exit 27

	# Build
	echo "Building $PACKAGE_NAME..."
	make "$MAKE_ARG" || exit 28

	# Install
	echo "Installing $PACKAGE_NAME..."
	make install "$MAKE_ARG" || exit 29
fi

# Clean up source directory if requested
if [ $CLEAN_SOURCE = true ]; then
	echo "Removing $PACKAGE_NAME source directory from $SOURCE_DIR"
	cd "$SOURCE_DIR"
	rm -rf "$PACKAGE_DIR_NAME"
fi

echo "$PACKAGE_NAME installed in $ARA_DEPS_INSTALL_DIR"
