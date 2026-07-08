# Shared setup for CrashSimulator bats tests.
#
# Sources the lib/*.sh fragments that define the pure helper functions under
# test. The fragments are declaration-only (the runtime entrypoint lives in
# lib/99_main.sh, which is NOT sourced here), so sourcing them just defines
# functions. Only SUCCESS/FAIL (the return-code globals the helpers use) are
# needed.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${SUCCESS:=0}"
: "${FAIL:=1}"
export SUCCESS FAIL

# shellcheck disable=SC1090,SC1091
source "$REPO_ROOT/lib/10_core.sh"
# shellcheck disable=SC1090,SC1091
source "$REPO_ROOT/lib/65_maa.sh"
# shellcheck disable=SC1090,SC1091
source "$REPO_ROOT/lib/75_scenarios.sh"
