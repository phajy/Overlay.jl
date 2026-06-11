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
