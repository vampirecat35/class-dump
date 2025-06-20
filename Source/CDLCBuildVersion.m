// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-2019 Steve Nygard.

#import "CDLCBuildVersion.h"

#import "CDMachOFile.h"

static NSString *NSStringFromBuildVersionPlatform(uint32_t platform)
{
    switch (platform) {
        case PLATFORM_ANY:                 return @"any";
        case PLATFORM_MACOS:               return @"macOS";
        case PLATFORM_IOS:                 return @"iOS";
        case PLATFORM_TVOS:                return @"tvOS";
        case PLATFORM_WATCHOS:             return @"watchOS";
        case PLATFORM_BRIDGEOS:            return @"bridgeOS";
#ifndef PLATFORM_IOSMAC
        case PLATFORM_MACCATALYST:         return @"macCatalyst";
#else /* PLATFORM_IOSMAC */
        case PLATFORM_IOSMAC:              return @"iOS Mac";
#endif /* PLATFORM_IOSMAC */
        case PLATFORM_IOSSIMULATOR:        return @"iOS Simulator";
        case PLATFORM_TVOSSIMULATOR:       return @"tvOS Simulator";
        case PLATFORM_WATCHOSSIMULATOR:    return @"watchOS Simulator";
        case PLATFORM_DRIVERKIT:           return @"DriverKit";
        case PLATFORM_VISIONOS:            return @"visionOS";
        case PLATFORM_VISIONOSSIMULATOR:   return @"visionOS Simulator";

        case PLATFORM_FIRMWARE:            return @"firmware";
        case PLATFORM_SEPOS:               return @"sepOS";

        case PLATFORM_MACOS_EXCLAVECORE:   return @"exclaveCore";
        case PLATFORM_MACOS_EXCLAVEKIT:    return @"exclaveKit";
        case PLATFORM_IOS_EXCLAVECORE:     return @"iOS exclaveCore";
        case PLATFORM_IOS_EXCLAVEKIT:      return @"iOS exclaveKit";
        case PLATFORM_TVOS_EXCLAVECORE:    return @"tvOS exclaveCore";
        case PLATFORM_TVOS_EXCLAVEKIT:     return @"tvOS exclaveKit";
        case PLATFORM_WATCHOS_EXCLAVECORE: return @"watchOS exclaveCore";
        case PLATFORM_WATCHOS_EXCLAVEKIT:  return @"watchOS exclaveKit";
        case PLATFORM_VISIONOS_EXCLAVECORE:return @"visionOS exclaveCore";
        case PLATFORM_VISIONOS_EXCLAVEKIT: return @"visionOS exclaveKit";

        default:               return [NSString stringWithFormat:@"Unknown platform %x", platform];
    }
}

static NSString *NSStringFromBuildVersionTool(uint32_t tool)
{
    switch (tool) {
        case TOOL_CLANG:           return @"clang";
        case TOOL_SWIFT:           return @"swift";
        case TOOL_LD:              return @"ld";
        case TOOL_LLD:             return @"lld";

        case TOOL_METAL:           return @"metal";
        case TOOL_AIRLLD:          return @"airlld";
        case TOOL_AIRNT:           return @"airnt";
        case TOOL_AIRNT_PLUGIN:    return @"airnt-plugin";
        case TOOL_AIRPACK:         return @"airpack";
        case TOOL_GPUARCHIVER:     return @"gpuarchiver";
        case TOOL_METAL_FRAMEWORK: return @"metal-framework";

        default:         return [NSString stringWithFormat:@"Unknown tool %x", tool];
    }
}

static NSString *NSStringFromBuildVersionToolNotATuple(uint64_t tuple)
{
    uint32_t tool = tuple >> 32;
    uint32_t version = tuple & 0xffffffff;
    return [NSString stringWithFormat:@"%@ %u.%u.%u", NSStringFromBuildVersionTool(tool),
            version >> 16,
            (version >> 8) & 0xff,
            version & 0xff];
}

@implementation CDLCBuildVersion
{
    struct build_version_command _buildVersionCommand;
    NSArray *_tools;
}

- (id)initWithDataCursor:(CDMachOFileDataCursor *)cursor;
{
    if ((self = [super initWithDataCursor:cursor])) {
        _buildVersionCommand.cmd      = [cursor readInt32];
        _buildVersionCommand.cmdsize  = [cursor readInt32];
        _buildVersionCommand.platform = [cursor readInt32];
        _buildVersionCommand.minos    = [cursor readInt32];
        _buildVersionCommand.sdk      = [cursor readInt32];
        _buildVersionCommand.ntools   = [cursor readInt32];
        NSMutableArray *tools = [NSMutableArray array];
        for (NSUInteger index = 0; index < _buildVersionCommand.ntools; index++) {
            // ISO tuples.
            uint32_t tool    = [cursor readInt32];
            uint32_t version = [cursor readInt32];
            uint64_t iso_tuples = ((uint64_t)tool << 32) | version;
            [tools addObject:@(iso_tuples)];
        }
        _tools = [tools copy];
    }

    return self;
}

#pragma mark -

- (uint32_t)cmd;
{
    return _buildVersionCommand.cmd;
}

- (uint32_t)cmdsize;
{
    return _buildVersionCommand.cmdsize;
}

- (NSString *)buildVersionString;
{
    return [NSString stringWithFormat:@"Platform: %@ %u.%u.%u, SDK: %u.%u.%u",
            NSStringFromBuildVersionPlatform(_buildVersionCommand.platform),
            _buildVersionCommand.minos >> 16,
            (_buildVersionCommand.minos >> 8) & 0xff,
            _buildVersionCommand.minos & 0xff,

            _buildVersionCommand.sdk >> 16,
            (_buildVersionCommand.sdk >> 8) & 0xff,
            _buildVersionCommand.sdk & 0xff];
}

- (NSArray *)toolStrings;
{
    NSMutableArray *tools = [NSMutableArray array];
    // iso map
    for (NSNumber *tuple in _tools) {
        [tools addObject:NSStringFromBuildVersionToolNotATuple([tuple unsignedLongLongValue])];
    }

    return [tools copy];
}

- (void)appendToString:(NSMutableString *)resultString verbose:(BOOL)isVerbose;
{
    [super appendToString:resultString verbose:isVerbose];

    [resultString appendFormat:@"    Build version: %@\n", self.buildVersionString];
}

@end
