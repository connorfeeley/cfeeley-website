# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

{ stdenv, git, emacsForPublish }:

stdenv.mkDerivation {
  name = "cfeeley-website";

  src = ../../.;

  buildInputs = [ emacsForPublish git ];
  buildPhase = ''
    mkdir -p $out
    emacs -Q --batch -l publish.el --funcall dw/publish
    cp -r public/* $out
  '';
}
