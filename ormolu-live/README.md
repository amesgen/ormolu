# Ormolu Live

Play around with ormolu in the browser via GHCJS!

## Development

### Building the site with GHCJS

```
nix build .#ormoluLive/website
```

### Local development with JSaddle

In a Nix shell (or if you have cabal installed), run

```
ghcid -r -W
```

and open `http://localhost:8080` in a Chromium-based browser.

## Acknowledgements

https://github.com/monadfix/ormolu-live
