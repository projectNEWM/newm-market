def sort_lexicographically(*args):
    """
    Sorts the given strings in lexicographical order.

    Args:
    *args: Strings to be sorted.

    Returns:
    A list of strings sorted in lexicographical order.
    """
    return sorted(args)


def get_index_in_order(ordered_list, item):
    """
    Returns the index of the given item in the ordered list.

    Args:
    ordered_list: A list of strings sorted in lexicographical order.
    item: The string whose index is to be found.

    Returns:
    The index of the item in the ordered list.
    """
    try:
        return ordered_list.index(item)
    except ValueError:
        return -1  # Return -1 if the item is not found


if __name__ == "__main__":
    # Define the strings
    x = "9ac0928f338ec0c4f5ae1275fe6517881a9c842c07720097ffc4f5fb82975dc1#0"
    y = "a4c1747f2a6dea8f307f4846dab721798f141aeb156cb24221c5671548e6cf7e#0"
    z = "a1133d386f47a72edd05d964540fe9763552685ca9ffbf07b26770766d063009#0"

    # Get the ordered list of strings
    ordered_list = sort_lexicographically(x, y, z)

    # Print the ordered list
    print("Ordered list:", ordered_list)

    # Get and print the index of each string
    index_x = get_index_in_order(ordered_list, x)
    index_y = get_index_in_order(ordered_list, y)
    index_z = get_index_in_order(ordered_list, z)

    print(f"Index of x: {index_x}")
    print(f"Index of y: {index_y}")
    print(f"Index of z: {index_z}")
