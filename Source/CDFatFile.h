// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-2019 Steve Nygard.

#import "CDFile.h"

@class CDFatArch, CDFatArch64;

@interface CDFatFile : CDFile

@property (readonly) NSMutableArray *arches;
@property (nonatomic, readonly) NSArray *archNames;
@property (nonatomic, readonly) bool isFat64;
@property (nonatomic, readonly) bool isSwapped;

- (void)addArchitecture:(CDFatArch *)fatArch;
- (void)addArchitecture64:(CDFatArch64 *)fatArch;
- (BOOL)containsArchitecture:(CDArch)arch;

@end
