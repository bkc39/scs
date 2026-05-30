{
  description = "scs - Racket bindings for SCS, the Splitting Conic Solver";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      version = "0.1.0";

      # Native libraries to stage alongside libscsdir/libscsindir.  SCS is built
      # with LAPACK, so the BLAS/LAPACK/gfortran closure travels with it; libgomp
      # (OpenMP) is pulled in on Linux.  These get $ORIGIN rpaths in build-so.sh
      # so the package is loadable without Nix on pkgs.racket-lang.org.
      libPattern = "lib(scsdir|scsindir|openblas|blas|lapack|gfortran|quadmath|gomp|gcc_s)\\.";
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          # nixpkgs#scs (3.2.11) already ships both libscsdir (direct) and
          # libscsindir (indirect) and is built with LAPACK, so no overrideAttrs
          # is needed to satisfy our build requirements.
          scs = pkgs.scs;

          # polyfill-glibc rewrites ELF binaries built against a newer glibc so
          # they resolve only symbols available on an older target.  Used by
          # scripts/build-so.sh to make Linux candidates portable back to the
          # glibc baseline pkg-build.racket-lang.org runs.  Not in nixpkgs;
          # pinned to a known-good upstream commit.
          polyfill-glibc = pkgs.stdenv.mkDerivation {
            pname = "polyfill-glibc";
            version = "unstable-2025-dd59051";
            src = pkgs.fetchFromGitHub {
              owner = "corsix";
              repo = "polyfill-glibc";
              rev = "dd59051faaa10ee63c1b96f1b47bf9fcd3770ee2";
              hash = "sha256-Qkzy33dIGnv9BOmRwql+LpYaEukZZIADSux09Fz3h7E=";
            };
            nativeBuildInputs = [ pkgs.ninja ];
            dontConfigure = true;
            buildPhase = ''
              runHook preBuild
              ninja polyfill-glibc
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              install -Dm755 polyfill-glibc $out/bin/polyfill-glibc
              runHook postInstall
            '';
            meta = {
              description = "Patch ELF binaries to require an older glibc version";
              homepage = "https://github.com/corsix/polyfill-glibc";
              license = pkgs.lib.licenses.mit;
              platforms = [ "x86_64-linux" "aarch64-linux" ];
            };
          };

          racket = pkgs.stdenv.mkDerivation {
            pname = "scs";
            inherit version;
            src = ./.;

            nativeBuildInputs = [ pkgs.racket pkgs.makeWrapper ];
            buildInputs = [ scs ];

            buildPhase = ''
              runHook preBuild

              export PLTUSERHOME=$TMPDIR/racket-home
              export SCS_NATIVE_LIB_PATH=${scs}
              mkdir -p $PLTUSERHOME

              # Pre-populate native-libs/ so define-runtime-path resolves during
              # the test phase even without the env var.
              mkdir -p ./scs/native-libs
              cp ${scs}/lib/libscsdir.* ./scs/native-libs/ 2>/dev/null || true
              cp ${scs}/lib/libscsindir.* ./scs/native-libs/ 2>/dev/null || true

              raco pkg install --batch --deps fail --no-setup --copy --scope user \
                --name scs ./scs

              raco setup --no-docs --pkgs scs

              runHook postBuild
            '';

            doCheck = true;
            checkPhase = ''
              runHook preCheck
              raco test ./scs/
              runHook postCheck
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share $out/bin
              cp -r $PLTUSERHOME $out/share/racket-home

              makeWrapper ${pkgs.racket}/bin/racket $out/bin/scs \
                --set PLTUSERHOME $out/share/racket-home \
                --add-flags "-l scs"

              runHook postInstall
            '';
          };

          # Stage the SCS native libraries (and their runtime closure) into
          # scs/native-libs/ for non-Nix workflows.  build-so.sh wraps this with
          # rpath rewriting; this app is the quick dev-time copy.
          copy-native-libs = pkgs.writeShellApplication {
            name = "copy-native-libs";
            runtimeInputs = [ ] ++ nixpkgs.lib.optional pkgs.stdenv.isLinux pkgs.patchelf;
            text = ''
              DEST="$(pwd)/scs/native-libs"
              mkdir -p "$DEST"
              cp -v --no-preserve=mode ${scs}/lib/libscsdir.* "$DEST/"
              cp -v --no-preserve=mode ${scs}/lib/libscsindir.* "$DEST/"
              echo "SCS native libraries copied to $DEST"
              ls -la "$DEST"
            '';
          };
        in
        {
          default = racket;
          inherit racket copy-native-libs;
        } // nixpkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          inherit polyfill-glibc;
        });

      apps = forAllSystems (system: {
        copy-native-libs = {
          type = "app";
          program = "${self.packages.${system}.copy-native-libs}/bin/copy-native-libs";
        };
      });

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) racket;
      });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          scs = pkgs.scs;
          python = pkgs.python3.withPackages (ps: [ ps.scs ps.numpy ps.scipy ]);
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.racket
              scs
              python
              pkgs.stdenv.cc
            ];

            shellHook = ''
              export SCS_NATIVE_LIB_PATH="${scs}"
              export PLTUSERHOME="$PWD/.racket-user"

              # Keep a copy of the native libs in-tree so define-runtime-path
              # resolves even when SCS_NATIVE_LIB_PATH is unset.
              mkdir -p ./scs/native-libs
              cp -f ${scs}/lib/libscsdir.* ./scs/native-libs/ 2>/dev/null || true
              cp -f ${scs}/lib/libscsindir.* ./scs/native-libs/ 2>/dev/null || true

              _rkt_ver=$(racket --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+' | tr -d 'v' | tr '.' '-')
              deps_stamp="$PLTUSERHOME/.deps-installed-''${_rkt_ver}"
              if [ ! -f "$deps_stamp" ]; then
                echo "Installing Racket package (link mode, Racket ''${_rkt_ver})..."
                mkdir -p "$PLTUSERHOME"
                raco pkg install --batch --auto --no-setup --link --scope user --skip-installed \
                  --name scs "$PWD/scs"
                raco setup --no-docs --pkgs scs
                echo "Installing Racket linters (Resyntax + racket-review)..."
                raco pkg install --batch --auto --scope user --skip-installed \
                  resyntax review
                touch "$deps_stamp"
                echo "Done. Lint: resyntax analyze --directory scs  |  raco review <files>"
              fi
              # Expose user-scope Racket launchers (e.g. `resyntax`) on PATH.
              export PATH="$(racket -e '(require setup/dirs)(display (path->string (find-user-console-bin-dir)))'):$PATH"
            '';
          };
        });
    };
}
