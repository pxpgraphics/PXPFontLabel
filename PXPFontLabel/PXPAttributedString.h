//
//  PXPAttributedString.h
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, PXPAttributedStringEnumerationOptions) {
	PXPAttributedStringEnumerationReverse = 1 << 1,
	PXPAttributedStringEnumerationLongestEffectiveRangeNotRequired = 1 << 20
};

typedef NS_ENUM(NSUInteger, PXPUnderlineStyles) {
	PXPUnderlineStyleNone = 0x0000,
	PXPUnderlineStyleSingle = 0x01
};

typedef NS_ENUM(NSUInteger, PXPAttributedStringUnderlinePatterns) {
	PXPAttributedStringUnderlinePatternSolid = 0x0000,
};

extern NSString * const PXPFontAttributeName;
extern NSString * const PXPForegroundColorAttributeName;
extern NSString * const PXPBackgroundColorAttributeName;
extern NSString * const PXPUnderlineStyleAttributeName;

extern NSUInteger const PXPAttributedStringUnderlineStyleMask;
extern NSUInteger const PXPAttributedStringUnderlinePatternMask;

@interface PXPAttributedString : NSObject <NSCoding, NSCopying, NSMutableCopying>
{
	NSMutableString *_buffer;
	NSMutableArray *_attributes;
}

@property (nonatomic, strong, readonly) NSMutableString	*buffer;
@property (nonatomic, strong, readonly) NSMutableArray *attributes;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly) NSString *string;

- (instancetype)initWithAttributedString:(PXPAttributedString *)attrStr;
- (instancetype)initWithString:(NSString *)str;
- (instancetype)initWithString:(NSString *)str attributes:(NSDictionary *)attrs;
- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range;
- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit;
- (instancetype)attributedSubstringFromRange:(NSRange)range;
- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range;
- (NSDictionary *)attributesAtIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit;
- (void)enumerateAttribute:(NSString *)attrName inRange:(NSRange)enumerationRange options:(PXPAttributedStringEnumerationOptions)opts usingBlock:(void (^)(id value, NSRange range, BOOL *stop))block;
- (void)enumerateAttributesInRange:(NSRange)enumerationRange options:(PXPAttributedStringEnumerationOptions)opts usingBlock:(void (^)(NSDictionary *attrs, NSRange range, BOOL *stop))block;
- (BOOL)isEqualToAttributedString:(PXPAttributedString *)otherStr;

@end

@interface PXPMutableAttributedString : PXPAttributedString

- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary *)attributes range:(NSRange)range;
- (void)appendAttributedString:(PXPAttributedString *)str;
- (void)deleteCharactersInRange:(NSRange)range;
- (void)insertAttributedString:(PXPAttributedString *)str atIndex:(NSUInteger)idx;
- (void)removeAttribute:(NSString *)name range:(NSRange)range;
- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(PXPAttributedString *)str;
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str;
- (void)setAttributedString:(PXPAttributedString *)str;
- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)range;

@end
