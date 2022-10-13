# About

This is repository contains the sources for my personal site.

The entire site is generated by `publish.el` based (primarily) on the
`org` files under `content/`.

# Commands

## Nix `devshell` commands

Using my nix `progenix-std` devshell:

``` shell
nix develop ~/source/progenix-std#cf-site-shell --command menu
```

``` shell
nixago: updating repositoriy files

[general commands]

  adrgen          - A command-line tool for generating and managing Architecture Decision Records
  check-the-flake - builds everything in the flake
  mdbook          - Create books from MarkDown
  menu            - prints this menu
  repo-root       - prints the repository root path
  treefmt         - one CLI to format the code tree
  wip             - alias for: git add . && git commit -m WIP

[legal]

  reuse           - A tool for compliance with the REUSE Initiative recommendations

[site]

  publish         - Generate website by calling publish.el
  readme          - Export README.org to README.md

```

## Generate the site

Simply run `publish` from inside the devshell:

``` shell
publish
```

Alternatively, run the `publish` command from outside the devshell:

``` shell
nix develop ~/source/progenix-std#cf-site-shell --command publish
```

### Watching for changes

It's a bit annoying having to flip to a `vterm` to run `publish`. I'd
prefer it if the site were automatically re-generated whenever there's a
change.

Sounds like a job for `entr`:

``` shell
fd . --extension=org | entr publish
```

## Export `README.org` to `README.md`

Since sourcehut doesn't support `org` README files, we need to convert
it manually by running the `readme` devshell command:

``` shell
readme
```

Alternatively, run the `readme` command from outside the devshell:

``` shell
nix develop ~/source/progenix-std#cf-site-shell --command readme
```

# Acknowledgements

-   System Crafters' (David Wilson) `org-mode` site: \[
    [webpage](https://systemcrafters.net/) \|
    [src](https://github.com/SystemCrafters/systemcrafters.github.io) \]
-   The `std` Nix flake framework; used for the `progenix-std`
    devshells: \[ [webpage](https://std.divnix.com/) \|
    [src](https://github.com/divnix/std) \]
