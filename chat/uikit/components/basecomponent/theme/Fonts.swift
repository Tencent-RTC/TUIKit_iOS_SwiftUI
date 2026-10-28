import SwiftUI
import UIKit

public let FontScheme = SemanticFontScheme(
    title1Bold: Fonts.Bold40,
    title2Bold: Fonts.Bold36,
    title3Bold: Fonts.Bold34,
    title4Bold: Fonts.Bold32,
    body1Bold: Fonts.Bold28,
    body2Bold: Fonts.Bold24,
    body3Bold: Fonts.Bold20,
    body4Bold: Fonts.Bold18,
    caption1Bold: Fonts.Bold16,
    caption2Bold: Fonts.Bold14,
    caption3Bold: Fonts.Bold12,
    caption4Bold: Fonts.Bold10,
    title1Medium: Fonts.Medium40,
    title2Medium: Fonts.Medium36,
    title3Medium: Fonts.Medium34,
    title4Medium: Fonts.Medium32,
    body1Medium: Fonts.Medium28,
    body2Medium: Fonts.Medium24,
    body3Medium: Fonts.Medium20,
    body4Medium: Fonts.Medium18,
    caption1Medium: Fonts.Medium16,
    caption2Medium: Fonts.Medium14,
    caption3Medium: Fonts.Medium12,
    caption4Medium: Fonts.Medium10,
    title1Regular: Fonts.Regular40,
    title2Regular: Fonts.Regular36,
    title3Regular: Fonts.Regular34,
    title4Regular: Fonts.Regular32,
    body1Regular: Fonts.Regular28,
    body2Regular: Fonts.Regular24,
    body3Regular: Fonts.Regular20,
    body4Regular: Fonts.Regular18,
    caption1Regular: Fonts.Regular16,
    caption2Regular: Fonts.Regular14,
    caption3Regular: Fonts.Regular12,
    caption4Regular: Fonts.Regular10
)

public struct SemanticFontScheme {
    public let title1Bold: Font
    public let title2Bold: Font
    public let title3Bold: Font
    public let title4Bold: Font
    public let body1Bold: Font
    public let body2Bold: Font
    public let body3Bold: Font
    public let body4Bold: Font
    public let caption1Bold: Font
    public let caption2Bold: Font
    public let caption3Bold: Font
    public let caption4Bold: Font
    public let title1Medium: Font
    public let title2Medium: Font
    public let title3Medium: Font
    public let title4Medium: Font
    public let body1Medium: Font
    public let body2Medium: Font
    public let body3Medium: Font
    public let body4Medium: Font
    public let caption1Medium: Font
    public let caption2Medium: Font
    public let caption3Medium: Font
    public let caption4Medium: Font
    public let title1Regular: Font
    public let title2Regular: Font
    public let title3Regular: Font
    public let title4Regular: Font
    public let body1Regular: Font
    public let body2Regular: Font
    public let body3Regular: Font
    public let body4Regular: Font
    public let caption1Regular: Font
    public let caption2Regular: Font
    public let caption3Regular: Font
    public let caption4Regular: Font
}

