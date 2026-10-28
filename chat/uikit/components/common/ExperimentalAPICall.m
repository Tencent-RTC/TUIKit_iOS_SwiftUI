#import "ExperimentalAPICall.h"
#import <objc/message.h>

@implementation ExperimentalAPICall

+ (BOOL)invokeWithApi:(NSString *)api
               params:(NSString *)params
              success:(ExperimentalAPICallSuccess)success
              failure:(ExperimentalAPICallFailure)failure {
    Class managerClass = NSClassFromString(@"V2TIMManager");
    if (managerClass == nil) {
        return NO;
    }
    SEL sharedSelector = NSSelectorFromString(@"sharedInstance");
    if (![managerClass respondsToSelector:sharedSelector]) {
        return NO;
    }
    id manager = ((id (*)(Class, SEL))objc_msgSend)(managerClass, sharedSelector);
    if (manager == nil) {
        return NO;
    }
    SEL callSelector = NSSelectorFromString(@"callExperimentalAPI:param:succ:fail:");
    if (![manager respondsToSelector:callSelector]) {
        return NO;
    }
    typedef NSObject *(*CallFunc)(id, SEL, NSString *, NSObject *, ExperimentalAPICallSuccess, ExperimentalAPICallFailure);
    ((CallFunc)objc_msgSend)(manager, callSelector, api, params, success, failure);
    return YES;
}

@end
