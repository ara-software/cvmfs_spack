from spack.package import *

class Librootfftwrapper(CMakePackage):
    homepage = "https://github.com/nichol77/libRootFftwWrapper"
    git      = "https://github.com/nichol77/libRootFftwWrapper.git"

    version("master", branch="master")

    depends_on("cmake", type="build")
    depends_on("root")
    depends_on("fftw")
