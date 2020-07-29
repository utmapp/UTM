#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import re
import subprocess
import sys
from collections import defaultdict
from collections import namedtuple

Name = namedtuple('Name', 'name desc')
Device = namedtuple('Device', 'name bus alias desc')
Machines = namedtuple('Machines', 'name items default')

TARGETS = [
    Name("alpha", "Alpha"),
    Name("arm", "ARM (aarch32)"),
    Name("aarch64", "ARM64 (aarch64)"),
    Name("avr", "AVR"),
    Name("cris", "CRIS"),
    Name("hppa", "HPPA"),
    Name("i386", "i386 (x86)"),
    Name("lm32", "LatticeMico32 (lm32)"),
    Name("m68k", "m68k"),
    Name("microblaze", "Microblaze"),
    Name("microblazeel", "Microblaze (Little Endian)"),
    Name("mips", "MIPS"),
    Name("mipsel", "MIPS (Little Endian)"),
    Name("mips64", "MIPS64"),
    Name("mips64el", "MIPS64 (Little Endian)"),
    Name("moxie", "Moxie"),
    Name("nios2", "NIOS2"),
    Name("or1k", "OpenRISC"),
    Name("ppc", "PowerPC"),
    Name("ppc64", "PowerPC64"),
    Name("riscv32", "RISC-V32"),
    Name("riscv64", "RISC-V64"),
    Name("rx", "RX"),
    Name("s390x", "S390x (zSeries)"),
    Name("sh4", "SH4"),
    Name("sh4eb", "SH4 (Big Endian)"),
    Name("sparc", "SPARC"),
    Name("sparc64", "SPARC64"),
    Name("tricore", "TriCore"),
    Name("unicore32", "Unicore32"),
    Name("x86_64", "x86_64"),
    Name("xtensa", "Xtensa"),
    Name("xtensaeb", "Xtensa (Big Endian)")
]

DEFAULTS = {
    "aarch64": "virt",
    "arm": "virt",
    "avr": "mega",
    "i386": "pc",
    "rx": "gdbsim-r5f562n7",
    "tricore": "tricore_testboard",
    "x86_64": "pc"
}

HEADER = '''//
// Copyright © 2020 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// !! THIS FILE IS GENERATED FROM const-gen.py, DO NOT MODIFY MANUALLY !!

#import "UTMConfiguration+Constants.h"

@implementation UTMConfiguration (ConstantsGenerated)

'''

def parseListing(listing):
    output = listing.splitlines()[1:]
    result = set()
    for line in output:
        idx = line.find(' ')
        if idx < 0:
            break
        name = line[0:idx]
        description = line[idx:].strip()
        result.add(Name(name, description))
    return result

def parseDeviceListing(listing):
    output = listing.splitlines()
    group = ''
    result = defaultdict(set)
    for line in output:
        if not line:
            continue
        if not line.startswith('name '):
            group = line.rstrip(':')
            continue
        search = re.search('^name "(?P<name>[^"]*)"(?:, bus (?P<bus>[^\s]+))?(?:, alias "(?P<alias>[^"]+)")?(?:, desc "(?P<desc>[^"]+)")?$', line)
        item = Device(search.group('name'), search.group('bus'), search.group('alias'), search.group('desc'))
        result[group].add(item)
    return result

def sortItems(items):
    return sorted(items, key=lambda item: item.desc if item.desc else item.name)

def getMachines(qemu_path):
    output = subprocess.check_output([qemu_path, '-machine', 'help'])
    return parseListing(output)

def getDefaultMachine(target, machines):
    find = None
    if target in DEFAULTS:
        find = DEFAULTS[target]
    for (idx, machine) in enumerate(machines):
        if find and find == machine.name:
            return idx
        elif not find and "default" in machine.desc:
            return idx
    print(machines)
    return -1

def getSoundCards(qemu_path):
    output = subprocess.check_output([qemu_path, '-soundhw', 'help'])
    return parseListing(output)

def getNetworkCards(qemu_path):
    output = subprocess.check_output([qemu_path, '-device', 'help'])
    devices = parseDeviceListing(output)
    return devices["Network devices"]

def generateArray(name, array):
    output  = '+ (NSArray<NSString *>*){} {{\n'.format(name)
    output += '    return @[\n'
    for item in array:
        output += '             @"{}",\n'.format(item)
    output += '             ];\n'
    output += '}\n\n'
    return output

def generateMap(name, keyName, keys, arrays):
    output  = '+ (NSArray<NSString *>*){}:(NSString *){} {{\n'.format(name, keyName)
    output += '    return @{\n'
    for key in keys:
        output += '        @"{}":\n'.format(key)
        output += '            @[\n'
        for item in arrays[key]:
            output += '                @"{}",\n'.format(item)
        output += '            ],\n'
    output += '    }}[{}];\n'.format(keyName)
    output += '}\n\n'
    return output

def generateIndexMap(name, keyName, keys, indexMap):
    output  = '+ (NSInteger){}:(NSString *){} {{\n'.format(name, keyName)
    output += '    return [@{\n'
    for key in keys:
        output += '        @"{}": @{},\n'.format(key, indexMap[key])
    output += '    }}[{}] integerValue];\n'.format(keyName)
    output += '}\n\n'
    return output

def generate(targets, machines, networkCards, soundCards):
    targetKeys = [item.name for item in targets]
    output  = HEADER
    output += generateArray('supportedArchitectures', targetKeys)
    output += generateArray('supportedArchitecturesPretty', [item.desc for item in targets])
    output += generateMap('supportedTargetsForArchitecture', 'architecture', targetKeys, {machine.name: [item.name for item in machine.items] for machine in machines})
    output += generateMap('supportedTargetsForArchitecturePretty', 'architecture', targetKeys, {machine.name: [item.desc for item in machine.items] for machine in machines})
    output += generateIndexMap('defaultTargetIndexForArchitecture', 'architecture', targetKeys, {machine.name: machine.default for machine in machines})
    output += generateArray('supportedNetworkCards', [item.name for item in networkCards])
    output += generateArray('supportedNetworkCardsPretty', [item.desc for item in networkCards])
    output += generateArray('supportedSoundCardDevices', [item.name for item in soundCards])
    output += generateArray('supportedSoundCardDevicesPretty', [item.desc for item in soundCards])
    output += '@end\n'
    return output

def main(argv):
    base = argv[1]
    allMachines = []
    soundCards = set()
    networkCards = set()
    # parse outputs
    for target in TARGETS:
        path = '{}/{}-softmmu/qemu-system-{}'.format(base, target.name, target.name)
        if not os.path.exists(path):
            path = '{}/qemu-system-{}'.format(base, target.name)
            if not os.path.exists(path):
                raise "Invalid path."
        machines = sortItems(getMachines(path))
        default = getDefaultMachine(target.name, machines)
        allMachines.append(Machines(target.name, machines, default))
        networkCards = networkCards.union(getNetworkCards(path))
        soundCards = soundCards.union(getSoundCards(path))
    # generate constants
    print(generate(TARGETS, allMachines, sortItems(networkCards), sortItems(soundCards)))

if __name__ == "__main__":
    main(sys.argv)
