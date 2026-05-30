#!/usr/bin/env bash
set -euo pipefail

# End-to-end test using the system Racket install (no Nix, no
# SCS_NATIVE_LIB_PATH).  Installs the scs package from native-libs/candidates/
# via the pre-install hook, then runs the unit tests and all examples.  This
# reproduces what pkg-build.racket-lang.org does.

RACKET=$(command -v racket 2>/dev/null || true)
RACO=$(command -v raco 2>/dev/null || true)

if [ -z "$RACKET" ] || [ -z "$RACO" ]; then
  echo "Error: racket/raco not found on PATH" >&2
  exit 1
fi
echo "Using $("$RACKET" --version)"

cd "$(dirname "$0")/.."

# Ensure the loader cannot fall back to a Nix store path.
unset SCS_NATIVE_LIB_PATH

echo "--- cleaning compiled bytecode ---"
find scs examples -name "compiled" -type d -exec rm -rf {} + 2>/dev/null || true

echo "--- removing previous scs install ---"
"$RACO" pkg remove scs 2>/dev/null || true

echo "--- clearing staged native libs (keep candidates/) ---"
find scs/native-libs -maxdepth 1 -type f -name 'lib*' -delete 2>/dev/null || true

echo "--- installing from candidates ---"
"$RACO" pkg install --name scs ./scs

echo "--- raco test scs/ ---"
"$RACO" test scs/

echo "--- examples ---"
"$RACO" test \
  examples/00-quadratic-program.rkt \
  examples/01-linear-program.rkt \
  examples/02-second-order-cone.rkt \
  examples/03-semidefinite.rkt \
  examples/04-exponential-cone.rkt \
  examples/05-warm-start-update.rkt \
  examples/06-indirect-solver.rkt

echo "--- all done ---"
