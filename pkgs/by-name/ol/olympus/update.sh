#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts

set -eu -o pipefail

api() {
  curl -s "https://dev.azure.com/EverestAPI/Olympus/_apis/$1?api-version=7.1"
}

pipeline_id=$(api pipelines | jq -r '
  .value
  | map(select(.name == "EverestAPI.Olympus"))
  | .[0].id
')

run_id=$(api pipelines/$pipeline_id/runs | jq -r '
  .value
  | map(select(.result == "succeeded"))
  | max_by(.finishedDate)
  | .id
')

run=$(api pipelines/$pipeline_id/runs/$run_id)

commit=$(echo "$run" | jq -r '.resources.repositories.self.version')
version=$(echo "$run" | jq -r '.name')
update-source-version olympus $version --rev=$commit

"$(nix-build --attr olympus.fetch-deps --no-out-link)"
