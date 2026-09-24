"""Shared vocabulary for the dex tables.

Every row is one car at one generation, written in a fixed order so the tables
stay narrow enough to read down a column. The order is:

    model, year, rarity, body, tint,
    series, production, engine, hp, torque, drive, gearbox,
    0-60, top speed, weight, seats, msrp, fuel

`year` is the model year of the exact car the entry depicts, not a guess and not
the first year of the nameplate. `production` is the run of that generation.
A zero means the figure is not published or not known well enough to print, and
the app leaves the row out rather than showing a zero.
"""

# Paint palette, kept small so a wall of cards stays calm.
RED, ORANGE, YELLOW = 0xD8232A, 0xFF6A00, 0xE8B93B
GREEN, LIME, TEAL = 0x1F6E4E, 0x8CE24B, 0x1FA88F
BLUE, NAVY, STEEL = 0x2F6BFF, 0x1D3557, 0x3B7FB5
PURPLE, CYAN, BRONZE = 0x6B2FA8, 0x2E6E8E, 0x9B8C6E
WHITE, SILVER, PEARL = 0xE8E8EE, 0xB9BEC7, 0xD9DDE4
GREY, BLACK, GUN = 0x4A4F58, 0x1B1B22, 0x2B2B33

# Rarity
L, X, R, U, C = "legendary", "exotic", "rare", "uncommon", "common"

# Body
SPORT, SEDAN, SUV = "sports", "sedan", "suv"
TRUCK, COUPE, HATCH, CONV = "truck", "coupe", "hatch", "convertible"

# Drivetrain
FWD, RWD, AWD, FOUR = "fwd", "rwd", "awd", "four"

# What it burns
GAS, HYB, PHEV, EV, DSL = "gas", "hybrid", "plugin", "electric", "diesel"

# Common gearboxes, so the strings stay consistent across nine hundred rows.
M4, M5, M6, M7 = "4-sp manual", "5-sp manual", "6-sp manual", "7-sp manual"
A3, A4, A5, A6, A7, A8, A9, A10 = (
    "3-sp auto", "4-sp auto", "5-sp auto", "6-sp auto", "7-sp auto",
    "8-sp auto", "9-sp auto", "10-sp auto",
)
D6, D7, D8, D9 = "6-sp DCT", "7-sp DCT", "8-sp DCT", "9-sp DCT"
CVT = "CVT"
EV1 = "1-sp reduction"
EV2 = "2-sp reduction"

FIELDS = (
    "model year rarity body tint series production engine power torque "
    "drive gearbox sprint top_speed weight seats msrp fuel"
).split()

RARITIES = {L, X, R, U, C}
BODIES = {SPORT, SEDAN, SUV, TRUCK, COUPE, HATCH, CONV}
DRIVES = {FWD, RWD, AWD, FOUR}
FUELS = {GAS, HYB, PHEV, EV, DSL}


def C_(model, year, rarity, body, tint,
       series, production, engine, power, torque, drive, gearbox,
       sprint, top_speed, weight, seats, msrp, fuel):
    """One car. Positional on purpose: a missing value is a TypeError naming
    the row rather than a silently shifted column."""
    assert rarity in RARITIES, f"{model}: bad rarity {rarity}"
    assert body in BODIES, f"{model}: bad body {body}"
    assert drive in DRIVES, f"{model}: bad drive {drive}"
    assert fuel in FUELS, f"{model}: bad fuel {fuel}"
    assert isinstance(year, str) and len(year) == 4, f"{model}: bad year {year}"
    return dict(zip(FIELDS, (
        model, year, rarity, body, tint, series, production, engine,
        power, torque, drive, gearbox, sprint, top_speed, weight, seats, msrp, fuel,
    )))
