// Contains common bit / byte manipulation functions

// Counts number of true bits in a given uint (Hamming weight)
uint count_number_true_bits(uint x)
{
    x = x - ((x >> 1u) & 0x55555555u);
    x = (x & 0x33333333u) + ((x >> 2u) & 0x33333333u);
    x = (x + (x >> 4u)) & 0x0F0F0F0Fu;
    x = x + (x >> 8u);
    x = x + (x >> 16u);
    return x & 0x3Fu; // Mask last 6 bits (max value 32)
}

uint create_single_bit_bitmask_from_child_index(uint index)
{
	return 1u << index;
}

// Return if a given index (0-7 inclusive) is contained by the given bitmask
bool is_index_contained_by_bitmask(uint index, uint bitmask)
{
	return (bitmask & (1u << index)) != 0u;
}