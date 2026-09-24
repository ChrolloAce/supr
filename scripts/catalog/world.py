"""Korea, Scandinavia, France, eastern Europe, China, India and Australia."""

from .base import *

DATA = {
    "Hyundai": [
        C_("Ioniq 5 N", "2025", R, HATCH, BLUE, "NE", "2024-present", "Two motors", 641, 568, AWD, EV2, 3.2, 161, 4861, 5, 67000, EV),
        C_("Elantra N", "2023", R, SEDAN, BLUE, "CN7", "2021-present", "2.0L turbo I4", 276, 289, FWD, D8, 5.0, 155, 3300, 5, 34000, GAS),
        C_("Veloster N", "2022", R, HATCH, BLUE, "JS", "2018-2022", "2.0L turbo I4", 275, 260, FWD, D8, 5.3, 155, 3200, 4, 33000, GAS),
        C_("Ioniq 5", "2023", U, HATCH, PEARL, "NE", "2021-present", "Two motors", 320, 446, AWD, EV1, 4.5, 115, 4662, 5, 52000, EV),
        C_("Ioniq 6", "2024", U, SEDAN, STEEL, "CE", "2022-present", "Two motors", 320, 446, AWD, EV1, 4.9, 115, 4462, 5, 53000, EV),
        C_("Ioniq 9", "2026", R, SUV, NAVY, "ME", "2025-present", "Two motors", 422, 516, AWD, EV1, 5.2, 112, 6000, 7, 60000, EV),
        C_("Elantra", "2022", C, SEDAN, CYAN, "CN7", "2020-present", "2.0L NA I4", 147, 132, FWD, CVT, 8.4, 118, 2800, 5, 22000, GAS),
        C_("Sonata", "2022", C, SEDAN, GREY, "DN8", "2019-present", "2.5L NA I4", 191, 181, FWD, A8, 7.9, 130, 3200, 5, 26000, GAS),
        C_("Tucson", "2022", C, SUV, SILVER, "NX4", "2021-present", "2.5L NA I4", 187, 178, AWD, A8, 8.8, 120, 3600, 5, 28000, GAS),
        C_("Santa Fe", "2023", C, SUV, WHITE, "TM", "2018-2023", "2.5L NA I4", 191, 181, AWD, A8, 8.5, 118, 3900, 5, 30000, GAS),
        C_("Santa Cruz", "2024", U, TRUCK, GREEN, "NX4T", "2021-present", "2.5L turbo I4", 281, 311, AWD, D8, 6.1, 120, 4200, 5, 36000, GAS),
        C_("Palisade", "2023", U, SUV, BLACK, "LX2", "2018-present", "3.8L NA V6", 291, 262, AWD, A8, 7.2, 118, 4400, 8, 37000, GAS),
        C_("Kona", "2023", C, SUV, LIME, "OS", "2017-2023", "2.0L NA I4", 147, 132, AWD, CVT, 9.2, 115, 3100, 5, 24000, GAS),
    ],
    "Kia": [
        C_("EV6 GT", "2024", R, SUV, LIME, "CV", "2022-present", "Two motors", 576, 546, AWD, EV1, 3.4, 161, 4772, 5, 63000, EV),
        C_("EV6", "2023", U, SUV, WHITE, "CV", "2021-present", "Two motors", 320, 446, AWD, EV1, 4.6, 117, 4500, 5, 52000, EV),
        C_("EV9", "2025", U, SUV, GUN, "MV", "2023-present", "Two motors", 379, 516, AWD, EV1, 4.9, 124, 5886, 7, 73000, EV),
        C_("Stinger GT", "2023", R, SEDAN, RED, "CK", "2017-2023", "3.3L twin-turbo V6", 368, 376, AWD, A8, 4.7, 167, 4023, 5, 53000, GAS),
        C_("K5", "2023", C, SEDAN, RED, "DL3", "2020-present", "1.6L turbo I4", 180, 195, FWD, A8, 7.8, 130, 3300, 5, 25000, GAS),
        C_("Forte", "2022", C, SEDAN, WHITE, "BD", "2018-2024", "2.0L NA I4", 147, 132, FWD, CVT, 8.8, 118, 2900, 5, 20000, GAS),
        C_("Sportage", "2022", C, SUV, BLACK, "QL", "2015-2022", "2.4L NA I4", 181, 175, AWD, A6, 9.1, 120, 3500, 5, 26000, GAS),
        C_("Seltos", "2024", C, SUV, ORANGE, "SP2", "2019-present", "1.6L turbo I4", 195, 195, AWD, D7, 7.6, 118, 3300, 5, 26000, GAS),
        C_("Sorento", "2023", C, SUV, SILVER, "MQ4", "2020-present", "2.5L turbo I4", 281, 311, AWD, D8, 6.6, 118, 4000, 7, 35000, GAS),
        C_("Telluride", "2022", C, SUV, NAVY, "ON", "2019-present", "3.8L NA V6", 291, 262, AWD, A8, 7.1, 118, 4400, 8, 37000, GAS),
        C_("Soul", "2022", C, HATCH, LIME, "SK3", "2019-present", "2.0L NA I4", 147, 132, FWD, CVT, 8.9, 115, 2900, 5, 21000, GAS),
        C_("Carnival", "2023", C, TRUCK, GREY, "KA4", "2020-present", "3.5L NA V6", 290, 262, FWD, A8, 7.2, 118, 4600, 8, 34000, GAS),
    ],
    "Genesis": [
        C_("G70", "2022", U, SEDAN, NAVY, "IK", "2017-present", "3.3L twin-turbo V6", 365, 376, AWD, A8, 4.5, 167, 3900, 5, 46000, GAS),
        C_("G80", "2023", R, SEDAN, BLACK, "RG3", "2020-present", "3.5L twin-turbo V6", 375, 391, AWD, A8, 5.1, 155, 4400, 5, 58000, GAS),
        C_("G90", "2023", R, SEDAN, PEARL, "RS4", "2022-present", "3.5L twin-turbo V6 mild hybrid", 409, 405, AWD, A8, 4.9, 155, 5000, 5, 99000, HYB),
        C_("GV60 Performance", "2024", R, SUV, ORANGE, "JW", "2021-present", "Two motors", 483, 516, AWD, EV1, 3.9, 146, 4700, 5, 69000, EV),
        C_("GV70", "2023", U, SUV, GREEN, "JK1", "2020-present", "3.5L twin-turbo V6", 375, 391, AWD, A8, 4.9, 149, 4400, 5, 48000, GAS),
        C_("GV80", "2023", R, SUV, SILVER, "JX1", "2020-present", "3.5L twin-turbo V6", 375, 391, AWD, A8, 5.5, 149, 4900, 7, 58000, GAS),
    ],
    "Volvo": [
        C_("P1800", "1965", R, COUPE, WHITE, "", "1961-1973", "1.8L NA I4", 108, 108, RWD, M4, 11.2, 110, 2400, 2, 4000, GAS),
        C_("240", "1990", C, SEDAN, RED, "", "1974-1993", "2.3L NA I4", 114, 136, RWD, M4, 11.5, 105, 2900, 5, 18000, GAS),
        C_("850 T-5R", "1995", R, HATCH, YELLOW, "", "1995-1995", "2.3L turbo I5", 243, 258, FWD, A4, 6.9, 155, 3300, 5, 35000, GAS),
        C_("S60 Polestar", "2022", R, SEDAN, CYAN, "", "2019-present", "2.0L turbo plug-in hybrid I4", 455, 523, AWD, A8, 4.3, 112, 4400, 5, 65000, PHEV),
        C_("V60", "2023", U, HATCH, GREY, "", "2018-present", "2.0L turbo I4", 247, 258, AWD, A8, 6.4, 112, 4000, 5, 46000, GAS),
        C_("XC40", "2023", U, SUV, BLUE, "", "2017-present", "2.0L turbo I4", 247, 258, AWD, A8, 6.3, 112, 3800, 5, 38000, GAS),
        C_("XC60", "2023", U, SUV, SILVER, "", "2017-present", "2.0L turbo I4 mild hybrid", 295, 310, AWD, A8, 6.2, 112, 4200, 5, 47000, HYB),
        C_("XC90", "2022", U, SUV, PEARL, "", "2014-present", "2.0L turbo I4 mild hybrid", 295, 310, AWD, A8, 6.5, 112, 4600, 7, 58000, HYB),
        C_("EX30", "2025", U, SUV, LIME, "", "2024-present", "Two motors", 422, 400, AWD, EV1, 3.4, 112, 4140, 5, 46000, EV),
        C_("EX90", "2026", R, SUV, PEARL, "", "2025-present", "Two motors", 510, 671, AWD, EV1, 4.7, 112, 6000, 7, 81000, EV),
    ],
    "Polestar": [
        C_("Polestar 1", "2021", X, COUPE, WHITE, "", "2019-2021", "2.0L turbo plug-in hybrid I4 plus 2 motors", 619, 738, AWD, A8, 4.2, 155, 5170, 4, 155000, PHEV),
        C_("Polestar 2", "2023", U, SEDAN, GREY, "", "2020-present", "Two motors", 455, 546, AWD, EV1, 4.1, 127, 4700, 5, 56000, EV),
        C_("Polestar 3", "2025", R, SUV, GUN, "", "2024-present", "Two motors", 517, 671, AWD, EV1, 4.0, 130, 5700, 5, 74000, EV),
        C_("Polestar 4", "2025", R, SUV, BRONZE, "", "2024-present", "Two motors", 536, 505, AWD, EV1, 3.7, 124, 5200, 5, 63000, EV),
    ],
    "Saab": [
        C_("900 Turbo", "1993", R, HATCH, BLACK, "", "1978-1993", "2.0L turbo I4", 175, 201, FWD, M5, 7.5, 130, 2900, 5, 28000, GAS),
        C_("9-3 Viggen", "2001", R, COUPE, YELLOW, "", "1999-2002", "2.3L turbo I4", 230, 258, FWD, M5, 6.4, 155, 3200, 4, 37000, GAS),
    ],
    "Renault": [
        C_("5 Turbo", "1984", L, HATCH, RED, "", "1980-1986", "1.4L turbo I4", 158, 163, RWD, M5, 6.9, 124, 2100, 4, 25000, GAS),
        C_("Clio Williams", "1994", R, HATCH, BLUE, "", "1993-1996", "2.0L NA I4", 148, 129, FWD, M5, 7.6, 134, 2200, 5, 20000, GAS),
        C_("Megane RS", "2022", R, HATCH, ORANGE, "IV", "2017-2023", "1.8L turbo I4", 296, 310, FWD, D6, 5.7, 155, 3000, 5, 45000, GAS),
        C_("Alpine A110", "2023", X, SPORT, BLUE, "", "2017-present", "1.8L turbo I4", 296, 251, RWD, D7, 4.2, 155, 2432, 2, 75000, GAS),
        C_("Clio", "2023", C, HATCH, WHITE, "V", "2019-present", "1.0L turbo I3", 89, 118, FWD, M5, 12.2, 112, 2500, 5, 20000, GAS),
        C_("5 E-Tech", "2026", U, HATCH, YELLOW, "", "2025-present", "Single front motor", 148, 181, FWD, EV1, 7.9, 93, 3086, 5, 33000, EV),
    ],
    "Peugeot": [
        C_("205 GTI", "1990", R, HATCH, RED, "", "1984-1994", "1.9L NA I4", 128, 119, FWD, M5, 7.8, 122, 1940, 5, 12000, GAS),
        C_("208 GTi", "2020", U, HATCH, RED, "", "2013-2020", "1.6L turbo I4", 205, 221, FWD, M6, 6.5, 143, 2500, 5, 28000, GAS),
        C_("508 PSE", "2023", R, SEDAN, LIME, "", "2021-present", "1.6L turbo plug-in hybrid I4", 355, 384, AWD, A8, 5.2, 155, 4200, 5, 60000, PHEV),
        C_("3008", "2023", C, SUV, GUN, "", "2016-present", "1.6L turbo I4", 178, 184, FWD, A8, 8.9, 127, 3300, 5, 33000, GAS),
    ],
    "Citroen": [
        C_("DS 21", "1970", R, SEDAN, BLACK, "", "1965-1975", "2.1L NA I4", 109, 128, FWD, M4, 13.0, 106, 2900, 5, 4000, GAS),
        C_("2CV", "1975", R, HATCH, GREY, "", "1948-1990", "0.6L NA flat-2", 29, 29, FWD, M4, 32.0, 71, 1279, 4, 1500, GAS),
        C_("C3", "2023", C, HATCH, WHITE, "", "2016-present", "1.2L turbo I3", 109, 151, FWD, M6, 9.5, 117, 2400, 5, 20000, GAS),
    ],
    "Skoda": [
        C_("Octavia vRS", "2023", U, HATCH, GREEN, "Mk4", "2019-present", "2.0L turbo I4", 242, 273, FWD, D7, 6.7, 155, 3200, 5, 40000, GAS),
        C_("Kodiaq", "2023", C, SUV, SILVER, "Mk1", "2016-2023", "2.0L turbo I4", 187, 236, AWD, D7, 8.4, 130, 3900, 7, 38000, GAS),
        C_("Enyaq", "2024", U, SUV, BLUE, "", "2021-present", "Two motors", 335, 339, AWD, EV1, 6.4, 112, 4900, 5, 50000, EV),
    ],
    "SEAT": [
        C_("Leon Cupra", "2022", U, HATCH, ORANGE, "Mk4", "2020-present", "2.0L turbo I4", 296, 295, FWD, D7, 5.7, 155, 3200, 5, 42000, GAS),
    ],
    "Dacia": [
        C_("Duster", "2023", C, SUV, ORANGE, "HM", "2017-2024", "1.3L turbo I4", 148, 184, AWD, M6, 9.7, 124, 3000, 5, 22000, GAS),
        C_("Sandero", "2023", C, HATCH, WHITE, "Mk3", "2020-present", "1.0L turbo I3", 89, 118, FWD, M6, 12.2, 111, 2400, 5, 15000, GAS),
    ],
    "Lada": [
        C_("Niva", "2020", C, SUV, WHITE, "2121", "1977-present", "1.7L NA I4", 82, 95, FOUR, M5, 19.0, 87, 2900, 5, 12000, GAS),
    ],
    "BYD": [
        C_("Yangwang U9", "2025", L, SPORT, BLUE, "", "2024-present", "Four motors", 1287, 0, AWD, EV1, 2.4, 192, 5290, 2, 233000, EV),
        C_("Yangwang U8", "2025", X, SUV, BLACK, "", "2023-present", "Four motors plus 2.0L range extender", 1184, 0, AWD, EV1, 3.6, 124, 7500, 5, 155000, PHEV),
        C_("Seal", "2024", U, SEDAN, BLUE, "", "2022-present", "Two motors", 523, 494, AWD, EV1, 3.8, 112, 4600, 5, 50000, EV),
        C_("Han", "2024", U, SEDAN, BLACK, "", "2020-present", "Two motors", 517, 494, AWD, EV1, 3.9, 115, 4850, 5, 45000, EV),
        C_("Atto 3", "2024", C, SUV, GREY, "", "2022-present", "Single front motor", 201, 228, FWD, EV1, 7.3, 99, 4266, 5, 40000, EV),
        C_("Dolphin", "2025", C, HATCH, CYAN, "", "2021-present", "Single front motor", 201, 228, FWD, EV1, 7.0, 99, 3400, 5, 30000, EV),
    ],
    "NIO": [
        C_("EP9", "2017", L, SPORT, BLUE, "", "2016-2018", "Four motors", 1341, 1091, AWD, EV1, 2.7, 195, 3826, 2, 1480000, EV),
        C_("ET7", "2024", R, SEDAN, PEARL, "", "2022-present", "Two motors", 644, 627, AWD, EV1, 3.8, 124, 5400, 5, 70000, EV),
        C_("ET9", "2026", X, SEDAN, BLACK, "", "2025-present", "Two motors", 697, 700, AWD, EV1, 4.3, 124, 6000, 4, 112000, EV),
        C_("EC7", "2024", R, SUV, BLUE, "", "2023-present", "Two motors", 644, 627, AWD, EV1, 3.8, 124, 5500, 5, 73000, EV),
    ],
    "Xpeng": [
        C_("P7", "2024", U, SEDAN, SILVER, "", "2020-present", "Two motors", 473, 481, AWD, EV1, 4.3, 106, 4600, 5, 45000, EV),
        C_("G6", "2025", U, SUV, GREEN, "", "2023-present", "Two motors", 476, 490, AWD, EV1, 4.1, 124, 4600, 5, 40000, EV),
    ],
    "Zeekr": [
        C_("001 FR", "2025", X, HATCH, ORANGE, "", "2024-present", "Four motors", 1265, 0, AWD, EV1, 2.1, 174, 5700, 5, 105000, EV),
        C_("001", "2024", R, HATCH, GREY, "", "2021-present", "Two motors", 536, 524, AWD, EV1, 3.8, 124, 4960, 5, 55000, EV),
        C_("009", "2025", R, TRUCK, BLACK, "", "2022-present", "Two motors", 536, 505, AWD, EV1, 4.5, 118, 6000, 6, 78000, EV),
    ],
    "Li Auto": [
        C_("L9", "2025", R, SUV, PEARL, "", "2022-present", "Two motors plus 1.5L range extender", 536, 457, AWD, EV1, 5.3, 112, 5800, 6, 65000, PHEV),
    ],
    "Hongqi": [
        C_("E-HS9", "2024", R, SUV, BLACK, "", "2020-present", "Two motors", 543, 457, AWD, EV1, 4.9, 124, 6000, 7, 100000, EV),
    ],
    "Wuling": [
        C_("Hongguang Mini EV", "2024", C, HATCH, CYAN, "", "2020-present", "Single rear motor", 27, 63, RWD, EV1, 0, 62, 1500, 4, 5000, EV),
    ],
    "MG": [
        C_("Cyberster", "2026", R, CONV, RED, "", "2024-present", "Two motors", 496, 535, AWD, EV1, 3.2, 124, 4000, 2, 75000, EV),
        C_("MG4", "2025", C, HATCH, ORANGE, "", "2022-present", "Single rear motor", 201, 184, RWD, EV1, 7.5, 99, 3500, 5, 33000, EV),
        C_("MGB", "1970", R, CONV, RED, "", "1962-1980", "1.8L NA I4", 95, 110, RWD, M4, 12.1, 105, 2030, 2, 2500, GAS),
    ],
    "VinFast": [
        C_("VF 8", "2024", U, SUV, BLUE, "", "2022-present", "Two motors", 402, 457, AWD, EV1, 5.3, 124, 5300, 5, 47000, EV),
    ],
    "Great Wall": [
        C_("Tank 300", "2024", U, SUV, GREEN, "", "2021-present", "2.0L turbo I4", 220, 280, FOUR, A8, 9.0, 106, 4600, 5, 30000, GAS),
    ],
    "Chery": [
        C_("Tiggo 8", "2024", C, SUV, WHITE, "", "2018-present", "1.6L turbo I4", 194, 214, FWD, D7, 8.9, 124, 3800, 7, 25000, GAS),
    ],
    "Tata": [
        C_("Nexon", "2024", C, SUV, BLUE, "", "2017-present", "1.2L turbo I3", 118, 125, FWD, M6, 11.0, 112, 2800, 5, 12000, GAS),
        C_("Safari", "2024", C, SUV, WHITE, "", "2021-present", "2.0L turbo diesel I4", 168, 258, FWD, A6, 10.5, 112, 3900, 7, 20000, DSL),
    ],
    "Mahindra": [
        C_("Thar", "2024", U, SUV, RED, "", "2020-present", "2.2L turbo diesel I4", 130, 221, FOUR, M6, 11.0, 96, 4200, 4, 18000, DSL),
        C_("Scorpio N", "2024", C, SUV, BLACK, "", "2022-present", "2.2L turbo diesel I4", 172, 273, FOUR, A6, 10.0, 112, 4400, 7, 20000, DSL),
    ],
    "Maruti Suzuki": [
        C_("Swift", "2024", C, HATCH, RED, "", "2024-present", "1.2L NA I3", 81, 82, FWD, M5, 12.6, 106, 2050, 5, 8000, GAS),
        C_("Baleno", "2023", C, HATCH, SILVER, "", "2022-present", "1.2L NA I4", 89, 83, FWD, M5, 12.3, 112, 2100, 5, 9000, GAS),
    ],
    "Holden": [
        C_("Commodore HSV GTS", "2016", X, SEDAN, YELLOW, "VF", "2013-2017", "6.2L supercharged V8", 577, 546, RWD, A6, 4.2, 155, 4200, 5, 95000, GAS),
        C_("Monaro", "2005", R, COUPE, RED, "V2", "2001-2005", "5.7L NA V8", 329, 361, RWD, M6, 5.5, 155, 3700, 4, 40000, GAS),
    ],
}
