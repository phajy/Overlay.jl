using Overlay
using Images
using Test

@testset "rotr90 display: x_scale ↔ columns, y_scale ↔ rows (no x/y swap)" begin
    # Extreme aspect ratio so a transpose bug would be obvious.
    img = zeros(Float32, 17, 300)
    cal = calibration_from_clicks(;
        img_size = size(img),
        x_pixels = (0.0, 16.0),
        x_values = (0.0, 1.0),
        y_pixels = (0.0, 299.0),
        y_values = (0.0, 1.0),
    )
    mat = rotr90(img)
    @test size(mat, 2) == length(cal.x_scale) == cal.img_width
    @test size(mat, 1) == length(cal.y_scale) == cal.img_height
end

@testset "calibration_from_clicks + pixel transforms (linear)" begin
    cal = calibration_from_clicks(;
        img_size = (100, 50),
        x_pixels = (10.0, 90.0),
        x_values = (0.0, 10.0),
        y_pixels = (5.0, 45.0),
        y_values = (1.0, 5.0),
    )
    @test cal.img_width == 100
    @test cal.img_height == 50
    @test cal.aspect_ratio == 50 / 100
    @test !cal.x_log && !cal.y_log

    x, y = pixel_to_data_continuous(cal, 10.0, 5.0)
    @test x ≈ 0.0
    @test y ≈ 1.0

    x2, y2 = pixel_to_data_continuous(cal, 90.0, 45.0)
    @test x2 ≈ 10.0
    @test y2 ≈ 5.0

    px, py = data_to_pixel_continuous(cal, 0.0, 1.0)
    @test px ≈ 10.0
    @test py ≈ 5.0

    i, j = data_to_pixel(cal, 0.0, 1.0)
    x3, y3 = pixel_to_data(cal, i, j)
    @test x3 ≈ 0.0
    @test y3 ≈ 1.0

    @test length(x_data_coords(cal)) == 100
    @test x_data_coords(cal)[1] ≈ first(cal.x_scale)
end

@testset "transformed_extent_aspect matches Makie camera spans" begin
    cal = calibration_from_clicks(;
        img_size = (100, 50),
        x_pixels = (0.0, 99.0),
        x_values = (1.0, 100.0),
        y_pixels = (0.0, 49.0),
        y_values = (1.0, 5.0),
        x_log = true,
        y_log = false,
    )
    ar = transformed_extent_aspect(cal, 1.0, 100.0, 1.0, 5.0)
    @test ar ≈ (log10(100) - log10(1.0)) / (5.0 - 1.0) rtol = 1e-12
    cal2 = calibration_from_clicks(;
        img_size = (30, 40),
        x_pixels = (0.0, 29.0),
        x_values = (1.0, 10.0),
        y_pixels = (0.0, 39.0),
        y_values = (1.0, 100.0),
        x_log = true,
        y_log = true,
    )
    ar2 = transformed_extent_aspect(cal2, 1.0, 10.0, 1.0, 100.0)
    @test ar2 ≈ (log10(10) - log10(1.0)) / (log10(100) - log10(1.0)) rtol = 1e-12
end

@testset "log10 x-axis calibration" begin
    # px 10→1, px 90→100  =>  log10 spans 0..2 linearly in px
    cal = calibration_from_clicks(;
        img_size = (100, 50),
        x_pixels = (10.0, 90.0),
        x_values = (1.0, 100.0),
        y_pixels = (5.0, 45.0),
        y_values = (1.0, 5.0),
        x_log = true,
        y_log = false,
    )
    @test cal.x_log && !cal.y_log
    x, y = pixel_to_data_continuous(cal, 10.0, 5.0)
    @test x ≈ 1.0
    @test y ≈ 1.0
    x2, y2 = pixel_to_data_continuous(cal, 90.0, 45.0)
    @test x2 ≈ 100.0
    @test y2 ≈ 5.0
    # geometric mean at midpoint in log-x: px=50 → log10(x)=1 → x=10
    xm, ym = pixel_to_data_continuous(cal, 50.0, 5.0)
    @test xm ≈ 10.0
    @test ym ≈ 1.0
    px, py = data_to_pixel_continuous(cal, 10.0, 1.0)
    @test px ≈ 50.0 rtol = 1e-5
    @test py ≈ 5.0
    @test x_data_coords(cal)[1] ≈ exp10(first(cal.x_scale))
end

@testset "save_calibration / load_calibration (TOML default)" begin
    cal = calibration_from_clicks(;
        img_size = (20, 10),
        x_pixels = (0.0, 19.0),
        x_values = (-1.0, 1.0),
        y_pixels = (2.0, 8.0),
        y_values = (0.0, 3.0),
    )
    path = joinpath(@__DIR__, "tmp_calibration.toml")
    try
        save_calibration(path, cal)
        cal2 = load_calibration(path)
        @test cal2.img_width == cal.img_width
        @test cal2.img_height == cal.img_height
        @test cal2.x_log == cal.x_log
        @test cal2.y_log == cal.y_log
        @test collect(cal2.x_scale) ≈ collect(cal.x_scale)
        @test collect(cal2.y_scale) ≈ collect(cal.y_scale)
        @test cal2.click_markers === cal.click_markers === nothing
        @test occursin("Overlay.jl.calibration", read(path, String))
    finally
        isfile(path) && rm(path)
    end
