@inline function _tf_to_data(tf::Float64, log_axis::Bool)
    return log_axis ? exp10(tf) : tf
end

function _data_to_tf(d::Float64, log_axis::Bool)
    if log_axis
        d > 0 || throw(ArgumentError("log-scaled axis requires positive data values (got $d)"))
        return log10(d)
    end
    return d
end

"""
    transformed_extent_aspect(cal::ImageCalibration, xlo, xhi, ylo, yhi) -> Float64

Return `Tx / Ty`, the width-to-height ratio of the axis limits in the **same transformed
coordinates** Makie uses for the 2D axis camera (`log10` span when an axis is log, linear
span otherwise).

Use this with `AxisAspect(...)` when plotting so the layout viewport matches the camera’s
orthographic bounds; using only the pixel count ratio `ncols/nrows` can stretch the figure
when `Tx/Ty` differs from that ratio (often visible as a slight vertical or horizontal skew).
"""
function transformed_extent_aspect(cal::ImageCalibration, xlo, xhi, ylo, yhi)
    tx0 = _data_to_tf(Float64(xlo), cal.x_log)
    tx1 = _data_to_tf(Float64(xhi), cal.x_log)
    ty0 = _data_to_tf(Float64(ylo), cal.y_log)
    ty1 = _data_to_tf(Float64(yhi), cal.y_log)
    Tx = abs(tx1 - tx0)
    Ty = abs(ty1 - ty0)
    Ty > 0 || throw(ArgumentError("degenerate y-axis extent after transform (Ty = 0)"))
    return Tx / Ty
end

function _linear_range_from_clicks(px0::Real, px1::Real, t0::Real, t1::Real, n::Int)
    if px1 ≈ px0
        throw(ArgumentError("calibration: pixel positions are too close ($(px0), $(px1))"))
    end
    Δ = (t1 - t0) / (px1 - px0)
    zero = t0 - px0 * Δ
    endv = zero + Δ * n
    return range(Float64(zero), Float64(endv); length = n)
end

"""
    calibration_from_clicks(;
        img_size, x_pixels, x_values, y_pixels, y_values,
        x_log = false, y_log = false,
        x_click_py = nothing, y_click_px = nothing,
    )

Build an [`ImageCalibration`](@ref) from two known **x** and two known **y** positions in **pixel space**.

# Keyword arguments
- `x_log`, `y_log`: if `true`, that axis is **log10** in the figure (pixel position is affine in
  `log10(data)`). Calibration values must be **positive** for a log axis.
- `x_click_py`: optional `(ypx₁, ypx₂)` — raw-image **continuous** y-pixel coordinates at the two
  **x** calibration clicks (same convention as [`pixel_to_data_continuous`](@ref), typically in
  `[0, img_height]`).
- `y_click_px`: optional `(xpx₁, xpx₂)` — raw-image **continuous** x-pixel coordinates at the two
  **y** calibration clicks (typically in `[0, img_width]`).

When both are provided, `click_markers` on the returned [`ImageCalibration`](@ref) stores four
`(x, y)` data-space points for overlays (e.g. [`plot_calibrated_image!`](@ref) with
`mark_calibration_points=true`).

Transform space along each index is linear: for a log axis, `x_scale[i]` is `log10` of the data
`x` at column `i`; use [`pixel_to_data`](@ref) or [`x_data_coords`](@ref) for data-space values.

This function is pure and testable; interactive calibration uses the same math.
"""
function calibration_from_clicks(;
    img_size::Tuple{Int,Int},
    x_pixels::Tuple{Real,Real},
    x_values::Tuple{Real,Real},
    y_pixels::Tuple{Real,Real},
    y_values::Tuple{Real,Real},
    x_log::Bool = false,
    y_log::Bool = false,
    x_click_py::Union{Nothing, Tuple{Real, Real}} = nothing,
    y_click_px::Union{Nothing, Tuple{Real, Real}} = nothing,
)
    img_w, img_h = img_size
    x0_px, x1_px = x_pixels
    x0_val, x1_val = x_values
    y0_px, y1_px = y_pixels
    y0_val, y1_val = y_values

    xt0 = _data_to_tf(Float64(x0_val), x_log)
    xt1 = _data_to_tf(Float64(x1_val), x_log)
    yt0 = _data_to_tf(Float64(y0_val), y_log)
    yt1 = _data_to_tf(Float64(y1_val), y_log)

    x_scale = _linear_range_from_clicks(x0_px, x1_px, xt0, xt1, img_w)
    y_scale = _linear_range_from_clicks(y0_px, y1_px, yt0, yt1, img_h)
    ar = Float64(img_h) / Float64(img_w)
    markers = _click_markers_data_xy(
        x_scale,
        y_scale,
        x_log,
        y_log,
        ar,
        img_w,
        img_h,
        x_pixels,
        y_pixels,
        x_click_py,
        y_click_px,
    )
    return ImageCalibration(x_scale, y_scale, x_log, y_log, ar, img_w, img_h, markers)
end

