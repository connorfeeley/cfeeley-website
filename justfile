#!/usr/bin/env -S just --justfile
# ^ A shebang isn't required, but allows a justfile to be executed
#   like a script, with `./justfile test`, for example.

watch:
  fd . --extension=org --extension=css --extension=js --extension=html --extension=el --extension=nix | entr -a nom build

serve:
  python -m http.server 8080 --directory result
