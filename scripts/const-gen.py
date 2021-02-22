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
Architecture = namedtuple('Architecture', 'name items default')

TARGETS = [
    Name("alpha", "Alpha"),
    Name("arm", "ARM (aarch32)"),
    Name("aarch64", "ARM64 (aarch64)"),
    Name("avr", "AVR"),
    Name("cris", "CRIS"),
    Name("hppa", "HPPA"),
    Name("i386", "i386 (x86)"),
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
    Name("x86_64", "x86_64"),
    Name("xtensa", "Xtensa"),
    Name("xtensaeb", "Xtensa (Big Endian)")
]

DEFAULTS = {
    "aarch64": "virt",
    "arm": "virt",
    "avr": "mega",
    "i386": "q35",
    "rx": "gdbsim-r5f562n7",
    "tricore": "tricore_testboard",
    "x86_64": "q35"
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
        result.add(Name(name, '{} ({})'.format(description, name)))
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
        name = search.group('name')
        desc = search.group('desc')
        if not desc:
            desc = name
        else:
            desc = '{} ({})'.format(desc, name)
        item = Device(name, search.group('bus'), search.group('alias'), desc)
        result[group].add(item)
    return result

def parseCpu(listing):
    def parseMips(line):
        search = re.search('^(?P<arch>\S+)\s+\'(?P<name>.+)\'.*', line)
        return Name(search.group('name'), search.group('name'))
    def parseSingle(line):
        name = line.strip()
        return Name(name, name)
    def parseSparc(line):
        search = re.search('^(?P<arch>\S+)\s+(?P<name>.+)\s+IU\s+(?P<iu>\S+)\s+FPU\s+(?P<fpu>\S+)\s+MMU\s+(?P<mmu>\S+)\s+NWINS\s+(?P<nwins>\d+).*$', line)
        return Name(search.group('name'), search.group('name'))
    def parseStandard(line):
        search = re.search('^(?P<arch>\S+)\s+(?P<name>\S+)\s+(?P<desc>.*)?$', line)
        name = search.group('name')
        desc = search.group('desc').strip()
        desc = ' '.join(desc.split())
        if not desc or desc.startswith('(alias'):
            desc = name
        else:
            desc = '{} ({})'.format(desc, name)
        return Name(name, desc)
    def parseSparcFlags(line):
        if line.startswith('Default CPU feature flags'):
            flags = line.split(':')[1].strip()
            return [Name('-' + flag, '-' + flag) for flag in flags.split(' ')]
        elif line.startswith('Available CPU feature flags'):
            flags = line.split(':')[1].strip()
            return [Name('+' + flag, '+' + flag) for flag in flags.split(' ')]
        elif line.startswith('Numerical features'):
            return []
        else:
            return None
    def parseS390Flags(line):
        if line.endswith(':'):
            return []
        else:
            flag = line.split(' ')[0]
            return [Name(flag, flag)]
    def parseX86Flags(line):
        flags = []
        for flag in line.split(' '):
            if flag:
                flags.append(Name(flag, flag))
        return flags
    output = enumerate(listing.splitlines())
    cpus = [Name('default', 'Default')]
    flags = []
    if next(output, None) == None:
        return (cpus, flags)
    for (index, line) in output:
        if not line:
            break
        if len(line.strip().split(' ')) == 1:
            cpus.append(parseSingle(line))
        elif line.startswith('Sparc'):
            cpus.append(parseSparc(line))
        elif line.startswith('MIPS'):
            cpus.append(parseMips(line))
        elif parseSparcFlags(line) != None:
            flags += parseSparcFlags(line)
        else:
            cpus.append(parseStandard(line))
    header = next(output, None)
    if header == None:
        return (cpus, flags)
    for (index, line) in output:
        if header[1] == 'Recognized CPUID flags:':
            flags += parseX86Flags(line)
        elif header[1] == 'Recognized feature flags:':
            flags += parseS390Flags(line)
    flags = set(flags) # de-duplicate
    return (cpus, flags)

def sortItems(items):
    return sorted(items, key=lambda item: item.desc if item.desc else item.name)

def getMachines(qemu_path):
    output = subprocess.check_output([qemu_path, '-machine', 'help']).decode('utf-8')
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
    return -1

def getDevices(qemu_path):
    output = subprocess.check_output([qemu_path, '-device', 'help']).decode('utf-8')
    devices = parseDeviceListing(output)
    return devices

def getCpus(qemu_path):
    output = subprocess.check_output([qemu_path, '-cpu', 'help']).decode('utf-8')
    return parseCpu(output)

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

def generateMapForeachArchitecture(name, targetKeys, targetItems, isPretty=False):
    return generateMap(name, 'architecture', targetKeys, {target.name: [item.desc if isPretty else item.name for item in sortItems(target.items)] for target in targetItems})

def generate(targets, cpus, cpuFlags, machines, displayCards, networkCards, soundCards):
    targetKeys = [item.name for item in targets]
    output  = HEADER
    output += generateArray('supportedArchitectures', targetKeys)
    output += generateArray('supportedArchitecturesPretty', [item.desc for item in targets])
    output += generateMapForeachArchitecture('supportedCpusForArchitecture', targetKeys, cpus)
    output += generateMapForeachArchitecture('supportedCpusForArchitecturePretty', targetKeys, cpus, isPretty=True)
    output += generateMapForeachArchitecture('supportedCpuFlagsForArchitecture', targetKeys, cpuFlags)
    output += generateMapForeachArchitecture('supportedTargetsForArchitecture', targetKeys, machines)
    output += generateMapForeachArchitecture('supportedTargetsForArchitecturePretty', targetKeys, machines, isPretty=True)
    output += generateIndexMap('defaultTargetIndexForArchitecture', 'architecture', targetKeys, {machine.name: machine.default for machine in machines})
    output += generateMapForeachArchitecture('supportedDisplayCardsForArchitecture', targetKeys, displayCards)
    output += generateMapForeachArchitecture('supportedDisplayCardsForArchitecturePretty', targetKeys, displayCards, isPretty=True)
    output += generateMapForeachArchitecture('supportedNetworkCardsForArchitecture', targetKeys, networkCards)
    output += generateMapForeachArchitecture('supportedNetworkCardsForArchitecturePretty', targetKeys, networkCards, isPretty=True)
    output += generateMapForeachArchitecture('supportedSoundCardsForArchitecture', targetKeys, soundCards)
    output += generateMapForeachArchitecture('supportedSoundCardsForArchitecturePretty', targetKeys, soundCards, isPretty=True)
    output += '@end\n'
    return output

def main(argv):
    base = argv[1]
    allMachines = []
    allCpus = []
    allCpuFlags = []
    allDisplayCards = []
    allSoundCards = []
    allNetworkCards = []
    # parse outputs
    for target in TARGETS:
        path = '{}/{}-softmmu/qemu-system-{}'.format(base, target.name, target.name)
        if not os.path.exists(path):
            path = '{}/qemu-system-{}'.format(base, target.name)
            if not os.path.exists(path):
                raise "Invalid path."
        machines = sortItems(getMachines(path))
        default = getDefaultMachine(target.name, machines)
        allMachines.append(Architecture(target.name, machines, default))
        devices = getDevices(path)
        allDisplayCards.append(Architecture(target.name, devices["Display devices"], 0))
        allNetworkCards.append(Architecture(target.name, devices["Network devices"], 0))
        nonHdaDevices = [device for device in devices["Sound devices"] if device.bus != 'HDA']
        allSoundCards.append(Architecture(target.name, nonHdaDevices, 0))
        cpus, flags = getCpus(path)
        allCpus.append(Architecture(target.name, cpus, 0))
        allCpuFlags.append(Architecture(target.name, flags, 0))
    # generate constants
    print(generate(TARGETS, allCpus, allCpuFlags, allMachines, allDisplayCards, allNetworkCards, allSoundCards))

if __name__ == "__main__":
    main(sys.argv)
