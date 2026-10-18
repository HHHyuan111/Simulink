"""Derive graph-only adapters from frozen local constructors; check exact diff."""
from pathlib import Path
import argparse
import hashlib
import json

BASE = Path(__file__).resolve().parents[2]
TARGET = BASE / 'robust/constructor'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def derive():
    frozen = json.loads((BASE / 'milestones/N3R1/frozen_candidate.json').read_text('utf-8-sig'))
    frozen_sha = {entry['path']: entry['sha256'] for entry in frozen['files']}
    source_manifest = json.loads((BASE / 'baseline/source_manifest.json').read_text('utf-8-sig'))
    original_sha = {entry['path']: entry['sha256'] for entry in source_manifest['source_files']}
    definitions = [
        ('pmsm_sensorless_model.m', 'pmsm_sensorless_geometry_model.m'),
        ('robust/integration/pmsm_sensorless_v2_model.m', 'pmsm_sensorless_v2_geometry_model.m'),
        ('../teaching/pmsm_reference.m', 'pmsm_reference_geometry.m'),
    ]
    products, manifest = {}, []
    for original, output in definitions:
        path = BASE / original
        expected = original_sha['modern/teaching/pmsm_reference.m'] if original.startswith('../') else frozen_sha[original]
        assert sha(path) == expected
        source = path.read_text('utf-8').replace('\r\n', '\n')
        if original == 'pmsm_sensorless_model.m':
            substitutions = [
                ('function result=pmsm_sensorless_model(action,mdl)',
                 'function result=pmsm_sensorless_geometry_model(action,mdl)'),
                ("here=fileparts(mfilename('fullpath'));",
                 "here=fileparts(fileparts(fileparts(mfilename('fullpath'))));"),
                ("feval(mdl,[],[],[],'compile');\nsourceDimensions=get_param(appliedSource,'CompiledPortDimensions');\ncurrentDimensions=get_param(currentSource,'CompiledPortDimensions');\nfeval(mdl,[],[],[],'term');",
                 "geometry=sensorless_r2_constructor_geometry(mdl);\nsourceDimensions=geometry.applied.compiled_dimensions;\ncurrentDimensions=geometry.current.compiled_dimensions;"),
            ]
            for old, new in substitutions:
                assert source.count(old) == 1
                source = source.replace(old, new)
            assert 'feval(' not in source and 'CompiledPortDimensions' not in source
        elif not original.startswith('../'):
            assert source.count('pmsm_sensorless_model(') == 3
            source = source.replace('pmsm_sensorless_model(', 'pmsm_sensorless_geometry_model(')
            old = 'function result=pmsm_sensorless_v2_model(action,mdl,interference_s)'
            assert source.count(old) == 1
            source = source.replace(old, 'function result=pmsm_sensorless_v2_geometry_model(action,mdl,interference_s)')
            old = "here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));"
            assert source.count(old) == 1
            source = source.replace(old, "here=fullfile(fileparts(fileparts(mfilename('fullpath'))),'integration');base=fileparts(fileparts(here));")
        else:
            substitutions = [
                ('function result=pmsm_reference(action,folder,mdl)',
                 'function result=pmsm_reference_geometry(action,folder,mdl)'),
                ("here=fileparts(mfilename('fullpath'));root=fileparts(here);",
                 "here=fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))),'teaching');root=fileparts(here);"),
                ('applyState(mdl,target,true);', 'applyState(mdl,target,false);'),
            ]
            for old, new in substitutions:
                assert source.count(old) == 1
                source = source.replace(old, new)
        data = source.encode('utf-8')
        products[output] = data
        manifest.append({'original': original, 'original_sha256': sha(path), 'generated': output,
                         'generated_sha256': hashlib.sha256(data).hexdigest()})
    return products, {'kind': 'exact_graph_constructor_derivation', 'algorithm_equations_changed': False,
                      'resource_paths': 'original trusted directories, computed relative to adapter location',
                      'explicit_preinstall_compile_removed': True, 'files': manifest}


def main(write=False):
    products, manifest = derive()
    TARGET.mkdir(exist_ok=True)
    for name, data in products.items():
        path = TARGET / name
        if write:
            path.write_bytes(data)
        else:
            assert path.read_bytes() == data, f'Unregistered constructor difference: {name}'
    encoded = (json.dumps(manifest, indent=2) + '\n').encode('utf-8')
    path = TARGET / 'derivation.json'
    if write:
        path.write_bytes(encoded)
    else:
        assert path.read_bytes() == encoded
    print(json.dumps({'exact_derivation_verified': True, 'files': len(products), 'algorithm_changed': False}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    main(parser.parse_args().write)
