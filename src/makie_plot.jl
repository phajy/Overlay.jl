function _extent_lo_hi(cal, is_x::Bool)
    r = is_x ? cal.x_scale : cal.y_scale
    logf = is_x ? cal.x_log : cal.y_log
    lo = logf ? exp10(float(first(r))) : float(first(r))
    hi = logf ? exp10(float(last(r))) : float(last(r))
    lo, hi = minmax(lo, hi)
    if logf
        # log axes require strictly positive limits; exp10 can underflow to 0.0
        lo = max(lo, nextfloat(0.0))
        hi = max(hi, nextfloat(0.0))
        if hi <= lo
            hi = lo * 10
        end
    end
    return lo, hi
end

function _format_marker_coord(x::Float64)
    ax = abs(x)
    if isnan(x) || isinf(x)
        return string(x)
    end
    if ax == 0.0 || (ax >= 1e-3 && ax < 1e5)
        return string(round(x; sigdigits = 5))
    end
    return string(round(x; sigdigits = 4))
end

function _plot_calibration_markers!(ax, click_markers)
    labels = ("x₀", "x₁", "y₀", "y₁")
    for (k, (x, y)) in enumerate(click_markers)
        Makie.scatter!(
            ax,
            x,
            y;
            marker = :circle,
            markersize = 12,
            color = (:orangered, 0.92),
            strokecolor = :white,
            strokewidth = 2,
        )
        lab = string(labels[k], "\n(", _format_marker_coord(x), ", ", _format_marker_coord(y), ")")
        Makie.text!(
            ax,
            lab;
            position = (x, y),
            align = (:center, :bottom),
            offset = (0, 10),
            fontsize = 10,
            color = :white,
            strokecolor = :black,
            strokewidth = 3,
        )
    end
    return nothing
end

"""
    plot_calibrated_image!(ax, img, cal::ImageCalibration; mark_calibration_points=false, kwargs...)

Plot `img` on Makie axis `ax` with the same rotation as interactive calibration (`rotr90`),
using **data-space** extents. If `cal.x_log` / `cal.y_log`, sets `xscale` / `yscale` to `log10`.

# Keyword arguments
- `mark_calibration_points` (default `false`): when `true`, draw circles and short labels at the
  four calibration click positions in data space when `cal.click_markers` is set (from
  [`calibrate_image`](@ref) or [`calibration_from_clicks`](@ref) with both `x_click_py` and
  `y_click_px`). If `true` but `cal.click_markers === nothing`, a warning is issued and nothing
  extra is drawn.

Extra `kwargs` are forwarded to `Makie.image!` (not including `mark_calibration_points`).

A fresh `Axis` starts with linear default limits `(0, 10)` on each side; assigning `log10`
before replacing those limits triggers Makie’s validation error. This function sets
**limits first** (still on the default identity scale), then switches to log scales, then
draws the image.

**Aspect ratio:** `DataAspect()` uses the linear span `(xhi - xlo) / (yhi - ylo)`, which is
misleading on **log** axes. Makie’s axis camera fits `transformed_extent_aspect`’s
`Tx/Ty` (Δlog10 along log axes, linear otherwise). This function sets
`ax.aspect = AxisAspect(Tx/Ty)` so the layout viewport matches that camera box—avoiding
independent x/y scaling that can look like a slight stretch when it disagrees with
`ncols/nrows` alone.
"""
function plot_calibrated_image!(
    ax,
    img,
    cal::ImageCalibration;
    mark_calibration_points::Bool = false,
    kwargs...,
)
    mat = rotr90(img)
    nr, nc = size(mat)
    (nr > 0 && nc > 0) || throw(ArgumentError("image must be non-empty"))

    xlo, xhi = _extent_lo_hi(cal, true)
    ylo, yhi = _extent_lo_hi(cal, false)
    # Match Makie.update_axis_camera: orthographic bounds use apply_transform on limits.
    ax.aspect = Makie.AxisAspect(transformed_extent_aspect(cal, xlo, xhi, ylo, yhi))
    # Default Axis limits are (0, 10); log10 rejects 0. Set positive limits before scales.
    Makie.limits!(ax, xlo, xhi, ylo, yhi)
    if cal.x_log
        ax.xscale = log10
    end
    if cal.y_log
        ax.yscale = log10
    end
    imgp = Makie.image!(
        ax,
        (xlo, xhi),
        (ylo, yhi),
        mat;
        kwargs...,
    )
    if mark_calibration_points
        if cal.click_markers === nothing
            @warn "mark_calibration_points=true but cal.click_markers is nothing; skipping markers"
        else
            _plot_calibration_markers!(ax, cal.click_markers)
        end
    end
    return imgp
end
