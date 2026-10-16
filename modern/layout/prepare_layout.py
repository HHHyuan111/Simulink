"""Coordinates for the existing model; no blocks or connections are created."""
import json
from pathlib import Path

folder = Path(__file__).resolve().parent
source = json.loads((folder / 'source_xml_inventory.json').read_text(encoding='utf-8'))
positions = {}


def put(sid, x, y, w=70, h=20):
    assert str(sid) not in positions, sid
    positions[str(sid)] = [x, y, x + w, y + h]


# 01. DC link, switching bridge, measurement and PMSM.
put(681, 100, 270, 65, 40)
put(245, 100, 220, 80, 20)
put(615, 250, 200, 115, 120)
put(671, 440, 200, 115, 120)
put(626, 660, 200, 155, 120)
put(523, 440, 410, 70, 40)
put(682, 100, 410, 65, 30)
put(496, 210, 415, 70, 20)
put(506, 560, 420, 70, 20)
put(281, 620, 145, 75, 20)
put(693, 660, 370, 110, 20)

# 02. Feedback decomposition, speed, electrical speed and angle.
put(649, 960, 185, 75, 120)
put(32, 1120, 175, 5, 60)
put(28, 1370, 170, 55, 75)
put(34, 1190, 205, 75, 20)
put(171, 1120, 320, 70, 40)
put(172, 1230, 330, 80, 20)
put(186, 1120, 385, 70, 40)
put(188, 1230, 395, 80, 20)
put(177, 1350, 385, 110, 40)
put(180, 1500, 395, 90, 20)
put(189, 1230, 460, 80, 20)
put(660, 960, 415, 75, 60)
put(358, 1070, 445, 80, 20)
put(359, 1070, 485, 80, 20)

# 03. Clarke/Park and inverse Park, preserving the original hierarchy.
put(200, 1680, 195, 90, 20)
put(183, 1800, 185, 50, 40)
put(593, 1890, 175, 115, 60)
put(597, 2090, 175, 115, 80)
put(62, 2270, 165, 5, 90)
put(65, 2320, 175, 75, 20)
put(66, 2320, 205, 75, 20)
put(265, 2320, 240, 20, 20)
put(199, 1800, 280, 80, 20)
put(191, 1930, 270, 50, 40)
put(228, 1680, 350, 80, 20)
put(229, 1680, 390, 80, 20)
put(232, 1680, 430, 65, 20)
put(231, 1800, 340, 5, 120)
put(606, 1990, 350, 140, 90)
put(236, 2220, 340, 5, 120)
put(237, 2310, 350, 80, 20)
put(238, 2310, 390, 80, 20)
put(266, 2310, 430, 20, 20)
put(233, 1800, 485, 80, 20)
put(235, 1930, 475, 50, 40)

# 04. Original speed PI and torque-to-current conversion.
put(592, 90, 675, 70, 40)
put(169, 320, 685, 20, 20)
put(155, 390, 670, 155, 50)
put(193, 610, 680, 45, 40)
put(222, 710, 690, 75, 20)
put(509, 210, 770, 80, 20)
put(201, 90, 835, 80, 20)
put(190, 220, 825, 50, 40)
put(196, 90, 900, 65, 30)
put(216, 90, 960, 65, 30)
put(578, 90, 1020, 80, 20)
put(217, 220, 965, 45, 60)
put(215, 320, 905, 20, 20)
put(195, 390, 870, 65, 30)
put(194, 390, 990, 65, 30)
put(197, 500, 865, 45, 150)

# 05. Original d/q current PI and feedforward branches.
put(590, 890, 650, 65, 40)
put(40, 1050, 660, 20, 20)
put(439, 1130, 645, 155, 50)
put(144, 1510, 660, 20, 20)
put(220, 1580, 660, 75, 20)
put(202, 890, 745, 80, 20)
put(203, 890, 810, 80, 20)
put(206, 890, 880, 80, 20)
put(210, 1010, 870, 50, 40)
put(139, 1130, 735, 65, 30)
put(141, 1380, 735, 45, 120)
put(212, 1190, 895, 65, 30)
put(213, 1380, 895, 45, 60)
put(579, 890, 990, 90, 20)
put(133, 1050, 990, 20, 20)
put(453, 1130, 975, 155, 50)
put(152, 1510, 990, 20, 20)
put(221, 1580, 990, 75, 20)
put(209, 1190, 1050, 65, 30)
put(214, 1380, 1040, 45, 60)
put(468, 1500, 1060, 20, 20)

