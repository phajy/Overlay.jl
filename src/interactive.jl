function _yield_until_display!(f; n::Int = 30)
    for _ in 1:n
        yield()
    end
    return nothing
end

"""Give GLMakie a moment after a mouse click so `focus!` on the textbox receives keyboard input."""
function _focus_textbox_for_input!(tb::Makie.Textbox)
    yield()
    yield()
    sleep(0.06)
    Makie.focus!(tb)
    yield()
    Makie.focus!(tb)
    return nothing
end

function _wait_left_click_on_axis!(f, ax, instr::Makie.Label, message::AbstractString)
    instr.text[] = string(message, " — left-click **on the image**.")
    ch = Channel{Tuple{Float64, Float64}}(1)
    tok = on(events(f).mousebutton) do event
        event.button == Mouse.left && event.action == Mouse.press || return Consume(false)
        Makie.is_mouseinside(ax.scene) || return Consume(false)
        mp = events(f).mouseposition[]
        put!(ch, (Float64(mp[1]), Float64(mp[2])))
        return Consume(false)
    end
    px, py = take!(ch)
    off(tok)
    return px, py
end

function _wait_float_textbox!(tb::Makie.Textbox, instr::Makie.Label, message::AbstractString)
    instr.text[] = message
    Makie.reset!(tb)
    ch = Channel{Float64}(1)
    tok_ref = Ref{Any}(nothing)
    tok_ref[] = on(tb.stored_string) do s
        s === nothing && return nothing
        v = tryparse(Float64, s)
        v === nothing && return nothing
        off(tok_ref[])
        put!(ch, v)
        return nothing
    end
    _focus_textbox_for_input!(tb)
    v = take!(ch)
    Makie.reset!(tb)
    return v
end

function _wait_axis_log!(instr::Makie.Label, btn_lin::Makie.Button, btn_log::Makie.Button, axis_name::AbstractString)
    instr.text[] = string(
        "Choose **", axis_name, "**-axis spacing (log₁₀ = tick labels spaced by decades on the figure).",
    )
    n0 = btn_lin.clicks[]
    m0 = btn_log.clicks[]
    while true
        yield()
        sleep(0.02)
        if btn_lin.clicks[] > n0
            return false
        end
        if btn_log.clicks[] > m0
            return true
        end
    end
end

const _DEFAULT_CALIBRATE_FIGSIZE = (1000, 780)

