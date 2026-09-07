@inline function _aligned_object_ids(left, right)
    length(left) == length(right) || return false
    axes(left) == axes(right) || return false
    @inbounds for index in eachindex(left, right)
        left[index] == right[index] || return false
    end
    return true
end

@inline function _sum_with_initial(values, initial::T) where {T}
    value_type = eltype(values)
    value_type === Any && return _sum_with_initial_any(values, initial)
    return _sum_with_initial_as(
        values,
        initial,
        promote_type(T, value_type),
    )
end

@inline function _sum_with_initial_as(values, initial, ::Type{T}) where {T}
    total = convert(T, initial)
    @inbounds for index in eachindex(values)
        total += convert(T, values[index])
    end
    return total
end

@inline function _sum_with_initial_any(values, initial::T) where {T}
    isempty(values) && return initial
    value_type = T
    @inbounds for index in eachindex(values)
        value_type = promote_type(value_type, typeof(values[index]))
    end
    return _sum_with_initial_as(values, initial, value_type)
end

@noinline function _throw_output_id_alignment_error(
    input_name::Symbol,
    output_name::Symbol,
    input_ids,
    output_ids,
)
    throw(
        ArgumentError(
            "XPalm input `$(input_name)` and distributed output " *
            "`$(output_name)` must contain the same ObjectId values in the " *
            "same order; got $(length(input_ids)) input object(s) and " *
            "$(length(output_ids)) output target(s).",
        ),
    )
end

@inline function _require_aligned_object_ids(
    input_name::Symbol,
    output_name::Symbol,
    input_ids,
    output_ids,
)
    _aligned_object_ids(input_ids, output_ids) ||
        _throw_output_id_alignment_error(
            input_name,
            output_name,
            input_ids,
            output_ids,
        )
    return nothing
end


# These collective kernels publish both organ values and their plant total.
# The destination selector includes the plant; the numerical organ loops use
# this view to omit it without copying values or assuming any ObjectId order.
struct _WithoutIndex{T,V<:AbstractVector{T}} <: AbstractVector{T}
    values::V
    excluded::Int
end

Base.IndexStyle(::Type{<:_WithoutIndex}) = IndexLinear()
Base.size(values::_WithoutIndex) = (length(values.values) - 1,)
@inline function Base.getindex(values::_WithoutIndex, index::Int)
    @boundscheck checkbounds(values, index)
    @inbounds return values.values[index + (index >= values.excluded)]
end
@inline function Base.setindex!(values::_WithoutIndex, value, index::Int)
    @boundscheck checkbounds(values, index)
    @inbounds values.values[index + (index >= values.excluded)] = value
    return value
end

@inline function _organ_output_view(targets, context, ::Val{variable}) where {variable}
    ids = PlantSimEngine.object_ids(targets)
    plant_id = PlantSimEngine.object_id(context)
    plant_index = findfirst(==(plant_id), ids)
    isnothing(plant_index) && throw(ArgumentError(
        "XPalm distributed output `$(variable)` must include the execution plant " *
        "$(plant_id) as well as its organs so that its plant total is published.",
    ))
    return (
        ids=_WithoutIndex(ids, plant_index),
        values=_WithoutIndex(getproperty(targets.columns, variable), plant_index),
        plant_index=plant_index,
    )
end
