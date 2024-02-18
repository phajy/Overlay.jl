function greet_overlay()
    return "Hello Overlay!"
end

function get_click(f ,pos)
    println("Click on ", pos)
    m_x = 0
    m_y = 0
    
    listener = on(events(f).mousebutton) do event
        if event.button == Mouse.left && event.action == Mouse.press
            mp = events(f).mouseposition[]
            m_x = mp[1]
            m_y = mp[2]
            println("Got click at ", m_x, ", ", m_y)
        end
    end

    while (m_x == 0 && m_y == 0)
        sleep(0.1)
    end

    off(listener)
    # ask user to type in the value
    print("Value of ", pos, " = ")
    value = parse(Float64, readline())
    return (m_x, m_y, value)
end

function calibrate_image(img)
    GLMakie.activate!(inline=false)
    # img = testimage("lighthouse")
    # get image dimensions
    (img_w, img_h) = size(img)

    # display the passed image
    f = Figure()
    image(f[1, 1], rotr90(img), axis = (aspect = DataAspect(), title = "Image"))
    sc = display(f) # <-- not sure if we need this
    
    # get the origin, width, and height of the image in axes coordinates
    r = f.content[1].scene.viewport.val
    o_x = r.origin[1]
    o_y = r.origin[2]
    w = r.widths[1]
    h = r.widths[2]

    # ask user to click on the origin
    println("Click on a known x-position")

    # listener = on(f.scene.events.mouseposition) do mousepos
        # println("Mouse position: ", mousepos)
        # sleep(1)
    # end

    x_0 = get_click(f, "x_0")
    x_1 = get_click(f, "x_1")
    y_0 = get_click(f, "y_0")
    y_1 = get_click(f, "y_1")

    println(x_0)
    println(x_1)
    println(y_0)
    println(y_1)

    # calculate the scale
    x_0_px = img_w*(x_0[1]-o_x)/(w)
    println("x_0_px = ", x_0_px)
    x_1_px = img_w*(x_1[1]-o_x)/(w)
    println("x_1_px = ", x_1_px)
    Δx = (x_1[3] - x_0[3]) / (x_1_px - x_0_px)
    zero_x = x_0[3] - x_0_px * Δx
    end_x = zero_x + Δx * img_w
    y_0_px = img_h*(y_0[2]-o_y)/(h)
    y_1_px = img_h*(y_1[2]-o_y)/(h)
    Δy = (y_1[3] - y_0[3]) / (y_1_px - y_0_px)
    zero_y = y_0[3] - y_0_px * Δy
    end_y = zero_y + Δy * img_h

    x_scale = range(zero_x, end_x, length=img_w)
    y_scale = range(zero_y, end_y, length=img_h)

    ar = img_h/img_w
    return (x_scale, y_scale, ar)
end

# img = load("test_plot.png")
# (x_scale, y_scale, ar) = calibrate_image(img)
# plot(x_scale, y_scale, reverse(img, dims = 1), yflip = false, aspect_ratio = ar)
