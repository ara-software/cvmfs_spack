# cvmfs_spack
Spack-based builder for the ARA cvmfs

## To compile, we run like
```
bash build_version.sh trunk el9
```

That would build the trunk version for el9.

It works by dropping you into a singularity/apptainer imagine.
So it's going to look for `el9.sif`.

And it's going to try and install spack with the `trunk.yaml` in `versions/`.
And then use the builder scripts in that repo.

## Building the apptainer imagge
To build the sif, we do:
apptainer build output.sif recipe.cfg
