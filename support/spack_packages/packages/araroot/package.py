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

    # Force this package to use the same compiler as ROOT
    conflicts("%gcc", when="^root%clang")
    conflicts("%clang", when="^root%gcc")

    def setup_build_environment(self, env):
        # Get ROOT's C++ standard
        std = str(self.spec["root"].variants["cxxstd"].value)
        
        # Force the standard everywhere and add SQLite include path
        env.set("CXXFLAGS", f"-std=c++{std} -I{self.spec['sqlite'].prefix.include}")
        env.set("CMAKE_CXX_FLAGS", f"-std=c++{std} -I{self.spec['sqlite'].prefix.include}")
        
        # Use ROOT's gcc-runtime if available
        root_gcc_runtime = None
        for dep in self.spec["root"].traverse():
            if dep.name == "gcc-runtime":
                root_gcc_runtime = dep
                break
        
        if root_gcc_runtime:
            gcc_lib = root_gcc_runtime.prefix.lib64
            env.prepend_path("LD_LIBRARY_PATH", gcc_lib)

    def cmake_args(self):
        # Get ROOT's C++ standard
        std = str(self.spec["root"].variants["cxxstd"].value)

        args = [
            # Force CMake to use Spack's compiler (same as ROOT)
            self.define("CMAKE_C_COMPILER", os.environ.get("SPACK_CC", "cc")),
            self.define("CMAKE_CXX_COMPILER", os.environ.get("SPACK_CXX", "c++")),
            
            # Set the C++ standard multiple ways to override whatever the project does
            self.define("CMAKE_CXX_STANDARD", std),
            self.define("CMAKE_CXX_STANDARD_REQUIRED", "ON"),
            self.define("CMAKE_CXX_EXTENSIONS", "OFF"),
            
            # Force it through flags as well, including SQLite include path
            self.define("CMAKE_CXX_FLAGS", f"-std=c++{std} -I{self.spec['sqlite'].prefix.include}"),
        ]
        
        # Find ROOT's gcc-runtime and use it explicitly
        root_gcc_runtime = None
        for dep in self.spec["root"].traverse():
            if dep.name == "gcc-runtime":
                root_gcc_runtime = dep
                break
        
        if root_gcc_runtime:
            gcc_lib = root_gcc_runtime.prefix.lib64
            libstdcxx = f"{gcc_lib}/libstdc++.so.6"
            args.append(self.define("CMAKE_EXE_LINKER_FLAGS", f"-L{gcc_lib} -Wl,-rpath,{gcc_lib} -Wl,{libstdcxx}"))
            args.append(self.define("CMAKE_SHARED_LINKER_FLAGS", f"-L{gcc_lib} -Wl,-rpath,{gcc_lib} -Wl,{libstdcxx}"))

        return args
