immutable SVector{S, T} <: StaticVector{T}
    data::NTuple{S, T}
end

@inline (::Type{SVector}){S}(x::NTuple{S}) = SVector{S}(x)
@inline (::Type{SVector{S}}){S, T}(x::NTuple{S,T}) = SVector{S,T}(x)
@inline (::Type{SVector{S}}){S, T <: Tuple}(x::T) = SVector{S,promote_tuple_eltype(T)}(x)

# conversion from AbstractVector / AbstractArray (better inference than default)
#@inline convert{S,T}(::Type{SVector{S}}, a::AbstractArray{T}) = SVector{S,T}((a...))

# Some more advanced constructor-like functions
@inline zeros{N}(::Type{SVector{N}}) = zeros(SVector{N,Float64})
@inline ones{N}(::Type{SVector{N}}) = ones(SVector{N,Float64})

#####################
## SVector methods ##
#####################

@pure size{S}(::Union{SVector{S},Type{SVector{S}}}) = (S, )
@pure size{S,T}(::Type{SVector{S,T}}) = (S,)

@propagate_inbounds function getindex(v::SVector, i::Integer)
    v.data[i]
end

@inline Tuple(v::SVector) = v.data

@inline function Base.unsafe_convert{N,T}(::Type{Ptr{T}}, v::SVector{N,T})
    Base.unsafe_convert(Ptr{T}, Base.data_pointer_from_objref(v))
end


macro SVector(ex)
    if isa(ex, Expr) && ex.head == :vect
        return esc(Expr(:call, SVector{length(ex.args)}, Expr(:tuple, ex.args...)))
    elseif isa(ex, Expr) && ex.head == :ref
        return esc(Expr(:call, Expr(:curly, :SVector, length(ex.args[2:end]), ex.args[1]), Expr(:tuple, ex.args[2:end]...)))
    elseif isa(ex, Expr) && ex.head == :comprehension
        if length(ex.args) != 1 || !isa(ex.args[1], Expr) || ex.args[1].head != :generator
            error("Expected generator in comprehension, e.g. [f(i) for i = 1:3]")
        end
        ex = ex.args[1]
        if length(ex.args) != 2
            error("Use a one-dimensional comprehension for @SVector")
        end

        rng = eval(current_module(), ex.args[2].args[2])
        f = gensym()
        f_expr = :($f = ($(ex.args[2].args[1]) -> $(ex.args[1])))
        exprs = [:($f($j)) for j in rng]

        return quote
            $(Expr(:meta, :inline))
            $(esc(f_expr))
            $(esc(Expr(:call, Expr(:curly, :SVector, length(rng)), Expr(:tuple, exprs...))))
        end
    elseif isa(ex, Expr) && ex.head == :typed_comprehension
        if length(ex.args) != 2 || !isa(ex.args[2], Expr) || ex.args[2].head != :generator
            error("Expected generator in typed comprehension, e.g. Float64[f(i) for i = 1:3]")
        end
        T = ex.args[1]
        ex = ex.args[2]
        if length(ex.args) != 2
            error("Use a one-dimensional comprehension for @SVector")
        end

        rng = eval(current_module(), ex.args[2].args[2])
        f = gensym()
        f_expr = :($f = ($(ex.args[2].args[1]) -> $(ex.args[1])))
        exprs = [:($f($j)) for j in rng]

        return quote
            $(Expr(:meta, :inline))
            $(esc(f_expr))
            $(esc(Expr(:call, Expr(:curly, :SVector, length(rng), T), Expr(:tuple, exprs...))))
        end
    elseif isa(ex, Expr) && ex.head == :call
        if ex.args[1] == :zeros || ex.args[1] == :ones || ex.args[1] == :rand ||ex.args[1] == :randn
            if length(ex.args) == 2
                return quote
                    $(Expr(:meta, :inline))
                    $(esc(ex.args[1]))(SVector{$(esc(ex.args[2]))})
                end
            elseif length(ex.args) == 3
                return quote
                    $(Expr(:meta, :inline))
                    $(esc(ex.args[1]))(SVector{$(esc(ex.args[3])), $(esc(ex.args[2]))})
                end
            else
                error("@SVector expected a 1-dimensional array expression")
            end
        else
            error("@SVector only supports the zeros(), ones(), rand() and randn() functions.")
        end
    else # TODO Expr(:call, :zeros), Expr(:call, :ones), Expr(:call, :eye) ?
        error("Use @SVector [a,b,c], @SVector Type[a,b,c] or a comprehension like [f(i) for i = i_min:i_max]")
    end
end
