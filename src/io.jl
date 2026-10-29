const _CALIBRATION_FORMAT = "Overlay.jl.calibration"
const _CALIBRATION_FORMAT_VERSION = 1

"""
    save_calibration(path::AbstractString, cal::ImageCalibration; format=:toml)

Persist [`ImageCalibration`](@ref) to `path`.

# Keyword arguments
- `format`: `:toml` (default) writes a versioned, human-readable TOML file (recommended);
  `:serialize` writes Julia’s binary `Serialization` format (legacy; may not load across
  package versions when `ImageCalibration` fields change).

See also [`load_calibration`](@ref).
"""
function save_calibration(
    path::AbstractString,
    cal::ImageCalibration;
    format::Symbol = :toml,
)
    if format === :toml
        return _save_calibration_toml(path, cal)
    elseif format === :serialize
        return open(path, "w") do io
            return Serialization.serialize(io, cal)
        end
    else
        throw(ArgumentError("unknown calibration format $(repr(format)); use :toml or :serialize"))
    end
end

function _save_calibration_toml(path::AbstractString, cal::ImageCalibration)
    dict = Dict{String, Any}(
        "format" => _CALIBRATION_FORMAT,
        "format_version" => _CALIBRATION_FORMAT_VERSION,
        "img_width" => cal.img_width,
        "img_height" => cal.img_height,
        "x_log" => cal.x_log,
        "y_log" => cal.y_log,
        "x_scale" => Dict{String, Any}(
            "start" => Float64(first(cal.x_scale)),
            "stop" => Float64(last(cal.x_scale)),
        ),
        "y_scale" => Dict{String, Any}(
            "start" => Float64(first(cal.y_scale)),
            "stop" => Float64(last(cal.y_scale)),
        ),
    )
    if cal.click_markers !== nothing
        dict["click_markers"] = [[x, y] for (x, y) in cal.click_markers]
    end
    open(path, "w") do io
        println(io, "# Overlay.jl image calibration (TOML)")
        TOML.print(io, dict)
    end
    return nothing
end

"""
    load_calibration(path::AbstractString) -> ImageCalibration

Load a calibration written by [`save_calibration`](@ref).

Auto-detects **TOML** (preferred) vs legacy Julia **Serialization** by inspecting the file
contents. TOML files must declare `format = "Overlay.jl.calibration"` and a supported
`format_version`.
"""
function load_calibration(path::AbstractString)
    bytes = read(path)
    if _looks_like_toml_calibration(bytes)
        return _load_calibration_toml(String(bytes))
    end
    return Serialization.deserialize(IOBuffer(bytes))::ImageCalibration
end

function _looks_like_toml_calibration(bytes::Vector{UInt8})
    isempty(bytes) && return false
    # Binary Serialization typically starts with non-text protocol bytes.
    n = min(length(bytes), 512)
    text = String(bytes[1:n])
    return occursin(_CALIBRATION_FORMAT, text) || occursin("format_version", text)
end

function _load_calibration_toml(text::AbstractString)
    dict = TOML.parse(text)
    fmt = get(dict, "format", nothing)
    fmt == _CALIBRATION_FORMAT ||
        throw(ArgumentError("not an Overlay.jl calibration TOML (format=$(repr(fmt)))"))
    ver = Int(get(dict, "format_version", -1))
    ver == _CALIBRATION_FORMAT_VERSION || throw(
        ArgumentError(
            "unsupported calibration format_version $ver (this package supports $_CALIBRATION_FORMAT_VERSION)",
        ),
    )
    img_w = Int(dict["img_width"])
    img_h = Int(dict["img_height"])
    x_log = Bool(dict["x_log"])
    y_log = Bool(dict["y_log"])
    xs = dict["x_scale"]
    ys = dict["y_scale"]
    x_scale = range(Float64(xs["start"]), Float64(xs["stop"]); length = img_w)
    y_scale = range(Float64(ys["start"]), Float64(ys["stop"]); length = img_h)
    ar = Float64(img_h) / Float64(img_w)
    markers = _parse_click_markers(get(dict, "click_markers", nothing))
    return ImageCalibration(x_scale, y_scale, x_log, y_log, ar, img_w, img_h, markers)
end

function _parse_click_markers(raw)
    raw === nothing && return nothing
    length(raw) == 4 || throw(ArgumentError("click_markers must have exactly 4 points (got $(length(raw)))"))
    return ntuple(4) do i
        pt = raw[i]
        length(pt) == 2 || throw(ArgumentError("click_markers[$i] must be [x, y]"))
        (Float64(pt[1]), Float64(pt[2]))
    end
end
