# Overlay.jl

[![Build Status](https://github.com/phajy/Overlay.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/phajy/Overlay.jl/actions/workflows/CI.yml?query=branch%3Amain)

**Overlay.jl** helps you **over-plot your own data** on a figure from the literature (PNG, JPEG, a rasterized PDF page, etc.). Typical workflow: load the image, run an interactive calibration once, then plot the image in data coordinates and overlay curves, scatter, etc. (for example with **Plots.jl** or **Makie**).

**Julia** ≥ 1.10 is required.

**Breaking change (from earlier prototypes):** `calibrate_image` returns an `ImageCalibration` object, not a tuple. Fields `x_scale` / `y_scale` are **uniform along pixel index** in *transform space*: for linear axes they equal data *x* / *y*; for log axes they are **log10** of positive data values. Use `pixel_to_data` or `x_data_coords` / `y_data_coords` for data-space values. The struct includes `x_log`, `y_log`, and `aspect_ratio`.

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/phajy/Overlay.jl")
```

## Interactive calibration

```julia
using Overlay
using Images

img = load("literature_plot.png")
cal = calibrate_image(img; title = "Click two x, then two y")
```

A **GLMakie** window opens (it may appear **behind** your IDE). Prompt order:

1. **x₀** — known data **x**, then type that value (must be **positive** if you choose a log x-axis).
2. **x₁** — second known **x**.
3. Whether the **x**-axis is **linear** or **log10** (blank or `linear` = linear; `log` or `log10` = log).
4. **y₀** / **y₁** — same for **y** (positive if you choose log **y**).
5. Whether the **y**-axis is linear or log10.

The points do **not** need to lie on the axes. **Log** axes use **base 10** (tick labels on typical log plots): pixel position is **affine in log10(data)** along that axis. No rotation beyond what is already in the image file.

Programmatic calibration: pass `x_log=true` / `y_log=true` to `calibration_from_clicks`.

Calibration requires a **graphical display**; it will not run on a headless server without appropriate setup.

## Using the calibration

`cal` is an `ImageCalibration` with `x_scale`, `y_scale`, `x_log`, `y_log`, `aspect_ratio`, `img_width`, and `img_height`. Use `x_data_coords(cal)` and `y_data_coords(cal)` for **data-space** vectors (length `img_width` / `img_height`) aligned to pixels—recommended for **Plots.jl** heatmaps when either axis can be log.

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

If both axes are linear, `xs` / `ys` match `collect(cal.x_scale)` / `collect(cal.y_scale)` up to floating details.

`aspect_ratio = cal.aspect_ratio` is the image’s **pixel** height/width ratio; for many overlays, `aspect_ratio = :equal` (equal data units) is easier to reason about. Adjust if the background and overlays must match a specific physical aspect.

### Makie

```julia
using GLMakie
using Overlay

fig = Figure()
ax = Axis(fig[1, 1])  # plot_calibrated_image! sets aspect = transformed limits (Tx/Ty), not DataAspect
plot_calibrated_image!(ax, img, cal)  # sets xscale/yscale to log10 when cal.x_log / cal.y_log
scatter!(ax, xs, ys)  # your overlay in the same data coordinates
fig
```

### Coordinate helpers

- `pixel_to_data(cal, i, j)` — data `(x, y)` from 1-based fractional indices.
- `pixel_to_data_continuous(cal, px, py)` — same, with `px`, `py` in `[0, img_width]` × `[0, img_height]` (viewport mapping frame).
- `data_to_pixel` / `data_to_pixel_continuous` — inverses (log axes require positive coordinates).
- `x_data_coords` / `y_data_coords` — data-space vectors along each image dimension.

## Saving and reloading calibration

```julia
save_calibration("my_plot.calibration", cal)
cal2 = load_calibration("my_plot.calibration")
```

The file is written with Julia’s **Serialization** standard library (Julia-specific, not a portable JSON format).

## PDFs

Overlay.jl does not rasterize PDFs. Export a page to PNG (or use another Julia package to rasterize), then load the PNG with **Images.jl** as above.

## API summary

| Function | Purpose |
|----------|---------|
| `calibrate_image(img; title=...)` | Interactive four-click calibration → `ImageCalibration` |
| `calibration_from_clicks(...; x_log, y_log)` | Same math without a GUI (tests, scripts) |
| `x_data_coords`, `y_data_coords` | Data-space coordinates along pixels (for heatmaps / Plots) |
| `pixel_to_data`, `data_to_pixel` | Index ↔ data coordinates |
| `pixel_to_data_continuous`, `data_to_pixel_continuous` | Continuous pixel frame ↔ data |
| `save_calibration`, `load_calibration` | Persist / restore calibration |
| `plot_calibrated_image!(ax, img, cal)` | Makie: background image with correct extents |

## Developing this package

Optional dev tools (**Revise**, **JuliaFormatter**, etc.) should be installed in your global environment or a dedicated dev environment, not listed as package dependencies.
