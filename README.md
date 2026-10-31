# Overlay.jl

[![Build Status](https://github.com/phajy/Overlay.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/phajy/Overlay.jl/actions/workflows/CI.yml?query=branch%3Amain)

**Overlay.jl** helps you **over-plot your own data** on a figure from the literature (PNG, JPEG, a rasterized PDF page, etc.). Typical workflow: load the image, run an interactive calibration once, save the calibration, then plot the image in data coordinates and overlay curves or scatter (for example with **Makie** or **Plots.jl**).

**Julia** ≥ 1.10 is required. Current release target: **1.1.0**.

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/phajy/Overlay.jl")
```

The package is not yet in the General registry or [AstroRegistry](https://github.com/astro-group-bristol/AstroRegistry); install from the GitHub URL above.

## Interactive calibration

```julia
using Overlay
using Images

img = load("literature_plot.png")
cal = calibrate_image(img; title = "Click two x, then two y")
save_calibration("literature_plot.calibration.toml", cal)  # TOML by default
```

A **GLMakie** window opens (it may appear **behind** your IDE). Everything is **in the figure**: instructions in a label, **numeric values in a text box** (type the number, press **Enter**), and **linear** / **log₁₀** axis mode via two **buttons** (no REPL typing). Step order:

1. **x₀** — left-click a known **x** **on the image**, then enter that data value in the text box (must be **positive** if you choose log **x**).
2. **x₁** — second **x** click on the image, then its value.
3. **x scale** — press **linear** or **log₁₀**.
4. **y₀** / **y₁** — same for **y** (positive if you choose log **y**).
5. **y scale** — **linear** or **log₁₀**.

The points do **not** need to lie on the axes. **Log** axes use **base 10** (tick labels on typical log plots): pixel position is **affine in log10(data)** along that axis. No rotation beyond what is already in the image file.

Programmatic calibration (tests, scripts, no GUI):

```julia
cal = calibration_from_clicks(;
    img_size = size(img),
    x_pixels = (10.0, 90.0),
    x_values = (1.0, 100.0),
    y_pixels = (5.0, 45.0),
    y_values = (0.1, 10.0),
    x_log = true,
    y_log = true,
    # optional: record full click positions for mark_calibration_points
    x_click_py = (12.0, 40.0),
    y_click_px = (20.0, 80.0),
)
```

Calibration requires a **graphical display**; it will not run on a headless server without appropriate setup (e.g. `xvfb-run` on Linux).

## Using the calibration

`cal` is an `ImageCalibration` with `x_scale`, `y_scale`, `x_log`, `y_log`, `aspect_ratio`, `img_width`, `img_height`, and optionally `click_markers` (four data-space points for the calibration clicks). Use `x_data_coords(cal)` and `y_data_coords(cal)` for **data-space** vectors aligned to pixels—recommended for **Plots.jl** heatmaps when either axis can be log.

`x_scale` / `y_scale` are uniform along pixel index in *transform space*: for linear axes they equal data *x* / *y*; for log axes they are **log10** of positive data values. Prefer `pixel_to_data` / `x_data_coords` when you need data-space values.

### Makie

```julia
using Overlay
using Images
using Makie, GLMakie

fig = Makie.Figure()
ax = Makie.Axis(fig[1, 1])  # qualify Axis/Figure: Images also exports Axis
plot_calibrated_image!(ax, img, cal)  # sets xscale/yscale to log10 when needed
# Optional: show the four calibration clicks (needs click_markers, e.g. from calibrate_image):
# plot_calibrated_image!(ax, img, cal; mark_calibration_points = true)
Makie.scatter!(ax, xs, ys)  # your overlay in the same data coordinates
fig
```

### Plots.jl

The calibration window displays `rotr90(img)` for convenience. Match that orientation and set axis scales when needed:

```julia
using Plots

xs = x_data_coords(cal)
ys = y_data_coords(cal)
plot(xs, ys, reverse(rotr90(img), dims = 1); yflip = false, aspect_ratio = :equal,
     xscale = cal.x_log ? :log10 : :identity,
     yscale = cal.y_log ? :log10 : :identity)
plot!(1.5 .* rand(10), rand(10); seriestype = :scatter)
```

`aspect_ratio = cal.aspect_ratio` is the image’s **pixel** height/width ratio; for many overlays, `aspect_ratio = :equal` (equal data units) is easier to reason about.

### Coordinate helpers

- `pixel_to_data(cal, i, j)` — data `(x, y)` from 1-based fractional indices.
- `pixel_to_data_continuous(cal, px, py)` — same, with `px`, `py` in `[0, img_width]` × `[0, img_height]`.
- `data_to_pixel` / `data_to_pixel_continuous` — inverses (log axes require positive coordinates).
- `x_data_coords` / `y_data_coords` — data-space vectors along each image dimension.

## Saving and reloading calibration

**Recommended (TOML):** human-readable, versioned (`format_version`), portable across Overlay.jl versions that support that format version.

```julia
save_calibration("my_plot.calibration.toml", cal)                 # format = :toml (default)
cal2 = load_calibration("my_plot.calibration.toml")
```

`load_calibration` auto-detects TOML vs legacy Julia **Serialization** binaries. Prefer re-saving old Serialization files as TOML after loading them once:

```julia
cal_old = load_calibration("old.calibration")          # Serialization still loads when possible
save_calibration("old.calibration.toml", cal_old)      # migrate to TOML
```

Legacy binary save (not recommended for new work):

```julia
save_calibration("my_plot.calibration", cal; format = :serialize)
```

## PDFs

Overlay.jl does not rasterize PDFs. Export a page to PNG (or use another Julia package to rasterize), then load the PNG with **Images.jl** as above.

## API summary

| Function | Purpose |
|----------|---------|
| `calibrate_image(img; title=..., figsize=...)` | Interactive four-click calibration → `ImageCalibration` |
| `calibration_from_clicks(...; x_log, y_log, x_click_py, y_click_px)` | Same math without a GUI; optional click metadata for markers |
| `x_data_coords`, `y_data_coords` | Data-space coordinates along pixels |
| `pixel_to_data`, `data_to_pixel` | Index ↔ data coordinates |
| `pixel_to_data_continuous`, `data_to_pixel_continuous` | Continuous pixel frame ↔ data |
| `save_calibration`, `load_calibration` | Persist / restore (TOML default; Serialization optional) |
| `plot_calibrated_image!(ax, img, cal; mark_calibration_points=false)` | Makie background image + optional click markers |
| `transformed_extent_aspect` | `Tx/Ty` for Makie `AxisAspect` on log/linear extents |

## Developing this package

```julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'
```

Optional GUI smoke checks need a display (or `xvfb-run -a …` on Linux). Dev tools (**Revise**, **JuliaFormatter**, etc.) belong in your global or a dedicated env, not as package dependencies.
