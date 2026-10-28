// Copyright (c) 2024 Tencent. All rights reserved.
// Created by eddardliu on 2024/10/21.

#import "VideoRecorderConfigInternal.h"
#import "VideoRecorderCommon.h"

@implementation VideoRecorderConfigInternal

+ (instancetype)sharedInstance {
    static VideoRecorderConfigInternal *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self resetToDefaults];
    }
    return self;
}

- (void)resetToDefaults {
    self.minDurationMs = 2000;
    self.maxDurationMs = 15000;
    self.videoQuality = 2;
    self.recordMode = 0;
    self.frontCamera = NO;
    self.supportTorch = YES;
    self.supportAspect = YES;
    self.themeColor = [VideoRecorderCommon tui_colorWithHex:@"#147AFF"];
}

- (BOOL)isSupportRecordAspect {
    return self.supportAspect;
}

- (BOOL)isSupportRecordTorch {
    return self.supportTorch;
}

- (UIColor *)getThemeColor {
    return self.themeColor;
}

- (int)getVideoQuality {
    return self.videoQuality;
}

- (BOOL)isDefaultFrontCamera {
    return self.frontCamera;
}

- (int)getMaxRecordDurationMs {
    return self.maxDurationMs;
}

- (int)getMinRecordDurationMs {
    return self.minDurationMs;
}

- (int)getRecordeMode {
    return self.recordMode;
}

@end
