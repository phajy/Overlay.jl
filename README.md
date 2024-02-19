# Overlay

[![Build Status](https://github.com/phajy/Overlay.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/phajy/Overlay.jl/actions/workflows/CI.yml?query=branch%3Amain)

Example usage:

```julia
using Overlay
using Images
using Plots

# load an image
img = load("test_plot.png")
# calibrate the image scale
(x_scale, y_scale, ar) = calibrate_image(img)
# plot the image with this scale
plot(x_scale, y_scale, reverse(img, dims = 1), yflip = false, aspect_ratio = ar)
# overplot something of interest to compare to the backgorund image
plot!(1.5*rand(10), rand(10), seriestype = :scatter)
```

When you call `calibrate_image` you will be asked to click on four points, $x_0$, $x_1$, $y_0$, and $y_1$. An interactive image should appear in a `GLMakie` window. Note that this can appear behind your IDE window. It is assumed that the image does not need to be rotated and the axes have linear scales. Once you've calibrated your image you'll get an array of $x$ and $y$ values that you can use in, e.g., `Plots.jl` to overlay a plot on top of the image. The aspect ratio is stored in `ar` although I'm not certain that is working properly at the moment.

Once the image is calibrated you can plot it as shown in the example above, and then overlay anything you want to compare with this background image.
