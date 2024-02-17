using Overlay
using Test

@testset "Overlay.jl" begin
    # Write your tests here.
    @test Overlay.greet_overlay() == "Hello Overlay!"
    @test Overlay.greet_overlay() != "Hello world!"
end
