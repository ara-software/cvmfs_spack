from spack.package import *
import os

class Araroot(CMakePackage):
    homepage = "https://github.com/ara-software/AraRoot"
    git      = "https://github.com/ara-software/AraRoot.git"

    version("master", branch="master")

    depends_on("cmake", type="build")
    depends_on("root")
    depends_on("fftw")
    depends_on("gsl")
    depends_on("sqlite")
    depends_on("librootfftwrapper")

    # Make sure every compile (incl. dictionaries) carries the same -std=c++<ROOT>
    def setup_build_environment(self, env):
        # 1) Force compilers for this build env (overrides /usr/bin/cc if exported)
        env.set("CC",  self.compiler.cc)   # e.g. .../gcc-15.2.0/bin/gcc
        env.set("CXX", self.compiler.cxx)  # e.g. .../gcc-15.2.0/bin/g++
        # 2) Force standard to match ROOT's (e.g. 17/20/23)
        std = str(self.spec["root"].variants["cxxstd"].value)
        env.append_flags("CXXFLAGS", f"-std=c++{std}")

    def cmake_args(self):
        # Mirror ROOT's C++ standard
        std = str(self.spec["root"].variants["cxxstd"].value)

        # Also pin compilers in the CMake cache
        cc  = self.spec.compiler.cc
        cxx = self.spec.compiler.cxx

        return [
            self.define("CMAKE_INSTALL_PREFIX", self.prefix),
            self.define("CMAKE_C_COMPILER", cc),
            self.define("CMAKE_CXX_COMPILER", cxx),
            self.define("CMAKE_CXX_STANDARD", std),
            self.define("CMAKE_CXX_STANDARD_REQUIRED", True),
            self.define("CMAKE_CXX_EXTENSIONS", False),
        ]
