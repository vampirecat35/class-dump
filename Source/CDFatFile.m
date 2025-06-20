// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-2019 Steve Nygard.

#import "CDFatFile.h"

#include <mach-o/arch.h>
#include <mach-o/fat.h>

#import "CDDataCursor.h"
#import "CDFatArch64.h"
#import "CDFatArch.h"
#import "CDMachOFile.h"

@implementation CDFatFile
{
    NSMutableArray *_arches;
    bool _isFat64;
    bool _isSwapped;
}

- (id)init;
{
    if ((self = [super init])) {
        _arches = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (id)initWithData:(NSData *)data filename:(NSString *)filename searchPathState:(CDSearchPathState *)searchPathState;
{
    if ((self = [super initWithData:data filename:filename searchPathState:searchPathState])) {
        CDDataCursor *cursor = [[CDDataCursor alloc] initWithData:data];

        struct fat_header header;
        header.magic = [cursor readBigInt32];

        if ((header.magic == FAT_CIGAM) || (header.magic == FAT_CIGAM_64)) {
            _isSwapped = true;
        } else {
            _isSwapped = false;
        }

        //NSLog(@"(testing fat) magic: 0x%x", header.magic);
        if ((header.magic != FAT_MAGIC) && (header.magic != FAT_MAGIC_64) && (header.magic != FAT_CIGAM) && (header.magic != FAT_CIGAM_64)) {
            return nil;
        }

        _arches = [[NSMutableArray alloc] init];

        if (_isSwapped == true) {
            header.nfat_arch = [cursor readLittleInt32];
        } else {
            header.nfat_arch = [cursor readBigInt32];
        }

        //NSLog(@"nfat_arch: %u", header.nfat_arch);
        for (NSUInteger index = 0; index < header.nfat_arch; index++) {
            if (header.magic == FAT_MAGIC) {
                CDFatArch *arch = [[CDFatArch alloc] initWithDataCursor:cursor bigendian:true];
                arch.fatFile = self;
                [_arches addObject:arch];
                _isFat64 = false;
            } else if (header.magic == FAT_CIGAM) {
                CDFatArch *arch = [[CDFatArch alloc] initWithDataCursor:cursor bigendian:false];
                arch.fatFile = self;
                [_arches addObject:arch];
                _isFat64 = false;
            } else if (header.magic == FAT_CIGAM_64) {
                CDFatArch64 *arch = [[CDFatArch64 alloc] initWithDataCursor:cursor bigendian:false];
                arch.fatFile = self;
                [_arches addObject:arch];
                _isFat64 = true;
            } else {
                CDFatArch64 *arch = [[CDFatArch64 alloc] initWithDataCursor:cursor bigendian:true];
                arch.fatFile = self;
                [_arches addObject:arch];
                _isFat64 = true;
            }
        }
    }

    return self;
}

#pragma mark - Debugging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@:%p> %lu arches", NSStringFromClass([self class]), self, [self.arches count]];
}

#pragma mark -


// Case 1: no arch specified
//  - check main file for these, then lock down on that arch:
//    - local arch, 64 bit
//    - local arch, 32 bit
//    - any arch, 64 bit
//    - any arch, 32 bit
//
// Case 2: you specified a specific arch (i386, x86_64, ppc, ppc7400, ppc64, etc.)
//  - only that arch
//
// In either case, we can ignore the cpu subtype

// Returns YES on success, NO on failure.
- (BOOL)bestMatchForArch:(CDArch *)ioArchPtr;
{
    cpu_type_t targetType = 0;

    if (_isSwapped == true) {
        targetType = OSSwapInt32(ioArchPtr->cputype) & OSSwapInt32(~CPU_ARCH_MASK);
    } else {
        targetType = ioArchPtr->cputype & ~CPU_ARCH_MASK;
    }

    if (_isFat64 == false) {
        // Target architecture, 64 bit
        for (CDFatArch *fatArch in self.arches) {
            if (fatArch.maskedCPUType == targetType && fatArch.uses64BitABI) {
                if (ioArchPtr != NULL) *ioArchPtr = fatArch.arch;
                return YES;
            }
        }

        // Target architecture, 32 bit
        for (CDFatArch *fatArch in self.arches) {
            if (fatArch.maskedCPUType == targetType && fatArch.uses64BitABI == NO) {
                if (ioArchPtr != NULL) *ioArchPtr = fatArch.arch;
                return YES;
            }
        }

        // Any architecture, 64 bit
        for (CDFatArch *fatArch in self.arches) {
            if (fatArch.uses64BitABI) {
                if (ioArchPtr != NULL) *ioArchPtr = fatArch.arch;
                return YES;
            }
        }

        // Any architecture, 32 bit
        for (CDFatArch *fatArch in self.arches) {
            if (fatArch.uses64BitABI == NO) {
                if (ioArchPtr != NULL) *ioArchPtr = fatArch.arch;
                return YES;
            }
        }
    } else {
        // Target architecture, 64 bit
        for (CDFatArch64 *fatArch in self.arches) {
            if (fatArch.maskedCPUType == targetType && fatArch.uses64BitABI) {
                if (ioArchPtr != NULL) *ioArchPtr = fatArch.arch;
                return YES;
            }
        }

        // Target architecture, 32 bit
        for (CDFatArch64 *fatArch in self.arches) {
            if (fatArch.maskedCPUType == targetType && fatArch.uses64BitABI == NO) {
                if (ioArchPtr != NULL) *ioArchPtr = fatArch.arch;
                return YES;
            }
        }

        // Any architecture, 64 bit
        for (CDFatArch64 *fatArch in self.arches) {
            if (fatArch.uses64BitABI) {
                if (ioArchPtr != NULL) *ioArchPtr = fatArch.arch;
                return YES;
            }
        }

        // Any architecture, 32 bit
        for (CDFatArch64 *fatArch in self.arches) {
            if (fatArch.uses64BitABI == NO) {
                if (ioArchPtr != NULL) *ioArchPtr = fatArch.arch;
                return YES;
            }
        }
    }

    // Any architecture
    if ([self.arches count] > 0) {
        if (ioArchPtr != NULL) *ioArchPtr = [self.arches[0] arch];
        return YES;
    }

    return NO;
}

- (CDFatArch64 *)fatArchWithArch64:(CDArch)cdarch;
{
    for (CDFatArch64 *arch in self.arches) {
        if (arch.cputype == cdarch.cputype && arch.maskedCPUSubtype == (cdarch.cpusubtype & ~CPU_SUBTYPE_MASK))
            return arch;
    }

    return nil;
}

- (CDFatArch *)fatArchWithArch:(CDArch)cdarch;
{
    for (CDFatArch *arch in self.arches) {
        if (arch.cputype == cdarch.cputype && arch.maskedCPUSubtype == (cdarch.cpusubtype & ~CPU_SUBTYPE_MASK))
            return arch;
    }

    return nil;
}

- (CDMachOFile *)machOFileWithArch:(CDArch)cdarch;
{
    if (_isFat64 == true) {
        return [[self fatArchWithArch64:cdarch] machOFile];
    }

    return [[self fatArchWithArch:cdarch] machOFile];
}

- (NSArray *)archNames;
{
    NSMutableArray *archNames = [NSMutableArray array];
    for (CDFatArch *arch in self.arches)
        [archNames addObject:arch.archName];

    return archNames;
}

- (NSString *)architectureNameDescription;
{
    return [self.archNames componentsJoinedByString:@", "];
}

#pragma mark -

- (void)addArchitecture64:(CDFatArch64 *)fatArch;
{
    fatArch.fatFile = self;
    [self.arches addObject:fatArch];
}

- (void)addArchitecture:(CDFatArch *)fatArch;
{
    fatArch.fatFile = self;
    [self.arches addObject:fatArch];
}

- (BOOL)containsArchitecture:(CDArch)arch;
{
    if (_isFat64 == true) {
        return [self fatArchWithArch64:arch] != nil;
    }

    return [self fatArchWithArch:arch] != nil;
}

@end
