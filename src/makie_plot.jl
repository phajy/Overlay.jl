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

"""
    plot_calibrated_image!(ax, img, cal::ImageCalibration; kwargs...)

Plot `img` on Makie axis `ax` with the same rotation as interactive calibration (`rotr90`),
using **data-space** extents. If `cal.x_log` / `cal.y_log`, sets `xscale` / `yscale` to `log10`.

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

Extra `kwargs` are forwarded to `Makie.image!`.
"""
function plot_calibrated_image!(ax, img, cal::ImageCalibration; kwargs...)
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
    return Makie.image!(
        ax,
        (xlo, xhi),
        (ylo, yhi),
        mat;
        kwargs...,
    )
end
