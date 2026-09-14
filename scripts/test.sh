#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift run WorkshopChecks
swift run DisinformationWorkshop --smoke-test
