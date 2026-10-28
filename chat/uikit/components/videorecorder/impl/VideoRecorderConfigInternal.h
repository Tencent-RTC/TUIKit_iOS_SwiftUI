// Copyright (c) 2024 Tencent. All rights reserved.
// Created by eddardliu on 2024/10/21.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoRecorderConfigInternal : NSObject
+ (instancetype)sharedInstance;
@property(nonatomic) int minDurationMs;
@property(nonatomic) int maxDurationMs;
@property(nonatomic) int videoQuality;
@property(nonatomic) int recordMode;
@property(nonatomic) BOOL frontCamera;
@property(nonatomic) BOOL supportTorch;
@property(nonatomic) BOOL supportAspect;
@property(nonatomic, strong) UIColor *themeColor;
- (void)resetToDefaults;
- (BOOL)isSupportRecordAspect;
- (BOOL)isSupportRecordTorch;

- (UIColor*)getThemeColor;
- (int)getMaxRecordDurationMs;
- (int)getMinRecordDurationMs;
- (int)getVideoQuality;
- (int)getRecordeMode;
- (BOOL)isDefaultFrontCamera;
@end

NS_ASSUME_NONNULL_END
