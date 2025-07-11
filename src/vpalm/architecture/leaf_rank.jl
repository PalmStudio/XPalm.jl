"""
    compute_leaf_rank(nb_internodes, index_leaf)

Compute the rank of a leaf based on the total number of internodes and the index of the leaf.

# Arguments

- `nb_internodes`: The total number of internodes until leaf of rank 1.
- `index_leaf`: The index of the leaf.
- `leaves_in_sheath`: The number of leaves in the sheath, i.e. with rank < 1 (default is 0).

# Note

This is a simple leaf rank, not considering the leaves of rank <= 0.

# Returns 

The leaf rank, i.e. 1 for the first opened leaf, 2 for the second leaf, etc.
"""
compute_leaf_rank(nb_internodes, index_leaf, leaves_in_sheath=0) = nb_internodes - index_leaf + 1 - leaves_in_sheath