set -e

cabal update
cabal build exe:ormolu --enable-executable-static --ghc-options=""

cp $(find dist-newstyle -name ormolu -type f) .
