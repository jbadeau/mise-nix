{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    # Lua
    pkgs.lua5_4

    # Node.js
    pkgs.nodejs_24

    # GCC
    pkgs.gcc13

    # GNU Make
    pkgs.gnumake

    # libuv
    pkgs.libuv

    # pkg-config
    pkgs.pkg-config

    # Python
    pkgs.python312

    # SQLite
    pkgs.sqlite

    # Zulu JDK
    pkgs.zulu17

    # Yarn Berry
    pkgs.yarn-berry

    # ShellSpec
    pkgs.shellspec
  ];

  shellHook = ''
  '';
}
