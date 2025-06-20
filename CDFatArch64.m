// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-2019 Steve Nygard.

#import "CDFatArch64.h"

#include <mach-o/fat.h>
#import "CDDataCursor.h"
#import "CDFatFile.h"
#import "CDMachOFile.h"

@implementation CDFatArch64
{
    __weak CDFatFile *_fatFile;
    bool _isSwapped;

    // This is essentially struct fat_arch, but this way our property accessors can be synthesized.
    cpu_type_t _cputype;
    cpu_subtype_t _cpusubtype;
    uint64_t _offset;
    uint64_t _size;
    uint32_t _align;
    uint32_t _reserved;

    CDMachOFile *_machOFile; // Lazily create this.
}

- (id)initWithMachOFile:(CDMachOFile *)machOFile bigendian:(bool)isBigEndian
{
    if ((self = [super init])) {
        _machOFile = machOFile;

        if (isBigEndian == true) {
            _cputype    = _machOFile.cputype;
            _cpusubtype = _machOFile.cpusubtype;
            _offset     = 0; // Would be filled in when this is written to disk
            _size       = (uint64_t)[_machOFile.data length];
            _align      = 12; // 2**12 = 4096 (0x1000)
            _reserved   = 0;
            _isSwapped = false;
        } else {
            _cputype    = OSSwapInt32(_machOFile.cputype);
            _cpusubtype = OSSwapInt32(_machOFile.cpusubtype);
            _offset     = 0; // Would be filled in when this is written to disk
            _size       = OSSwapInt64((uint64_t)[_machOFile.data length]);
            _align      = 0x0C000000; // 2**12 = 4096 (0x1000)
            _reserved   = 0;
            _isSwapped = true;
        }
    }
    
    return self;
}

- (id)initWithDataCursor:(CDDataCursor *)cursor bigendian:(bool)isBigEndian
{
    if ((self = [super init])) {
        if (isBigEndian == true) {
            _cputype    = [cursor readBigInt32];
            _cpusubtype = [cursor readBigInt32];
            _offset     = [cursor readBigInt64];
            _size       = [cursor readBigInt64];
            _align      = [cursor readBigInt32];
            _reserved   = [cursor readBigInt32];
            _isSwapped = false;
        } else {
            _cputype    = [cursor readLittleInt32];
            _cpusubtype = [cursor readLittleInt32];
            _offset     = [cursor readLittleInt64];
            _size       = [cursor readLittleInt64];
            _align      = [cursor readLittleInt32];
            _reserved   = [cursor readLittleInt32];
            _isSwapped = true;
        }

        //NSLog(@"self: %@", self);
    }

    return self;
}

#pragma mark - Debugging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"64 bit ABI? %d, cputype: 0x%08x, cpusubtype: 0x%08x, offset: 0x%16llx (%16llu), size: 0x%16llx (%16llu), align: 2^%u (%x), arch name: %@",
            self.uses64BitABI, self.cputype, self.cpusubtype, self.offset, self.offset, self.size, self.size,
            self.align, 1 << self.align, self.archName];
}

#pragma mark -

- (cpu_type_t)maskedCPUType;
{
    return self.cputype & ~CPU_ARCH_MASK;
}

- (cpu_subtype_t)maskedCPUSubtype;
{
    return self.cpusubtype & ~CPU_SUBTYPE_MASK;
}

- (BOOL)uses64BitABI;
{
    return CDArchUses64BitABI(self.arch);
}

- (BOOL)uses64BitLibraries;
{
    return CDArchUses64BitLibraries(self.arch);
}

- (CDArch)arch;
{
    CDArch arch = { self.cputype, self.cpusubtype };

    return arch;
}

// Must not return nil.
- (NSString *)archName;
{
    return CDNameForCPUType(self.cputype, self.cpusubtype);
}

- (CDMachOFile *)machOFile;
{
    if (_machOFile == nil) {
        NSData *data = [NSData dataWithBytesNoCopy:((uint8_t *)[self.fatFile.data bytes] + self.offset) length:self.size freeWhenDone:NO];
        _machOFile = [[CDMachOFile alloc] initWithData:data filename:self.fatFile.filename searchPathState:self.fatFile.searchPathState];
    }

    return _machOFile;
}

@end
