"""
    ImageCalibration

Result of calibrating a raster image to data coordinates.

# Fields
- `x_scale`, `y_scale`: `AbstractRange` of length `img_width` / `img_height`, **uniform along
  pixel index** in *transform space*: for a **linear** axis this equals data *x* / *y*; for a
  **log** axis (base 10, matching typical log tick labels) it equals `log10` of positive data values.
- `x_log`, `y_log`: whether each axis uses log10 spacing (`true`) or linear spacing (`false`).
- `aspect_ratio`: pixel aspect ratio `img_height / img_width`.
- `img_width`, `img_height`: same as `size(img)` for the raw image.
- `click_markers`: `nothing`, or four `(x, y)` tuples in **data** space for the calibration clicks
  (first x pick, second x pick, first y pick, second y pick). Populated when building via
  [`calibration_from_clicks`](@ref) with `x_click_py` / `y_click_px` (e.g. from [`calibrate_image`](@ref));
  older saved calibrations may have `nothing`, in which case [`plot_calibrated_image!`](@ref) cannot draw markers.

Use `pixel_to_data` / `data_to_pixel` for coordinates in **data** space,
`x_data_coords` / `y_data_coords` for vectors aligned to pixels for plotting,
`save_calibration` / `load_calibration` to persist.
"""
struct ImageCalibration{Rx<:AbstractRange,Ry<:AbstractRange}
    x_scale::Rx
    y_scale::Ry
    x_log::Bool
    y_log::Bool
    aspect_ratio::Float64
    img_width::Int
    img_height::Int
    click_markers::Union{Nothing, NTuple{4, Tuple{Float64, Float64}}}
end

function Base.show(io::IO, cal::ImageCalibration)
    xf = float(first(cal.x_scale))
    xl = float(last(cal.x_scale))
    yf = float(first(cal.y_scale))
    yl = float(last(cal.y_scale))
    xd0 = cal.x_log ? exp10(xf) : xf
    xd1 = cal.x_log ? exp10(xl) : xl
    yd0 = cal.y_log ? exp10(yf) : yf
    yd1 = cal.y_log ? exp10(yl) : yl
    return print(
        io,
        "ImageCalibration(",
        cal.img_width,
        "×",
        cal.img_height,
        ", x",
        cal.x_log ? " (log10)" : "",
        "∈[",
        xd0,
        ", ",
        xd1,
        "], y",
        cal.y_log ? " (log10)" : "",
        "∈[",
        yd0,
        ", ",
        yd1,
        "])",
    )
end
