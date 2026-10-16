from pathlib import Path
import zipfile, xml.etree.ElementTree as E, json

folder=Path(__file__).resolve().parent
source=folder.parent/'PMSM_FOC_R2026a.slx'
with zipfile.ZipFile(source) as z:
    r=E.fromstring(z.read('simulink/systems/system_root.xml'))
    blocks=[]
    for b in r.findall('Block'):
        blocks.append(dict(name=b.get('Name'),type=b.get('BlockType'),sid=b.get('SID'),
            params={p.get('Name'):p.text for p in b.findall('P')},ports=b.find('PortCounts').attrib if b.find('PortCounts') is not None else {}))
    (folder/'source_xml_inventory.json').write_text(json.dumps(blocks,ensure_ascii=False,indent=2),encoding='utf-8')
    print('TOP BLOCKS',len(blocks))
    for line in r.findall('Line')[:12]:print(E.tostring(line,encoding='unicode'))
    print('ANNOTATIONS')
    for a in r.findall('Annotation'):print(E.tostring(a,encoding='unicode')[:1400])
# Read native area serialization from an installed sample, without changing it.
for f in Path(r'D:\DevTools\MATLAB\R2026a\toolbox\simulink').rglob('*.slx'):
    try:
        with zipfile.ZipFile(f) as z:
            for entry in z.namelist():
                if entry.startswith('simulink/systems/') and entry.endswith('.xml'):
                    data=z.read(entry)
                    if b'AnnotationType">area' in data or b'Type="area"' in data or b'BlockType="Area"' in data:
                        root=E.fromstring(data)
                        matches=[a for a in root.iter() if a.tag in ('Annotation','Block') and ('area' in E.tostring(a,encoding='unicode').lower())]
                        for a in matches:
                            print('AREA SAMPLE',str(f),entry,E.tostring(a,encoding='unicode')[:3500])
                            (folder/'area_sample.xml').write_text(E.tostring(a,encoding='unicode'),encoding='utf-8')
                            raise SystemExit(0)
    except zipfile.BadZipFile:pass
print('NO_AREA_SAMPLE')
