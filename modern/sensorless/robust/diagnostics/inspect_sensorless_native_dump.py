"""Read only exception metadata/module addresses; never export memory strings.

The module hits below are a raw stack scan, NOT an unwound call stack.
Layouts: Microsoft Learn MINIDUMP_EXCEPTION_STREAM/MODULE/THREAD docs.
"""
import argparse
import json
import mmap
import ntpath
import struct
from pathlib import Path


def inspect(path):
    with path.open('rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        def unpack(fmt, offset):
            size = struct.calcsize(fmt)
            assert 0 <= offset <= len(data) - size
            return struct.unpack_from(fmt, data, offset)

        assert data[:4] == b'MDMP'
        count, directory = unpack('<II', 8)
        entries = {}
        for k in range(count):
            kind, size, rva = unpack('<III', directory + 12*k)
            assert rva + size <= len(data)
            entries[kind] = (rva, size)
        module_rva, module_size = entries[4]
        module_count, = unpack('<I', module_rva)
        assert module_count * 108 + 4 <= module_size
        modules = []
        for k in range(module_count):
            offset = module_rva + 4 + 108*k
            base, size, _, _, name_rva = unpack('<QIIII', offset)
            name_size, = unpack('<I', name_rva)
            name = data[name_rva+4:name_rva+4+name_size].decode('utf-16-le')
            modules.append((base, base+size, ntpath.basename(name)))

        def module_address(address):
            for start, stop, name in modules:
                if start <= address < stop:
                    return {'module': name, 'offset': hex(address-start)}
            return {'module': 'unknown/unmapped', 'address': hex(address)}

        exception_rva, _ = entries[6]
        thread_id, = unpack('<I', exception_rva)
        code, flags = unpack('<II', exception_rva+8)
        address, = unpack('<Q', exception_rva+24)
        parameter_count, = unpack('<I', exception_rva+32)
        assert parameter_count <= 15
        parameters = unpack('<'+'Q'*parameter_count, exception_rva+40)
        report = {'dump_name': path.name, 'exception_code': hex(code), 'exception_flags': flags,
                  'exception_location': module_address(address), 'thread_id': thread_id,
                  'module_hits_are_unwound_stack': False, 'raw_memory_exported': False}
        if code == 0xc0000005 and len(parameters) >= 2:
            report['access_kind'] = {0: 'read', 1: 'write', 8: 'execute'}.get(parameters[0], str(parameters[0]))
            report['access_target'] = module_address(parameters[1])
        context_size, context_rva = unpack('<II', exception_rva+160)
        if context_size >= 256:
            rsp, = unpack('<Q', context_rva+152)
            rip, = unpack('<Q', context_rva+248)
            report['context_instruction_matches_exception'] = rip == address
            thread_rva, _ = entries[3]
            thread_count, = unpack('<I', thread_rva)
            for k in range(thread_count):
                offset = thread_rva + 4 + 48*k
                current, = unpack('<I', offset)
                if current != thread_id:
                    continue
                start, size, stack_rva = unpack('<QII', offset+24)
                hits = []
                if start <= rsp < start+size:
                    for position in range(rsp-start, min(size-7, rsp-start+16384), 8):
                        candidate, = unpack('<Q', stack_rva+position)
                        location = module_address(candidate)
                        if location['module'] != 'unknown/unmapped':
                            location['stack_offset_bytes'] = position-(rsp-start)
                            hits.append(location)
                            if len(hits) >= 50:
                                break
                report['raw_stack_module_hits'] = hits
                break
        return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('dumps', nargs='+', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    reports = [inspect(path) for path in args.dumps]
    args.output.write_text(json.dumps(reports, indent=2) + '\n', encoding='utf-8')
    for report in reports:
        print(json.dumps({key: value for key, value in report.items() if key != 'raw_stack_module_hits'}))
        print(json.dumps(report.get('raw_stack_module_hits', [])[:12]))