"""
    calibrate_image(img; title = "Calibrate: two x, then two y", figsize = (1000, 780))

Interactively calibrate a 2D image (e.g. from [`Images.load`](@ref)).

Opens a **GLMakie** window (often behind the IDE). All steps use the **figure** only: short
instructions in a label, numeric values in a **text box** (type the number, press **Enter**),
and **linear** / **log₁₀** axis mode via two **buttons** — no REPL `readline`, so the event
loop is not fighting the terminal (which used to make the first value prompt easy to miss).

Order:

1. **x₀** — left-click a known **x** on the image, then enter that **x** in the text box (must be **positive** if you choose log **x**).
2. **x₁** — same for a second **x**.
3. **x scale** — press **linear** or **log₁₀**.
4. **y₀** / **y₁** — same for **y** (values must be **positive** if you choose log **y**).
5. **y scale** — **linear** or **log₁₀**.

Log axes assume pixel position is affine in `log10(data)` along that direction (standard log plot).

Returns an [`ImageCalibration`](@ref).

# Arguments
- `figsize::Tuple{Integer, Integer}`: figure size in pixels `(width, height)` for the GLMakie window (named `figsize` so it does not shadow `Base.size` on `img`).

# Notes
- Requires a graphical display (not headless CI/SSH without forwarding).
- Calibration matches raw `img` indexing as returned by `size(img)`; the window uses `rotr90` for display only.
"""
function calibrate_image(
    img;
    title::AbstractString = "Calibrate: two x, then two y",
    figsize::Tuple{Integer, Integer} = _DEFAULT_CALIBRATE_FIGSIZE,
)
    GLMakie.activate!(; inline = false)
    img_w, img_h = size(img)

    # Single root column (buttons live in a nested grid) so the image is not squeezed to ~half
    # width. Do *not* use `rowsize!(..., Aspect(...))` with full column width: row height would be
    # `width * img_w/img_h`, which often exceeds the window and clips the plot and instructions.
    # Row 1 is greedy `Auto(1)`; `DataAspect()` letterboxes inside that cell so everything fits.
    f = Makie.Figure(; size = figsize, figure_padding = 4)
    f.layout.halign = :center
    f.layout.valign = :center
    Makie.colsize!(f.layout, 1, Makie.Relative(1f0))
    Makie.rowsize!(f.layout, 1, Makie.Auto(1f0))
    Makie.rowgap!(f.layout, 4)
    ax = Makie.Axis(
        f[1, 1];
        aspect = Makie.DataAspect(),
        title = title,
        titlegap = 4,
    )
    Makie.hidedecorations!(ax)
    Makie.hidespines!(ax)
    Makie.image!(ax, rotr90(img))
    instr = Makie.Label(
        f[2, 1],
        "Calibration";
        tellwidth = true,
        halign = :left,
        justification = :left,
        word_wrap = true,
    )
    # Instructions are in `instr` above; avoid a second hint here. A bare empty string breaks
    # Makie's cursor/label layout (no glyph boxes), so use a single space as a neutral placeholder.
    tb = Makie.Textbox(
        f[3, 1];
        width = Makie.Relative(1f0),
        tellwidth = false,
        halign = :left,
        placeholder = " ",
        validator = Float64,
        defocus_on_submit = true,
        reset_on_defocus = false,
    )
    btn_gl = Makie.GridLayout(f[4, 1]; halign = :left)
    btn_lin = Makie.Button(btn_gl[1, 1]; label = "linear")
    btn_log = Makie.Button(btn_gl[1, 2]; label = "log₁₀")

    display(f)
    _yield_until_display!(f)

    r = ax.scene.viewport[]
    o_x = Float64(r.origin[1])
    o_y = Float64(r.origin[2])
    w = Float64(r.widths[1])
    h = Float64(r.widths[2])

    px0, py0 = _wait_left_click_on_axis!(f, ax, instr, "Step 1/4: first known **x** position")
    x0 = _wait_float_textbox!(
        tb,
        instr,
        "Enter the **data x** value at that point (then Enter).",
    )
    px1, py1 = _wait_left_click_on_axis!(f, ax, instr, "Step 2/4: second known **x** position")
    x1 = _wait_float_textbox!(
        tb,
        instr,
        "Enter the **data x** value at the second point (then Enter).",
    )
    x_log = _wait_axis_log!(instr, btn_lin, btn_log, "x")
    if x_log && (x0 <= 0 || x1 <= 0)
        throw(
            ArgumentError(
                "log x-axis requires positive calibration values; got x₀ = $x0, x₁ = $x1",
            ),
        )
    end

    px2, py2 = _wait_left_click_on_axis!(f, ax, instr, "Step 3/4: first known **y** position")
    y0 = _wait_float_textbox!(
        tb,
        instr,
        "Enter the **data y** value at that point (then Enter).",
    )
    px3, py3 = _wait_left_click_on_axis!(f, ax, instr, "Step 4/4: second known **y** position")
    y1 = _wait_float_textbox!(
        tb,
        instr,
        "Enter the **data y** value at the second point (then Enter).",
    )
    y_log = _wait_axis_log!(instr, btn_lin, btn_log, "y")
    if y_log && (y0 <= 0 || y1 <= 0)
        throw(
            ArgumentError(
                "log y-axis requires positive calibration values; got y₀ = $y0, y₁ = $y1",
            ),
        )
    end

    instr.text[] = "Done — you can close the window."

    x_0_px = img_w * (px0 - o_x) / w
    x_1_px = img_w * (px1 - o_x) / w
    y_0_px = img_h * (py2 - o_y) / h
    y_1_px = img_h * (py3 - o_y) / h

    y_px_at_x0 = img_h * (py0 - o_y) / h
    y_px_at_x1 = img_h * (py1 - o_y) / h
    x_px_at_y0 = img_w * (px2 - o_x) / w
    x_px_at_y1 = img_w * (px3 - o_x) / w

    return calibration_from_clicks(;
        img_size = (img_w, img_h),
        x_pixels = (x_0_px, x_1_px),
        x_values = (x0, x1),
        y_pixels = (y_0_px, y_1_px),
        y_values = (y0, y1),
        x_log = x_log,
        y_log = y_log,
        x_click_py = (y_px_at_x0, y_px_at_x1),
        y_click_px = (x_px_at_y0, x_px_at_y1),
    )
end
