## aglaea

- Docker: daemon is amalthea (`docker` context `amalthea`, default). Bind mounts and `-v $PWD` resolve on amalthea's disk; published ports listen on amalthea, not localhost. Mount-heavy local runs: run from a checkout on amalthea, or `docker context use orbstack` (start OrbStack first) and switch back after. Never prune volumes without asking.
