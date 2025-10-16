from spack.package import *
import os

class Librootfftwrapper(CMakePackage):
    homepage = "https://github.com/nichol77/libRootFftwWrapper"
    git      = "https://github.com/nichol77/libRootFftwWrapper.git"

    version("master", branch="master")

    depends_on("cmake", type="build")
    depends_on("root")
    depends_on("fftw")

    # Force this package to use the same compiler as ROOT
    conflicts("%gcc", when="^root%clang")
    conflicts("%clang", when="^root%gcc")
    
    def setup_build_environment(self, env):
        env.set("ARA_UTIL_INSTALL_DIR", self.prefix)

    def cmake_args(self):
        args = [self.define("CMAKE_INSTALL_PREFIX", self.prefix)]

        # Force CMake to use Spack's compiler
        # The spack_cc/spack_cxx are in the environment during build
        args.extend([
            self.define("CMAKE_C_COMPILER", os.environ.get("SPACK_CC", "cc")),
            self.define("CMAKE_CXX_COMPILER", os.environ.get("SPACK_CXX", "c++")),
        ])

        # Mirror ROOT's cxx standard
        cxxstd = self.spec["root"].variants.get("cxxstd", None)
        if cxxstd is not None:
            std = str(cxxstd.value)
            args += [
                self.define("CMAKE_CXX_STANDARD", std),
                self.define("CMAKE_CXX_STANDARD_REQUIRED", True),
                self.define("CMAKE_CXX_EXTENSIONS", False),
            ]

        return args
