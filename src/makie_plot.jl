"""
    plot_calibrated_image!(ax, img, cal::ImageCalibration; kwargs...)

Plot `img` on Makie axis `ax` with the same rotation as interactive calibration (`rotr90`),
using **data-space** extents. If `cal.x_log` / `cal.y_log`, sets `xscale` / `yscale` to `log10`.

Extra `kwargs` are forwarded to `Makie.image!`.
"""
function plot_calibrated_image!(ax, img, cal::ImageCalibration; kwargs...)
    xlo = cal.x_log ? exp10(float(first(cal.x_scale))) : float(first(cal.x_scale))
    xhi = cal.x_log ? exp10(float(last(cal.x_scale))) : float(last(cal.x_scale))
    ylo = cal.y_log ? exp10(float(first(cal.y_scale))) : float(first(cal.y_scale))
    yhi = cal.y_log ? exp10(float(last(cal.y_scale))) : float(last(cal.y_scale))
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
        rotr90(img);
        kwargs...,
    )
end