# 06. SVPWM, carrier, comparators, complementary gates.
put(242, 1790, 700, 80, 20)
put(243, 1790, 750, 80, 20)
put(246, 1790, 800, 65, 30)
put(247, 1790, 855, 65, 30)
put(240, 1910, 700, 105, 180)
put(295, 2050, 685, 5, 240)
put(346, 2090, 705, 55, 40)
put(347, 2090, 785, 55, 40)
put(348, 2090, 865, 55, 40)
put(291, 2200, 695, 45, 40)
put(292, 2200, 775, 45, 40)
put(293, 2200, 855, 45, 40)
put(299, 2290, 740, 40, 30)
put(300, 2290, 820, 40, 30)
put(301, 2290, 900, 40, 30)
put(298, 2380, 690, 5, 240)
put(244, 2420, 800, 80, 20)
put(324, 1790, 610, 90, 40)
put(426, 1940, 610, 55, 40)
put(302, 2410, 980, 60, 100)
put(307, 2070, 1020, 80, 20)
put(372, 1790, 1000, 80, 20)
put(718, 1910, 1000, 80, 20)

# 07. Existing scopes grouped by the quantity being observed.
# Row 1: speed/torque, dq current, abc current, line voltage, dq voltage.
put(259, 90, 1230, 80, 20)
put(271, 90, 1280, 80, 20)
put(255, 310, 1225, 65, 80)
put(310, 580, 1230, 80, 20)
put(312, 580, 1280, 80, 20)
put(314, 800, 1225, 65, 80)
put(273, 1070, 1250, 80, 20)
put(274, 1300, 1235, 65, 60)
put(282, 1560, 1250, 80, 20)
put(334, 1690, 1225, 5, 90)
put(288, 1800, 1225, 65, 90)
put(361, 2050, 1220, 80, 20)
put(360, 2050, 1260, 80, 20)
put(365, 2190, 1220, 60, 60)
put(362, 2300, 1220, 80, 20)
put(363, 2300, 1260, 80, 20)
put(366, 2430, 1220, 60, 60)

# Row 2: gates, alpha/beta, PWM thresholds, vector locus, sector.
put(269, 90, 1450, 80, 20)
put(275, 310, 1430, 65, 60)
put(285, 580, 1430, 80, 20)
put(286, 580, 1480, 80, 20)
put(287, 800, 1425, 65, 80)
put(350, 1070, 1450, 80, 20)
put(352, 1200, 1425, 5, 90)
put(353, 1300, 1425, 65, 90)
put(331, 1560, 1430, 80, 20)
put(332, 1560, 1480, 80, 20)
put(330, 1800, 1425, 65, 80)
put(308, 2050, 1450, 80, 20)
put(309, 2290, 1430, 65, 60)

# Row 3: DC/speed, two original chirp comparisons, chirp sources, logger.
put(497, 90, 1650, 80, 20)
put(498, 90, 1700, 80, 20)
put(499, 310, 1645, 65, 80)

for ids, x in [((501,589,534,504,546,548,551,550,549),580),
               ((586,576,563,564,566,558,559,560,565),1070)]:
    a,b,mux,main,error,absolute,constant,divide,pair=ids
    put(a,x,1610,80,20)
    put(b,x,1660,80,20)
    put(mux,x+170,1605,5,80)
    put(main,x+355,1600,60,70)
    put(error,x+170,1730,20,20)
    put(absolute,x+220,1720,35,40)
    put(constant,x+170,1800,105,30)
    put(divide,x+300,1730,35,70)
    put(pair,x+355,1690,60,70)

put(683, 1560, 1640, 65, 40)
put(553, 1690, 1645, 70, 30)
put(588, 1800, 1650, 80, 20)
put(688, 1560, 1740, 65, 40)
put(573, 1690, 1745, 70, 30)
put(575, 1800, 1750, 80, 20)
put(695, 2130, 1650, 240, 100)

source_ids={b['sid'] for b in source}
assert set(positions)==source_ids, f'missing={source_ids-set(positions)}, extra={set(positions)-source_ids}'
out=[dict(sid=b['sid'],name=b['name'],position=positions[b['sid']]) for b in source]
(folder/'layout_positions.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print('PLACEMENTS_OK',len(out))