end

@testset "save_calibration / load_calibration (Serialization legacy)" begin
    cal = calibration_from_clicks(;
        img_size = (20, 10),
        x_pixels = (0.0, 19.0),
        x_values = (-1.0, 1.0),
        y_pixels = (2.0, 8.0),
        y_values = (0.0, 3.0),
    )
    path = joinpath(@__DIR__, "tmp_calibration.overlayjl")
    try
        save_calibration(path, cal; format = :serialize)
        cal2 = load_calibration(path)
        @test cal2.img_width == cal.img_width
        @test collect(cal2.x_scale) == collect(cal.x_scale)
        @test collect(cal2.y_scale) == collect(cal.y_scale)
        @test cal2.click_markers === nothing
    finally
        isfile(path) && rm(path)
    end
end

@testset "click_markers (calibration_from_clicks)" begin
    cal = calibration_from_clicks(;
        img_size = (100, 50),
        x_pixels = (10.0, 90.0),
        x_values = (0.0, 10.0),
        y_pixels = (5.0, 45.0),
        y_values = (1.0, 5.0),
        x_click_py = (12.0, 40.0),
        y_click_px = (20.0, 80.0),
    )
    @test cal.click_markers !== nothing
    m = cal.click_markers::NTuple{4, Tuple{Float64, Float64}}
    x1, y1 = pixel_to_data_continuous(cal, 10.0, 12.0)
    @test m[1][1] ≈ x1 && m[1][2] ≈ y1
    x2, y2 = pixel_to_data_continuous(cal, 90.0, 40.0)
    @test m[2][1] ≈ x2 && m[2][2] ≈ y2
    x3, y3 = pixel_to_data_continuous(cal, 20.0, 5.0)
    @test m[3][1] ≈ x3 && m[3][2] ≈ y3
    x4, y4 = pixel_to_data_continuous(cal, 80.0, 45.0)
    @test m[4][1] ≈ x4 && m[4][2] ≈ y4

    cal_one = calibration_from_clicks(;
        img_size = (10, 10),
        x_pixels = (0.0, 9.0),
        x_values = (0.0, 1.0),
        y_pixels = (0.0, 9.0),
        y_values = (0.0, 1.0),
        x_click_py = (1.0, 2.0),
    )
    @test cal_one.click_markers === nothing
end

@testset "TOML save/load preserves click_markers and log axes" begin
    cal = calibration_from_clicks(;
        img_size = (30, 20),
        x_pixels = (1.0, 28.0),
        x_values = (1.0, 100.0),
        y_pixels = (2.0, 18.0),
        y_values = (0.1, 10.0),
        x_log = true,
        y_log = true,
        x_click_py = (5.0, 10.0),
        y_click_px = (8.0, 20.0),
    )
    @test cal.click_markers !== nothing
    path = joinpath(@__DIR__, "tmp_calibration_markers.toml")
    try
        save_calibration(path, cal)
        cal2 = load_calibration(path)
        @test cal2.x_log && cal2.y_log
        @test collect(cal2.x_scale) ≈ collect(cal.x_scale)
        @test collect(cal2.y_scale) ≈ collect(cal.y_scale)
        @test length(cal2.click_markers) == 4
        for i in 1:4
            @test cal2.click_markers[i][1] ≈ cal.click_markers[i][1]
            @test cal2.click_markers[i][2] ≈ cal.click_markers[i][2]
        end
    finally
        isfile(path) && rm(path)
    end
end

@testset "save_calibration rejects unknown format" begin
    cal = calibration_from_clicks(;
        img_size = (10, 10),
        x_pixels = (0.0, 9.0),
        x_values = (0.0, 1.0),
        y_pixels = (0.0, 9.0),
        y_values = (0.0, 1.0),
    )
    @test_throws ArgumentError save_calibration(tempname(), cal; format = :json)
end

@testset "calibration_from_clicks errors (pixels)" begin
    @test_throws ArgumentError calibration_from_clicks(;
        img_size = (10, 10),
        x_pixels = (1.0, 1.0),
        x_values = (0.0, 1.0),
        y_pixels = (0.0, 1.0),
        y_values = (0.0, 1.0),
    )
end

@testset "log axis requires positive values" begin
    @test_throws ArgumentError calibration_from_clicks(;
        img_size = (10, 10),
        x_pixels = (0.0, 9.0),
        x_values = (-1.0, 10.0),
        y_pixels = (0.0, 9.0),
        y_values = (1.0, 2.0),
        x_log = true,
    )
