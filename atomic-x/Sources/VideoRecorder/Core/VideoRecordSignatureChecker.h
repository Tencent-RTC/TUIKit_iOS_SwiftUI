// Copyright (c) 2024 Tencent. All rights reserved.
// Author: eddardliu

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VideoRecordSignatureResultCode) {
    ResultCodeSUCCESS = 0,
    ResultCodeERROR_NO_LITEAV_SDK = -7,
    ResultCodeERROR_NO_IM_SDK = -8,
    ResultCodeERROR_APP_ID_EMPTY = -9,
    ResultCodeERROR_NO_SIGNATURE = -10
};

@interface VideoRecordSignatureChecker : NSObject
+ (void)load;
+ (instancetype)shareInstance;
- (void)startUpdateSignature;
- (Boolean)setSignatureToSDK:(NSString*)sdkAppId;
- (VideoRecordSignatureResultCode)getSetSignatureResult;
@end

NS_ASSUME_NONNULL_END
