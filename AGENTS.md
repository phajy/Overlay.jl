# AGENTS.md

## Cursor Cloud specific instructions

Overlay.jl is a **Julia library package** (not a service/app). There are no databases,
servers, or ports. End-to-end usage = build deps, run the test suite, and (for the GUI)
calibrate an image. Julia (>= 1.10) is installed via `juliaup`; the `julia` binary lives at
`~/.juliaup/bin/julia` and is on `PATH` in interactive shells.

### Build / test / run

- Install/refresh deps: `julia --project=. -e 'using Pkg; Pkg.instantiate()'`
  (this is the startup update script; first run precompiles GLMakie/Makie and is slow, ~5 min).
- Run tests: `julia --project=. -e 'using Pkg; Pkg.test()'` (runs `test/runtests.jl`;
  mirrors CI in `.github/workflows/CI.yml`). The test suite is headless — it does not open a window.
- Lint: there is **no configured lint step** (no `.JuliaFormatter.toml`, none in CI). The
  test suite is the canonical check.

### Non-obvious gotchas

- **Headless GUI/rendering needs a virtual display.** The interactive `calibrate_image` GUI and
  any GLMakie figure-saving (`save("fig.png", fig)`) require an OpenGL/X display. On this VM use
  `xvfb-run -a julia --project=. <script>`. Mesa software GLX is present, so Xvfb is sufficient;
  no GPU is required. The automated tests do NOT need this.
- **`Axis`/`Figure` name clash:** both `GLMakie` and `Images` export `Axis` (and some other
  names). When `using Overlay` (which re-uses both), qualify Makie entry points in your own
  scripts, e.g. `GLMakie.Figure(...)`, `GLMakie.Axis(...)`, `GLMakie.scatter!`,
  `GLMakie.axislegend`. `plot_calibrated_image!` itself is exported by Overlay and needs no prefix.
- The core coordinate/calibration API (`calibration_from_clicks`, `pixel_to_data*`,
  `data_to_pixel*`, `x_data_coords`/`y_data_coords`, `save_calibration`/`load_calibration`) is
  pure and runs without any display.
- `Manifest.toml` is gitignored; deps are resolved fresh by `Pkg.instantiate()`.
