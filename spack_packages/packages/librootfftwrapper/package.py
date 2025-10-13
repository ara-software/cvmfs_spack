from spack.package import *

class Librootfftwrapper(CMakePackage):
    homepage = "https://github.com/nichol77/libRootFftwWrapper"
    git      = "https://github.com/nichol77/libRootFftwWrapper.git"

    version("master", branch="master")

    depends_on("cmake", type="build")
    depends_on("root")
    depends_on("fftw")

    # ARA needs this
    def setup_build_environment(self, env):
        env.set("ARA_UTIL_INSTALL_DIR", self.prefix)

    def cmake_args(self):
        args = [self.define("CMAKE_INSTALL_PREFIX", self.prefix)]

        # Mirror ROOT's cxx standard (make sure that librootfftwwrapper grabs ROOT's C++ standard)
        cxxstd = self.spec["root"].variants.get("cxxstd", None)
        if cxxstd is not None:
            std = str(cxxstd.value)
            args += [
                self.define("CMAKE_CXX_STANDARD", std),
                self.define("CMAKE_CXX_STANDARD_REQUIRED", True),
                self.define("CMAKE_CXX_EXTENSIONS", False),
            ]

        return args
