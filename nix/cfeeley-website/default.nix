# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

{ lib, stdenv, git, emacsForPublish, publishUrl }:

stdenv.mkDerivation {
  name = "cfeeley-website";

  src = ../../.;

  buildInputs = [ emacsForPublish git ];

  patchPhase = lib.optionalString (publishUrl != null) ''
    substituteInPlace publish.el --replace "http://localhost:8080" "${publishUrl}"
  '';

  buildPhase = ''
    mkdir -p $out
    emacs -Q --batch -l publish.el --funcall dw/publish
    cp -r public/* $out
  '';
}
