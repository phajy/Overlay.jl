module Overlay

using Serialization
using Images
using GLMakie
using Makie

include("types.jl")
include("geometry.jl")
include("io.jl")
include("interactive.jl")
include("makie_plot.jl")

export ImageCalibration
export calibration_from_clicks
export calibrate_image
export x_data_coords
export y_data_coords
export pixel_to_data
export pixel_to_data_continuous
export data_to_pixel
export data_to_pixel_continuous
export transformed_extent_aspect
export save_calibration
export load_calibration
export plot_calibrated_image!

end
