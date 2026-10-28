#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ExperimentalAPICallSuccess)(NSObject * _Nullable result);
typedef void (^ExperimentalAPICallFailure)(int code, NSString * _Nullable desc);

@interface ExperimentalAPICall : NSObject

+ (BOOL)invokeWithApi:(NSString *)api
               params:(NSString *)params
              success:(nullable ExperimentalAPICallSuccess)success
              failure:(nullable ExperimentalAPICallFailure)failure;

@end

NS_ASSUME_NONNULL_END
