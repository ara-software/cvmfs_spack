from spack.package import *


class Librootfftwrapper(CMakePackage):
    """Wrapper library for calling FFTW from within ROOT."""

    homepage = "https://github.com/nichol77/libRootFftwWrapper"
    git      = "https://github.com/nichol77/libRootFftwWrapper.git"

    # Use master by default; upstream also has tag R1.11
    version("master", branch="master", preferred=True)
    version("r1.11", tag="R1.11")

    depends_on("cmake@3.10:", type="build")
    depends_on("root")
    depends_on("fftw")
