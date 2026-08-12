import itertools
import os

from ruamel.yaml import YAML, Loader, add_constructor, add_multi_constructor, Constructor
from ruamel.yaml.constructor import ConstructorError

from wwrando_paths import DATA_PATH

WEIGHTS_PATH = os.path.join(DATA_PATH, "random_settings_weights.yml")
EXCLUDED_LOCATIONS_PATH = os.path.join(DATA_PATH, "default_excluded_locations.txt")


def flatten(loader: Loader, node):
    """Flattens one layer of a list of T|list[T]"""
    parsed_node = loader.construct_sequence(node)
    return list(itertools.chain.from_iterable(
        (item,) if not isinstance(item, list) else item
        for item in parsed_node
    ))

import logic.item_types
EXPOSED_CONSTANTS={
    "logic.item_types.DUNGEON_NONPROGRESS_ITEMS": tuple(logic.item_types.DUNGEON_NONPROGRESS_ITEMS)
}
def construct_constant(loader: Loader, suffix, node):
    if suffix not in EXPOSED_CONSTANTS:
        raise ConstructorError("While constructing a python name",
                               node.start_mark,
                               f"name is not in allowlist: {node!r}",
                               node.start_mark)
    return EXPOSED_CONSTANTS[suffix]


yaml = YAML(typ="safe")
add_multi_constructor('tag:yaml.org,2002:python/name:', construct_constant, constructor=yaml.constructor)
add_constructor('tag:yaml.org,2002:python/tuple', Constructor.construct_python_tuple, constructor=yaml.constructor)
add_constructor('!flatten', flatten, constructor=yaml.constructor)

def load_data_files(file=WEIGHTS_PATH):
    with open(file) as f:
        # Imports to be made available as references in the yaml files

        data = yaml.load(f)

    # Ensure all section names can be used as enum fields
    assert all(ident.isidentifier() for ident in data.keys())
    return data


# Locations that are excluded from holding progress items by default.
# Kept as a data file rather than inline so it can be referenced from the weights yaml as well as
# being the default value of the excluded_locations option.
# Must be registered in EXPOSED_CONSTANTS before load_data_files() runs, or the reference in the
# weights yaml fails to construct.
with open(EXCLUDED_LOCATIONS_PATH) as f:
    DEFAULT_EXCLUDED_LOCATIONS: list[str] = yaml.load(f)

# Registered as a list, not a tuple: excluded_locations is a list[str] option, and the weights file
# type-checks choices with isinstance(value, list).
EXPOSED_CONSTANTS["options.randomized.data.DEFAULT_EXCLUDED_LOCATIONS"] = DEFAULT_EXCLUDED_LOCATIONS

WEIGHT_DATA = load_data_files()

RANDOM_SETTINGS_PRESETS = {
    ident: entry.get("name", ident)
    for ident, entry in sorted(WEIGHT_DATA.items(), key=lambda t: t[1].get("display_order", len(WEIGHT_DATA) + 2))
}