end

@testset "data_to_pixel rejects non-positive values on log axis" begin
    cal = calibration_from_clicks(;
        img_size = (10, 10),
        x_pixels = (0.0, 9.0),
        x_values = (1.0, 100.0),
        y_pixels = (0.0, 9.0),
        y_values = (1.0, 2.0),
        x_log = true,
    )
    @test_throws ArgumentError data_to_pixel(cal, -1.0, 1.0)
end

@testset "data_extents" begin
    cal = calibration_from_clicks(;
        img_size = (100, 50),
        x_pixels = (0.0, 99.0),
        x_values = (0.0, 10.0),
        y_pixels = (0.0, 49.0),
        y_values = (0.0, 1.0),
    )
    (xlo, xhi), (ylo, yhi) = data_extents(cal)
    @test xlo ≈ first(x_data_coords(cal))
    @test xhi ≈ last(x_data_coords(cal))
    @test ylo ≈ first(y_data_coords(cal))
    @test yhi ≈ last(y_data_coords(cal))

    cal_log = calibration_from_clicks(;
        img_size = (100, 50),
        x_pixels = (0.0, 99.0),
        x_values = (1.0, 100.0),
        y_pixels = (0.0, 49.0),
        y_values = (0.1, 10.0),
        x_log = true,
        y_log = true,
    )
    (xlo2, xhi2), (ylo2, yhi2) = data_extents(cal_log)
    # Extents are extrapolated to full image edges, not the click values.
    @test xlo2 ≈ first(x_data_coords(cal_log))
    @test xhi2 ≈ last(x_data_coords(cal_log))
    @test ylo2 ≈ first(y_data_coords(cal_log))
    @test yhi2 ≈ last(y_data_coords(cal_log))
    @test xlo2 ≤ 1.0 ≤ xhi2
    @test ylo2 ≤ 0.1 ≤ yhi2
end

@testset "calibrated_plot_attrs" begin
    cal = calibration_from_clicks(;
        img_size = (100, 50),
        x_pixels = (0.0, 99.0),
        x_values = (0.0, 10.0),
        y_pixels = (0.0, 49.0),
        y_values = (0.0, 1.0),
    )
    attrs = calibrated_plot_attrs(cal)
    (xlo, xhi), (ylo, yhi) = data_extents(cal)
    @test attrs.xlims == (xlo, xhi)
    @test attrs.ylims == (ylo, yhi)
    @test attrs.xscale === :identity
    @test attrs.yscale === :identity
    @test attrs.widen === false
    # Displayed (rotr90) grid: W_vis = img_height, H_vis = img_width
    Tx_Ty = transformed_extent_aspect(cal, xlo, xhi, ylo, yhi)
    @test attrs.aspect_ratio ≈ Tx_Ty * (cal.img_width / cal.img_height)

    cal_log = calibration_from_clicks(;
        img_size = (100, 50),
        x_pixels = (0.0, 99.0),
        x_values = (1.0, 100.0),
        y_pixels = (0.0, 49.0),
        y_values = (0.1, 10.0),
        x_log = true,
        y_log = true,
    )
    attrs_log = calibrated_plot_attrs(cal_log)
    @test attrs_log.xscale === :log10
    @test attrs_log.yscale === :log10
end

@testset "calibrated_heatmap_data orientation matches Makie rotr90" begin
    # Images-style array: dim1 = visual rows (top→bottom), dim2 = visual cols (left→right).
    H, W = 6, 10
    img = [RGB{Float32}(i / H, j / W, 0) for i in 1:H, j in 1:W]
    img[1, 1] = RGB{Float32}(1, 0, 0)       # visual TL
    img[1, W] = RGB{Float32}(0, 1, 0)       # visual TR
    img[H, 1] = RGB{Float32}(0, 0, 1)       # visual BL
    img[H, W] = RGB{Float32}(1, 1, 0)       # visual BR

    cal = calibration_from_clicks(;
        img_size = size(img),
        x_pixels = (0.0, Float64(H - 1)),
        x_values = (0.0, 10.0),
        y_pixels = (0.0, Float64(W - 1)),
        y_values = (0.0, 1.0),
    )
    xs, ys, z = calibrated_heatmap_data(img, cal)
    @test size(z) == (length(ys), length(xs))
    @test size(z) == size(permutedims(rotr90(img)))
    # Plots: row 1 = bottom when yflip=false → BL, BR, TL, TR
    @test z[1, 1] == img[H, 1]          # BL blue
    @test z[1, end] == img[H, W]        # BR yellow
    @test z[end, 1] == img[1, 1]        # TL red
    @test z[end, end] == img[1, W]      # TR green
    @test first(xs) ≈ first(data_extents(cal)[1])
    @test last(xs) ≈ last(data_extents(cal)[1])
    @test_throws ArgumentError calibrated_heatmap_data(zeros(RGB{Float32}, 2, 2), cal)
end
