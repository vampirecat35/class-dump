// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-2019 Steve Nygard.

#include <mach/machine.h> // For cpu_type_t, cpu_subtype_t

typedef struct {
    cpu_type_t cputype;
    cpu_subtype_t cpusubtype;
} CDArch;

@class CDMachOFile, CDSearchPathState;

NSString *CDImportNameForPath(NSString *path);
NSString *CDNameForCPUType(cpu_type_t cputype, cpu_subtype_t cpusubtype);
CDArch CDArchFromName(NSString *name);
BOOL CDArchUses64BitABI(CDArch arch);
BOOL CDArchUses64BitLibraries(CDArch arch);

@interface CDFile : NSObject

// Returns CDFatFile or CDMachOFile
+ (id)fileWithContentsOfFile:(NSString *)filename cache:(NSString *)cache searchPathState:(CDSearchPathState *)searchPathState isCache:(BOOL)aIsCache;

- (id)initWithData:(NSData *)data filename:(NSString *)filename searchPathState:(CDSearchPathState *)searchPathState isCache:(BOOL)aIsCache;

@property (readonly) NSString *filename;
@property (readonly) NSData *data;
@property (readonly) CDSearchPathState *searchPathState;

- (BOOL)bestMatchForLocalArch:(CDArch *)oArchPtr;
- (BOOL)bestMatchForArch:(CDArch *)ioArchPtr;
- (CDMachOFile *)machOFileWithArch:(CDArch)arch;

@property (nonatomic, readonly) NSString *architectureNameDescription;

@end
