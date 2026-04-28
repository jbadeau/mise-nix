FROM nixos/nix:2.34.1

RUN mkdir -p /etc/nix \
  && printf '%s\n' \
    'experimental-features = nix-command flakes' \
    'accept-flake-config = true' \
    'sandbox = false' \
    > /etc/nix/nix.conf

RUN nix profile install \
  nixpkgs#lua53Packages.busted \
  nixpkgs#mise \
  nixpkgs#shellspec \
  nixpkgs#unzip \
  nixpkgs#zip

ENV PATH="/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"
ENV SSL_CERT_FILE="/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
ENV NIX_SSL_CERT_FILE="/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
ENV MISE_LIBGIT2="false"
ENV MISE_GIX="false"

WORKDIR /workspace
COPY . /workspace

CMD ["/workspace/scripts/run-isolated-e2e.sh"]
