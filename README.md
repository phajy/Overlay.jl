# Overlay

[![Build Status](https://github.com/phajy/Overlay.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/phajy/Overlay.jl/actions/workflows/CI.yml?query=branch%3Amain)

```julia
using Overlay
using Images
using Plots

img = load("test_plot.png")
(x_scale, y_scale, ar) = calibrate_image(img)
plot(x_scale, y_scale, reverse(img, dims = 1), yflip = false, aspect_ratio = ar)
```
