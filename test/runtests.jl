using jlfmt
using Test

@testset "jlfmt" begin
    @test jlfmt.main(["--help"]) === nothing
end
