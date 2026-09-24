"""Hypercars, low volume specials and the tuner houses.

Figures are the manufacturer's own claims where they exist, which is the only
honest source for cars built in the dozens. Where a maker never published a
number it is left at zero and the app drops the row.
"""

from .base import *

DATA = {
    "Bugatti": [
        C_("Chiron", "2021", L, SPORT, BLUE, "", "2016-2022", "8.0L quad-turbo W16", 1479, 1180, AWD, D7, 2.4, 261, 4400, 2, 2990000, GAS),
        C_("Chiron Super Sport", "2023", L, SPORT, BLACK, "", "2021-2024", "8.0L quad-turbo W16", 1577, 1180, AWD, D7, 2.3, 273, 4400, 2, 3900000, GAS),
        C_("Divo", "2020", L, SPORT, SILVER, "", "2018-2021", "8.0L quad-turbo W16", 1479, 1180, AWD, D7, 2.4, 236, 4400, 2, 5800000, GAS),
        C_("Centodieci", "2022", L, SPORT, WHITE, "", "2021-2022", "8.0L quad-turbo W16", 1577, 1180, AWD, D7, 2.4, 236, 4400, 2, 9000000, GAS),
        C_("Bolide", "2025", L, SPORT, YELLOW, "", "2024-2026", "8.0L quad-turbo W16", 1578, 1180, AWD, D7, 2.2, 236, 3196, 2, 4700000, GAS),
        C_("Veyron", "2011", L, SPORT, NAVY, "16.4", "2005-2015", "8.0L quad-turbo W16", 1001, 922, AWD, D7, 2.5, 253, 4162, 2, 1700000, GAS),
        C_("Veyron Super Sport", "2012", L, SPORT, BLACK, "16.4", "2010-2015", "8.0L quad-turbo W16", 1184, 1106, AWD, D7, 2.4, 268, 4045, 2, 2400000, GAS),
        C_("EB110 GT", "1993", L, SPORT, BLUE, "EB110", "1991-1995", "3.5L quad-turbo V12", 553, 451, AWD, M6, 3.4, 213, 3571, 2, 350000, GAS),
        C_("Tourbillon", "2026", L, SPORT, PEARL, "", "2026-present", "8.3L NA V16 plus 3 motors", 1775, 664, AWD, D8, 2.0, 276, 4400, 2, 4100000, PHEV),
        C_("Mistral", "2024", L, CONV, YELLOW, "", "2024-2025", "8.0L quad-turbo W16", 1577, 1180, AWD, D7, 2.3, 282, 4400, 2, 5000000, GAS),
    ],
    "Koenigsegg": [
        C_("Jesko", "2023", L, SPORT, WHITE, "", "2022-present", "5.0L twin-turbo V8", 1280, 1106, RWD, "9-sp LST", 2.5, 300, 3131, 2, 3000000, GAS),
        C_("Jesko Absolut", "2024", L, SPORT, SILVER, "", "2023-present", "5.0L twin-turbo V8", 1600, 1106, RWD, "9-sp LST", 2.5, 330, 3131, 2, 3400000, GAS),
        C_("Regera", "2020", L, SPORT, SILVER, "", "2016-2022", "5.0L twin-turbo V8 plus 3 motors", 1500, 1475, RWD, "Direct drive", 2.7, 250, 3510, 2, 1900000, PHEV),
        C_("Gemera", "2025", L, COUPE, GREEN, "", "2025-present", "5.0L twin-turbo V8 plus 3 motors", 2300, 1997, AWD, "9-sp LST", 1.9, 250, 4189, 4, 1700000, PHEV),
        C_("Agera RS", "2017", L, SPORT, BLACK, "", "2015-2018", "5.0L twin-turbo V8", 1160, 944, RWD, D7, 2.6, 278, 3075, 2, 2500000, GAS),
        C_("One:1", "2015", L, SPORT, BLACK, "", "2014-2015", "5.0L twin-turbo V8", 1341, 1011, RWD, D7, 2.6, 273, 2998, 2, 2850000, GAS),
        C_("CCX", "2008", L, SPORT, ORANGE, "", "2006-2010", "4.7L supercharged V8", 806, 678, RWD, M6, 3.2, 245, 2601, 2, 695000, GAS),
        C_("CC850", "2025", L, SPORT, ORANGE, "", "2024-present", "5.0L twin-turbo V8", 1385, 1022, RWD, "9-sp LST", 2.5, 250, 3417, 2, 3650000, GAS),
    ],
    "Pagani": [
        C_("Huayra", "2016", L, SPORT, BRONZE, "", "2012-2018", "6.0L twin-turbo V12", 730, 738, RWD, "7-sp AMT", 3.0, 238, 2976, 2, 1300000, GAS),
        C_("Huayra BC", "2019", L, SPORT, GREY, "", "2016-2020", "6.0L twin-turbo V12", 789, 811, RWD, "7-sp AMT", 2.8, 238, 2685, 2, 2600000, GAS),
        C_("Zonda", "2006", L, SPORT, SILVER, "C12", "1999-2011", "7.3L NA V12", 602, 575, RWD, M6, 3.5, 214, 2755, 2, 667000, GAS),
        C_("Utopia", "2024", L, SPORT, RED, "", "2023-present", "6.0L twin-turbo V12", 852, 811, RWD, M7, 2.8, 217, 2822, 2, 2500000, GAS),
        C_("Huayra R", "2023", L, SPORT, WHITE, "", "2021-present", "6.0L NA V12", 838, 553, RWD, "6-sp seq", 2.7, 217, 2315, 1, 3100000, GAS),
    ],
    "Rimac": [
        C_("Nevera", "2023", L, SPORT, NAVY, "", "2022-present", "Four permanent magnet motors", 1914, 1741, AWD, EV1, 1.8, 258, 5070, 2, 2400000, EV),
        C_("Nevera R", "2025", L, SPORT, BLACK, "", "2025-present", "Four permanent magnet motors", 2107, 1741, AWD, EV1, 1.7, 268, 4938, 2, 2600000, EV),
        C_("Concept One", "2016", L, SPORT, BLACK, "", "2013-2016", "Four permanent magnet motors", 1224, 1180, AWD, EV1, 2.5, 221, 4079, 2, 1000000, EV),
    ],
    "Pininfarina": [
        C_("Battista", "2024", L, SPORT, BRONZE, "", "2022-present", "Four permanent magnet motors", 1877, 1725, AWD, EV1, 1.8, 217, 4938, 2, 2200000, EV),
    ],
    "Aspark": [
        C_("Owl", "2023", L, SPORT, BLACK, "", "2020-present", "Four permanent magnet motors", 1980, 1475, AWD, EV1, 1.7, 249, 4188, 2, 3200000, EV),
    ],
    "Hispano Suiza": [
        C_("Carmen Boulogne", "2023", L, COUPE, NAVY, "", "2022-present", "Two rear axial flux motors", 1114, 811, RWD, EV1, 2.6, 180, 3792, 2, 1900000, EV),
    ],
    "Hennessey": [
        C_("Venom F5", "2023", L, SPORT, BLUE, "", "2021-present", "6.6L twin-turbo V8", 1817, 1193, RWD, "7-sp semi-auto", 2.6, 271, 3053, 2, 2100000, GAS),
        C_("Venom GT", "2014", L, SPORT, SILVER, "", "2011-2017", "7.0L twin-turbo V8", 1244, 1155, RWD, M6, 2.7, 270, 2743, 2, 1200000, GAS),
    ],
    "SSC": [
        C_("Tuatara", "2022", L, SPORT, WHITE, "", "2020-present", "5.9L twin-turbo V8", 1750, 1280, RWD, "7-sp AMT", 2.5, 283, 2750, 2, 1900000, GAS),
    ],
    "Czinger": [
        C_("21C", "2024", L, SPORT, SILVER, "", "2023-present", "2.9L twin-turbo V8 plus 2 motors", 1250, 811, AWD, "7-sp seq", 1.9, 253, 2932, 2, 2000000, PHEV),
    ],
    "Gordon Murray": [
        C_("T.50", "2024", L, SPORT, PEARL, "", "2022-present", "3.9L NA V12", 654, 344, RWD, M6, 2.8, 226, 2174, 3, 2600000, GAS),
        C_("T.33", "2025", L, COUPE, SILVER, "", "2024-present", "3.9L NA V12", 607, 332, RWD, M6, 2.9, 200, 2403, 2, 1850000, GAS),
    ],
    "De Tomaso": [
        C_("P72", "2025", L, SPORT, BRONZE, "", "2025-present", "5.0L supercharged V8", 700, 605, RWD, M6, 3.0, 210, 2866, 2, 1000000, GAS),
        C_("Pantera GTS", "1974", L, COUPE, YELLOW, "", "1971-1992", "5.8L NA V8", 350, 333, RWD, M5, 5.5, 159, 3200, 2, 10000, GAS),
    ],
    "Apollo": [
        C_("Intensa Emozione", "2019", L, SPORT, BLACK, "IE", "2018-present", "6.3L NA V12", 780, 561, RWD, "6-sp seq", 2.7, 208, 2755, 2, 2700000, GAS),
    ],
    "Zenvo": [
        C_("TSR-S", "2021", L, SPORT, RED, "", "2019-present", "5.8L twin-supercharged V8", 1177, 811, RWD, "7-sp seq", 2.8, 202, 3306, 2, 1900000, GAS),
        C_("Aurora Agil", "2026", L, SPORT, WHITE, "", "2026-present", "6.6L quad-turbo V12 plus motor", 1450, 1030, RWD, "7-sp DCT", 2.3, 280, 3197, 2, 2900000, PHEV),
    ],
    "Noble": [
        C_("M600", "2016", L, SPORT, SILVER, "", "2010-present", "4.4L twin-turbo V8", 650, 604, RWD, M6, 3.0, 225, 2755, 2, 250000, GAS),
    ],
    "Saleen": [
        C_("S7", "2006", L, SPORT, RED, "S7", "2000-2009", "7.0L twin-turbo V8", 750, 700, RWD, M6, 2.8, 248, 2865, 2, 585000, GAS),
    ],
    "TVR": [
        C_("Sagaris", "2006", L, COUPE, RED, "", "2005-2006", "4.0L NA I6", 406, 349, RWD, M5, 3.7, 185, 2403, 2, 95000, GAS),
        C_("Griffith 500", "1996", R, CONV, YELLOW, "", "1991-2002", "5.0L NA V8", 320, 320, RWD, M5, 4.1, 167, 2313, 2, 45000, GAS),
    ],
    "Morgan": [
        C_("Plus Six", "2023", X, CONV, GREEN, "", "2019-present", "3.0L turbo I6", 335, 369, RWD, A8, 4.2, 166, 2500, 2, 110000, GAS),
        C_("Plus Four", "2024", R, CONV, BLUE, "", "2020-present", "2.0L turbo I4", 255, 295, RWD, A8, 4.8, 149, 2200, 2, 78000, GAS),
    ],
    "Caterham": [
        C_("Seven 620R", "2022", X, SPORT, YELLOW, "", "2013-present", "2.0L supercharged I4", 310, 219, RWD, "6-sp seq", 2.8, 155, 1213, 2, 85000, GAS),
        C_("Seven 170", "2024", R, SPORT, BLUE, "", "2021-present", "0.66L turbo I3", 84, 86, RWD, M5, 6.9, 105, 970, 2, 33000, GAS),
    ],
    "Ariel": [
        C_("Atom 4", "2023", X, SPORT, LIME, "", "2018-present", "2.0L turbo I4", 320, 310, RWD, M6, 2.8, 162, 1350, 2, 90000, GAS),
        C_("Nomad", "2022", R, SPORT, ORANGE, "", "2015-present", "2.4L NA I4", 235, 221, RWD, M6, 3.4, 125, 1477, 2, 78000, GAS),
    ],
    "BAC": [
        C_("Mono R", "2023", X, SPORT, ORANGE, "", "2019-present", "2.5L NA I4", 343, 227, RWD, "6-sp seq", 2.7, 170, 1213, 1, 240000, GAS),
    ],
    "Ultima": [
        C_("RS", "2023", X, SPORT, BLACK, "", "2019-present", "6.2L supercharged V8", 1200, 900, RWD, M6, 2.3, 250, 2200, 2, 130000, GAS),
    ],
    "Rezvani": [
        C_("Beast", "2022", X, SPORT, ORANGE, "", "2015-present", "2.5L supercharged I4", 700, 500, RWD, M6, 2.7, 180, 1650, 2, 325000, GAS),
        C_("Tank", "2024", X, SUV, BLACK, "", "2018-present", "6.2L supercharged V8", 1000, 850, FOUR, A10, 3.9, 150, 6500, 5, 259000, GAS),
    ],
    "RUF": [
        C_("CTR Yellowbird", "1987", L, SPORT, YELLOW, "", "1987-1989", "3.4L twin-turbo flat-6", 469, 408, RWD, M5, 3.6, 211, 2359, 2, 223000, GAS),
        C_("CTR Anniversary", "2020", L, SPORT, YELLOW, "", "2019-present", "3.6L twin-turbo flat-6", 700, 649, RWD, M6, 3.5, 224, 2640, 2, 1000000, GAS),
    ],
    "Brabus": [
        C_("G800", "2024", X, SUV, BLACK, "W463A", "2019-present", "4.0L twin-turbo V8", 800, 737, FOUR, A9, 4.1, 149, 5940, 5, 400000, GAS),
        C_("Rocket 900", "2023", X, SEDAN, BLACK, "", "2021-present", "4.5L twin-turbo V8", 900, 774, AWD, A9, 2.8, 205, 4960, 4, 500000, GAS),
    ],
    "Alpina": [
        C_("B7", "2022", X, SEDAN, NAVY, "G12", "2020-2022", "4.4L twin-turbo V8", 600, 590, AWD, A8, 3.5, 205, 4784, 5, 143000, GAS),
        C_("XB7", "2023", X, SUV, BLACK, "G07", "2021-present", "4.4L twin-turbo V8", 630, 590, AWD, A8, 4.0, 180, 5820, 7, 148000, GAS),
    ],
    "Lucid": [
        C_("Air Sapphire", "2024", X, SEDAN, BLACK, "", "2024-present", "Three permanent magnet motors", 1234, 1430, AWD, EV1, 1.9, 205, 5386, 5, 249000, EV),
        C_("Air Dream", "2023", R, SEDAN, PEARL, "", "2021-2023", "Two permanent magnet motors", 1111, 1025, AWD, EV1, 2.5, 168, 5236, 5, 169000, EV),
        C_("Air Pure", "2025", R, SEDAN, SILVER, "", "2023-present", "Single rear motor", 430, 406, RWD, EV1, 4.5, 145, 4564, 5, 70000, EV),
        C_("Gravity", "2025", R, SUV, SILVER, "", "2025-present", "Two permanent magnet motors", 828, 0, AWD, EV1, 3.4, 155, 5900, 7, 95000, EV),
    ],
}
