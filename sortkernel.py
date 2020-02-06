#!/usr/bin/python3

import sys
import re

def make_vtuple(vstr, rc=None, build=None):
    verparts = vstr.split('.')
    res = [int(vp) for vp in verparts]
        
    if rc:
        res.append(int(rc))
    else:
        res.append(999)

    if build:
        res.append(int(build))

    return tuple(res)


def filename_sortkey(filename):
    rc = re.compile(r'^([0-9\.]+)-rc([0-9]+)-[^\-]+-([0-9]+)')
    rel = re.compile(r'^([0-9\.]+)-[^-]+-([0-9]+)')

    try:
        verstr = filename.split('_')[-2]
        m = rc.match(verstr)
        if m:
            return make_vtuple(m.group(1), m.group(2), m.group(3))

        m=rel.match(verstr)
        if m:
            return make_vtuple(m.group(1), None, m.group(2))
    except:
        print("Can not create version key for filename %s key %s" % (filename, verstr), file=sys.stderr)
        return (0,)

    print("Can not recognize version in filename %s key %s" % (filename, verstr), file=sys.stderr)
    return (0,)


def kernel_sort(inlist):
    return sorted(inlist, key=filename_sortkey)

def main():
    r=kernel_sort([l.strip() for l in sys.stdin.readlines()])
    for l in r:
        print(l)

if __name__ == '__main__':
    main()