function _click_markers_data_xy(
    x_scale,
    y_scale,
    x_log::Bool,
    y_log::Bool,
    ar::Float64,
    img_w::Int,
    img_h::Int,
    x_pixels::Tuple{Real, Real},
    y_pixels::Tuple{Real, Real},
    x_click_py,
    y_click_px,
)
    if x_click_py === nothing || y_click_px === nothing
        return nothing
    end
    cal0 = ImageCalibration(x_scale, y_scale, x_log, y_log, ar, img_w, img_h, nothing)
    xpx0, xpx1 = Float64(x_pixels[1]), Float64(x_pixels[2])
    ypx0, ypx1 = Float64(y_pixels[1]), Float64(y_pixels[2])
    y_at_x0, y_at_x1 = Float64(x_click_py[1]), Float64(x_click_py[2])
    x_at_y0, x_at_y1 = Float64(y_click_px[1]), Float64(y_click_px[2])
    return (
        pixel_to_data_continuous(cal0, xpx0, y_at_x0),
        pixel_to_data_continuous(cal0, xpx1, y_at_x1),
        pixel_to_data_continuous(cal0, x_at_y0, ypx0),
        pixel_to_data_continuous(cal0, x_at_y1, ypx1),
    )
end

"""
    x_data_coords(cal::ImageCalibration)

Vector of length `img_width`: data-space **x** at each column (for heatmaps / `plot`).

For a log **x** axis, values are positive and grow exponentially across the image width.
"""
function x_data_coords(cal::ImageCalibration)
    if cal.x_log
        return [exp10(Float64(v)) for v in cal.x_scale]
    end
    return collect(Float64, cal.x_scale)
end

"""
    y_data_coords(cal::ImageCalibration)

Vector of length `img_height`: data-space **y** at each row (for heatmaps / `plot`).
"""
function y_data_coords(cal::ImageCalibration)
    if cal.y_log
        return [exp10(Float64(v)) for v in cal.y_scale]
    end
    return collect(Float64, cal.y_scale)
end

function _interp_axis(r::AbstractRange, n::Int, t::Real)
    n < 1 && throw(ArgumentError("length must be positive"))
    n == 1 && return float(first(r))
    tt = clamp(t, one(t), float(n))
    s = (tt - 1) / (n - 1)
    return (1 - s) * float(first(r)) + s * float(last(r))
end

"""
    pixel_to_data(cal::ImageCalibration, i::Real, j::Real)

Map **1-based fractional** image indices to data `(x, y)` (linear or log axis in data space).
"""
function pixel_to_data(cal::ImageCalibration, i::Real, j::Real)
    tx = _interp_axis(cal.x_scale, cal.img_width, i)
    ty = _interp_axis(cal.y_scale, cal.img_height, j)
    x = _tf_to_data(tx, cal.x_log)
    y = _tf_to_data(ty, cal.y_log)
    return (x, y)
end

function _inverse_axis(r::AbstractRange, n::Int, v::Real)
    f = float(first(r))
    l = float(last(r))
    n == 1 && return 1.0
    denom = l - f
    abs(denom) < eps(Float64) * max(abs(f), abs(l), 1) &&
        throw(ArgumentError("degenerate axis range: cannot invert"))
    s = (float(v) - f) / denom
    return 1 + s * (n - 1)
end

"""
    data_to_pixel(cal::ImageCalibration, x::Real, y::Real)

Inverse of [`pixel_to_data`](@ref): return `(i, j)` as floats in 1-based index space.
"""
function data_to_pixel(cal::ImageCalibration, x::Real, y::Real)
    tx = _data_to_tf(Float64(x), cal.x_log)
    ty = _data_to_tf(Float64(y), cal.y_log)
    i = _inverse_axis(cal.x_scale, cal.img_width, tx)
    j = _inverse_axis(cal.y_scale, cal.img_height, ty)
    return (i, j)
end

"""
    pixel_to_data_continuous(cal::ImageCalibration, px::Real, py::Real)

Like [`pixel_to_data`](@ref), with `px`, `py` in `[0, img_width]` × `[0, img_height]` (continuous
pixel frame used after mapping viewport clicks).
"""
function pixel_to_data_continuous(cal::ImageCalibration, px::Real, py::Real)
    w, h = cal.img_width, cal.img_height
    i = w <= 1 ? one(px) : 1 + px * (w - 1) / w
    j = h <= 1 ? one(py) : 1 + py * (h - 1) / h
    return pixel_to_data(cal, i, j)
end

"""
    data_to_pixel_continuous(cal::ImageCalibration, x::Real, y::Real)

Inverse of [`pixel_to_data_continuous`](@ref): returns `(px, py)` in `[0, img_width]` × `[0, img_height]`.
"""
function data_to_pixel_continuous(cal::ImageCalibration, x::Real, y::Real)
    i, j = data_to_pixel(cal, x, y)
    w, h = cal.img_width, cal.img_height
    px = w <= 1 ? 0.0 : (i - 1) * w / (w - 1)
    py = h <= 1 ? 0.0 : (j - 1) * h / (h - 1)
    return (px, py)
end
