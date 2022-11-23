
struct Root{T,S}
    length::T
    type::S
end

struct TapRoot end
struct LateralRoot end

r = Root(20.4, TapRoot())

function f(r::Root{Float64,TapRoot})
    println("Root of length $(r.length) and type $(r.type)")
end

function f(r::Root{Float64,LateralRoot})
    println("This is a lateral root of length $(r.length) and type $(r.type)")
end

r = Root(20.4, LateralRoot())
add_root(r)
