"""
    save_calibration(path::AbstractString, cal::ImageCalibration)

Serialize [`ImageCalibration`](@ref) to `path` using Julia's `Serialization` standard library.
The file format is Julia-specific (not portable to other languages).

See also [`load_calibration`](@ref).
"""
function save_calibration(path::AbstractString, cal::ImageCalibration)
    return open(path, "w") do io
        return Serialization.serialize(io, cal)
    end
end

"""
    load_calibration(path::AbstractString) -> ImageCalibration

Load a calibration written by [`save_calibration`](@ref).
"""
function load_calibration(path::AbstractString)
    return open(path, "r") do io
        return Serialization.deserialize(io)::ImageCalibration
    end
end
