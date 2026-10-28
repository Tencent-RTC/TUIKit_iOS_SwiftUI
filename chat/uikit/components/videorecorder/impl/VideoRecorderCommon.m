// Copyright (c) 2024 Tencent. All rights reserved.
// Author: eddardliu

#import "VideoRecorderCommon.h"

#define ChatEngineLanguageKey @"AtomicXLanguageKey"

@interface NSString (TUIHexColorPrivate)
- (NSUInteger)_hexValue;
@end

@implementation NSString (TUIHexColorPrivate)
- (NSUInteger)_hexValue {
    NSUInteger result = 0;
    sscanf([self UTF8String], "%lx", &result);
    return result;
}
@end

@implementation VideoRecorderCommon

+ (NSBundle *)stringBundle {
    NSBundle *modleBundle = [self modleNSBundle];
    if (!modleBundle) {
        NSLog(@"error: can not find ChatUIKitBundle");
        return nil;
    }

    NSURL *chatLocalizableURL = [modleBundle URLForResource:@"ChatLocalizable" withExtension:@"bundle"];
    if (!chatLocalizableURL) {
        return nil;
    }
    return [NSBundle bundleWithURL:chatLocalizableURL];
}

+ (NSBundle *)modleNSBundle {
    NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
    NSURL *atomicBundleURL = [mainBundle URLForResource:@"ChatUIKitBundle" withExtension:@"bundle"];
    if (!atomicBundleURL) {
        return nil;
    }
    NSBundle *atomicBundle = [NSBundle bundleWithURL:atomicBundleURL];
    return atomicBundle;
}

+ (UIImage *)bundleImageByName:(NSString *)name {
    if (self.modleNSBundle == nil) {
        return nil;
    }
    return [UIImage imageNamed:name inBundle:self.modleNSBundle compatibleWithTraitCollection:nil];
}

+ (NSString *)localizedStringForKey:(NSString *)key {
    NSBundle *bundle = self.stringBundle;
    NSString *lang = [self getPreferredLanguage];
    NSString *languagePath = [bundle pathForResource:lang ofType:@"lproj" inDirectory:@"Localizable"];
    NSBundle *languageBundle = languagePath ? [NSBundle bundleWithPath:languagePath] : nil;
    NSString *localized = [languageBundle localizedStringForKey:key value:key table:@"Localizable"];
    if (localized != nil && ![localized isEqualToString:key]) {
        return localized;
    }
    NSString *englishPath = [bundle pathForResource:@"en" ofType:@"lproj" inDirectory:@"Localizable"];
    NSBundle *englishBundle = englishPath ? [NSBundle bundleWithPath:englishPath] : nil;
    return [englishBundle localizedStringForKey:key value:key table:@"Localizable"] ?: key;
}

+ (UIColor *)colorFromHex:(NSString *)hex {
    return [VideoRecorderCommon tui_colorWithHex:hex];
}

+ (UIImage *__nullable)dynamicImage:(NSString *)imageKey defaultImageName:(NSString *)image {
    if (VideoRecorderCommon.modleNSBundle == nil) {
        return nil;
    }


    return [UIImage imageNamed:image inBundle:VideoRecorderCommon.modleNSBundle compatibleWithTraitCollection:nil];
}

+ (UIColor *)dynamicColor:(NSString *)colorKey  defaultColor:(NSString *)hex {
    return [VideoRecorderCommon tui_colorWithHex:hex];
}

+ (UIColor *)tui_colorWithHex:(NSString *)hex {
    if ([hex isEqualToString:@""]) {
        return [UIColor clearColor];
    }

    if ([hex hasPrefix:@"#"]) {
        hex = [hex substringFromIndex:1];
    } else if ([hex hasPrefix:@"0x"]) {
        hex = [hex substringFromIndex:2];
    }

    NSUInteger length = [hex length];
    if (length != 3 && length != 6 && length != 8) {
        return [[UIColor alloc] init];
    }

    if (length == 3) {
        NSString *r = [hex substringWithRange:NSMakeRange(0, 1)];
        NSString *g = [hex substringWithRange:NSMakeRange(1, 1)];
        NSString *b = [hex substringWithRange:NSMakeRange(2, 1)];
        hex = [NSString stringWithFormat:@"%@%@%@%@%@%@ff", r, r, g, g, b, b];
    } else if (length == 6) {
        hex = [hex stringByAppendingString:@"ff"];
    }

    CGFloat red = [[hex substringWithRange:NSMakeRange(0, 2)] _hexValue] / 255.0f;
    CGFloat green = [[hex substringWithRange:NSMakeRange(2, 2)] _hexValue] / 255.0f;
    CGFloat blue = [[hex substringWithRange:NSMakeRange(4, 2)] _hexValue] / 255.0f;
    CGFloat alpha = [[hex substringWithRange:NSMakeRange(6, 2)] _hexValue] / 255.0f;

    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (NSString *)getPreferredLanguage {
    NSString* gCustomLanguage = [NSUserDefaults.standardUserDefaults objectForKey:ChatEngineLanguageKey];
    if (gCustomLanguage != nil && gCustomLanguage.length > 0) {
        return gCustomLanguage;
    }

    NSString *language = [NSLocale preferredLanguages].firstObject;
    if ([language hasPrefix:@"en"]) {
        language = @"en";
    } else if ([language hasPrefix:@"zh"]) {
        if ([language rangeOfString:@"Hans"].location != NSNotFound) {
            language = @"zh-Hans";
        } else {
            language = @"zh-Hant";
        }
    } else if ([language hasPrefix:@"ar"]) {
        language = @"ar";
    }
    else {
        language = @"en";
    }

    return language;
}

@end
