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
            "XPalm input `$(input_name)` and distributed output group " *
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
