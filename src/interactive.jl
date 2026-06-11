function _read_float(prompt::AbstractString)
    while true
        print(prompt)
        line = readline()
        v = tryparse(Float64, line)
        if v !== nothing
            return v
        end
        println("Could not parse that as a Float64; please enter a number (e.g. 1.5 or -2).")
    end
end

function _read_axis_log(name::AbstractString)
    while true
        print("Is the ", name, "-axis linear or log10? Type 'linear' or 'log' [linear]: ")
        line = strip(lowercase(readline()))
        isempty(line) && return false
        if line in ("linear", "lin")
            return false
        end
        if line in ("log", "log10", "lg")
            return true
        end
        println("Please enter 'linear' or 'log' (blank defaults to linear).")
    end
end

function _get_click(f, pos_label::AbstractString)
    println("Click for ", pos_label, " (left mouse button).")
    clicked = Ref(false)
    px = Ref(0.0)
    py = Ref(0.0)
    listener = on(events(f).mousebutton) do event
        if event.button == Mouse.left && event.action == Mouse.press
            mp = events(f).mouseposition[]
            px[] = Float64(mp[1])
            py[] = Float64(mp[2])
            clicked[] = true
            println("Recorded click at (", px[], ", ", py[], ").")
        end
        return nothing
    end
    while !clicked[]
        sleep(0.05)
    end
    off(listener)
    value = _read_float(string("Data-axis value for ", pos_label, " = "))
    return (px[], py[], value)
end

"""
    calibrate_image(img; title = "Calibrate: two x, then two y")

Interactively calibrate a 2D image (e.g. from [`Images.load`](@ref)).

Opens a **GLMakie** window (often behind the IDE). Order of prompts:

1. **x₀** — known data **x**, then type that **x** (must be **positive** if you choose a log x-axis).
2. **x₁** — second known **x**.
3. Whether the figure’s **x**-axis is **linear** or **log10** (typical printed log axes).
4. **y₀** / **y₁** — same for **y** (values must be **positive** if you choose log **y**).
5. Whether the **y**-axis is linear or log10.

Log axes assume pixel position is affine in `log10(data)` along that direction (standard log plot).

Returns an [`ImageCalibration`](@ref).

# Notes
- Requires a graphical display (not headless CI/SSH without forwarding).
- Calibration matches raw `img` indexing as returned by `size(img)`; the window uses `rotr90` for display only.
"""
function calibrate_image(img; title::AbstractString = "Calibrate: two x, then two y")
    GLMakie.activate!(; inline = false)
    img_w, img_h = size(img)

    f = Figure()
    image(f[1, 1], rotr90(img); axis = (aspect = DataAspect(), title = title))
    display(f)

    r = f.content[1].scene.viewport.val
    o_x = Float64(r.origin[1])
    o_y = Float64(r.origin[2])
    w = Float64(r.widths[1])
    h = Float64(r.widths[2])

    println()
    println("--- Overlay.jl calibration ---")
    println("Step 1/4: first known x position")
    x_0 = _get_click(f, "x_0")
    println("Step 2/4: second known x position")
    x_1 = _get_click(f, "x_1")
    x_log = _read_axis_log("x")
    if x_log && (x_0[3] <= 0 || x_1[3] <= 0)
        throw(
            ArgumentError(
                "log x-axis requires positive calibration values; got x₀ = $(x_0[3]), x₁ = $(x_1[3])",
            ),
        )
    end
    println("Step 3/4: first known y position")
    y_0 = _get_click(f, "y_0")
    println("Step 4/4: second known y position")
    y_1 = _get_click(f, "y_1")
    y_log = _read_axis_log("y")
    if y_log && (y_0[3] <= 0 || y_1[3] <= 0)
        throw(
            ArgumentError(
                "log y-axis requires positive calibration values; got y₀ = $(y_0[3]), y₁ = $(y_1[3])",
            ),
        )
    end

    x_0_px = img_w * (x_0[1] - o_x) / w
    x_1_px = img_w * (x_1[1] - o_x) / w
    y_0_px = img_h * (y_0[2] - o_y) / h
    y_1_px = img_h * (y_1[2] - o_y) / h

    return calibration_from_clicks(;
        img_size = (img_w, img_h),
        x_pixels = (x_0_px, x_1_px),
        x_values = (x_0[3], x_1[3]),
        y_pixels = (y_0_px, y_1_px),
        y_values = (y_0[3], y_1[3]),
        x_log = x_log,
        y_log = y_log,
    )
end