public enum UIKitFontScheme {
    public static let title1Bold = UIFont.systemFont(ofSize: 40, weight: .bold)
    public static let title2Bold = UIFont.systemFont(ofSize: 36, weight: .bold)
    public static let title3Bold = UIFont.systemFont(ofSize: 34, weight: .bold)
    public static let title4Bold = UIFont.systemFont(ofSize: 32, weight: .bold)
    public static let body1Bold = UIFont.systemFont(ofSize: 28, weight: .bold)
    public static let body2Bold = UIFont.systemFont(ofSize: 24, weight: .bold)
    public static let body3Bold = UIFont.systemFont(ofSize: 20, weight: .bold)
    public static let body4Bold = UIFont.systemFont(ofSize: 18, weight: .bold)
    public static let caption1Bold = UIFont.systemFont(ofSize: 16, weight: .bold)
    public static let caption2Bold = UIFont.systemFont(ofSize: 14, weight: .bold)
    public static let caption3Bold = UIFont.systemFont(ofSize: 12, weight: .bold)
    public static let caption4Bold = UIFont.systemFont(ofSize: 10, weight: .bold)
    public static let title1Medium = UIFont.systemFont(ofSize: 40, weight: .medium)
    public static let title2Medium = UIFont.systemFont(ofSize: 36, weight: .medium)
    public static let title3Medium = UIFont.systemFont(ofSize: 34, weight: .medium)
    public static let title4Medium = UIFont.systemFont(ofSize: 32, weight: .medium)
    public static let body1Medium = UIFont.systemFont(ofSize: 28, weight: .medium)
    public static let body2Medium = UIFont.systemFont(ofSize: 24, weight: .medium)
    public static let body3Medium = UIFont.systemFont(ofSize: 20, weight: .medium)
    public static let body4Medium = UIFont.systemFont(ofSize: 18, weight: .medium)
    public static let caption1Medium = UIFont.systemFont(ofSize: 16, weight: .medium)
    public static let caption2Medium = UIFont.systemFont(ofSize: 14, weight: .medium)
    public static let caption3Medium = UIFont.systemFont(ofSize: 12, weight: .medium)
    public static let caption4Medium = UIFont.systemFont(ofSize: 10, weight: .medium)
    public static let title1Regular = UIFont.systemFont(ofSize: 40)
    public static let title2Regular = UIFont.systemFont(ofSize: 36)
    public static let title3Regular = UIFont.systemFont(ofSize: 34)
    public static let title4Regular = UIFont.systemFont(ofSize: 32)
    public static let body1Regular = UIFont.systemFont(ofSize: 28)
    public static let body2Regular = UIFont.systemFont(ofSize: 24)
    public static let body3Regular = UIFont.systemFont(ofSize: 20)
    public static let body4Regular = UIFont.systemFont(ofSize: 18)
    public static let caption1Regular = UIFont.systemFont(ofSize: 16)
    public static let caption2Regular = UIFont.systemFont(ofSize: 14)
    public static let caption3Regular = UIFont.systemFont(ofSize: 12)
    public static let caption4Regular = UIFont.systemFont(ofSize: 10)
}

private enum Fonts {
    static let Bold40 = Font(UIKitFontScheme.title1Bold)
    static let Bold36 = Font(UIKitFontScheme.title2Bold)
    static let Bold34 = Font(UIKitFontScheme.title3Bold)
    static let Bold32 = Font(UIKitFontScheme.title4Bold)
    static let Bold28 = Font(UIKitFontScheme.body1Bold)
    static let Bold24 = Font(UIKitFontScheme.body2Bold)
    static let Bold20 = Font(UIKitFontScheme.body3Bold)
    static let Bold18 = Font(UIKitFontScheme.body4Bold)
    static let Bold16 = Font(UIKitFontScheme.caption1Bold)
    static let Bold14 = Font(UIKitFontScheme.caption2Bold)
    static let Bold12 = Font(UIKitFontScheme.caption3Bold)
    static let Bold10 = Font(UIKitFontScheme.caption4Bold)
    static let Medium40 = Font(UIKitFontScheme.title1Medium)
    static let Medium36 = Font(UIKitFontScheme.title2Medium)
    static let Medium34 = Font(UIKitFontScheme.title3Medium)
    static let Medium32 = Font(UIKitFontScheme.title4Medium)
    static let Medium28 = Font(UIKitFontScheme.body1Medium)
    static let Medium24 = Font(UIKitFontScheme.body2Medium)
    static let Medium20 = Font(UIKitFontScheme.body3Medium)
    static let Medium18 = Font(UIKitFontScheme.body4Medium)
    static let Medium16 = Font(UIKitFontScheme.caption1Medium)
    static let Medium14 = Font(UIKitFontScheme.caption2Medium)
    static let Medium12 = Font(UIKitFontScheme.caption3Medium)
    static let Medium10 = Font(UIKitFontScheme.caption4Medium)
    static let Regular40 = Font(UIKitFontScheme.title1Regular)
    static let Regular36 = Font(UIKitFontScheme.title2Regular)
    static let Regular34 = Font(UIKitFontScheme.title3Regular)
    static let Regular32 = Font(UIKitFontScheme.title4Regular)
    static let Regular28 = Font(UIKitFontScheme.body1Regular)
    static let Regular24 = Font(UIKitFontScheme.body2Regular)
    static let Regular20 = Font(UIKitFontScheme.body3Regular)
    static let Regular18 = Font(UIKitFontScheme.body4Regular)
    static let Regular16 = Font(UIKitFontScheme.caption1Regular)
    static let Regular14 = Font(UIKitFontScheme.caption2Regular)
    static let Regular12 = Font(UIKitFontScheme.caption3Regular)
    static let Regular10 = Font(UIKitFontScheme.caption4Regular)
}
