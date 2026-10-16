"""Reposition the 164 existing root blocks; never change model topology."""
import json
from pathlib import Path

folder = Path(__file__).resolve().parent
old = json.loads((folder / 'layout_positions.json').read_text(encoding='utf-8'))
lookup = {b['sid']: b for b in old}
positions = {}

def move(ids, dx, dy):
    for sid in map(str, ids):
        assert sid not in positions
        x1, y1, x2, y2 = lookup[sid]['position']
        positions[sid] = [x1+dx, y1+dy, x2+dx, y2+dy]

def put(sid, x, y, w=80, h=20):
    sid = str(sid)
    assert sid not in positions
    positions[sid] = [x, y, x+w, y+h]

# Nine equal 860 x 580 areas, 40 units between them. Main chain reads by row.
move([592,169,155,193,222,509,201,190,196,216,578,217,215,195,194,197], 0, -465)
move([590,40,439,144,220,202,203,206,210,139,141,212,213,579,133,453,152,221,209,214,468], 100, -465)
move([200,183,593,597,62,65,66,265,199,191,228,229,232,231,606,236,237,238,266,233,235], 200, 0)
move([242,243,246,247,240,295,346,347,348,291,292,293,299,300,301,298,244,324,426,302,307,372,718], -1700, 155)
move([681,245,615,671,626,523,682,496,506,281,693], 900, 720)
move([649,32,28,34,171,172,186,188,177,180,189,660,358,359], 950, 700)

# Motor observations, arranged in a regular two-column / three-row grid.
move([259,271,255], 0, 210)
move([310,312,314], -80, 210)
move([273,274], -980, 370)
move([282,334,288], -1060, 385)
move([361,360,365], -1960, 570)
move([362,363,366], -1800, 570)

# Modulation observations, using exactly the original From/Scope blocks.
move([269,275], 900, 0)
move([285,286,287], 820, 20)
move([350,352,353], -80, 190)
move([331,332,330], -160, 190)
move([308,309], -1060, 390)
move([497,498,499], 1310, 150)

# Original auxiliary comparisons. Compress only the spaces between blocks.
for ids, x in [((501,589,534,504,546,548,551,550,549),1890),
               ((586,576,563,564,566,558,559,560,565),2310)]:
    a,b,mux,main,error,absolute,constant,divide,pair = ids
    put(a,x,1430); put(b,x,1480)
    put(mux,x+125,1425,5,80); put(main,x+300,1420,55,70)
    put(error,x+125,1560,20,20); put(absolute,x+175,1550,30,40)
    put(constant,x+110,1630,105,30); put(divide,x+245,1560,30,70)
    put(pair,x+300,1530,55,70)
put(683,1890,1750,65,40); put(553,2010,1755,70,30); put(588,2140,1760)
put(688,1890,1840,65,40); put(573,2010,1845,70,30); put(575,2140,1850)
put(695,2400,1760,240,100)

assert set(positions) == set(lookup), (set(lookup)-set(positions), set(positions)-set(lookup))
out = [dict(sid=b['sid'], name=b['name'], position=positions[b['sid']]) for b in old]
(folder / 'flat_tidy_positions.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print('EXISTING_BLOCKS_POSITIONED', len(out))
