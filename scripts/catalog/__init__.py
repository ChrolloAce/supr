"""The dex tables, split by region so each file stays readable.

`ALL` is one dict of make -> [row], merged from every region module. A make may
appear in more than one file; the lists are concatenated in import order.
"""

from . import america, britain, germany, hyper, italy, japan, world

MODULES = (hyper, italy, germany, britain, japan, america, world)

ALL = {}
for module in MODULES:
    for make, rows in module.DATA.items():
        ALL.setdefault(make, []).extend(rows)
