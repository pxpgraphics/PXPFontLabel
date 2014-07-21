//
//  PXPFont.m
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import "PXPFont.h"

@interface PXPFont ()

@property (nonatomic, readonly) CGFloat ratio;
@property (nonatomic, readwrite) CGFontRef cgFont;
@property (nonatomic, readwrite) CGFloat pointSize;
@property (nonatomic, readwrite) CGFloat ascender;
@property (nonatomic, readwrite) CGFloat descender;
@property (nonatomic, readwrite) CGFloat leading;
@property (nonatomic, readwrite) CGFloat xHeight;
@property (nonatomic, readwrite) CGFloat capHeight;
@property (nonatomic, readwrite) NSString *familyName;
@property (nonatomic, readwrite) NSString *fontName;
@property (nonatomic, readwrite) NSString *postScriptName;

- (NSString *)copyNameTableEntryForId:(UInt16)nameId;

@end

@implementation PXPFont

#pragma mark - Lifecycle methods

- (instancetype)init
{
	NSAssert(NO, @"-init is not valid for PXPFont");
	return nil;
}

- (instancetype)initWithCGFont:(CGFontRef)font size:(CGFloat)fontSize
{
	self = [super init];
	if (self) {
		_cgFont = CGFontRetain(font);
		_pointSize = fontSize;
		_ratio = fontSize / CGFontGetUnitsPerEm(font);
	}
	return self;
}

- (instancetype)fontWithSize:(CGFloat)fontSize
{
	if (fontSize == self.pointSize) {
		return self;
	}

	NSParameterAssert(fontSize > 0.0f);
	return [[PXPFont alloc] initWithCGFont:self.cgFont size:fontSize];
}

- (void)dealloc
{
	CGFontRelease(_cgFont);
}

#pragma mark - Private methods

- (NSString *)copyNameTableEntryForId:(UInt16)aNameId
{
	CFDataRef nameTable = CGFontCopyTableForTag(self.cgFont, 'name');
	NSAssert1(nameTable != NULL, @"CGFontCopyTableForTag returned NULL for 'name' tag in font %@",
			  (__bridge id)CFCopyDescription(self.cgFont));
	const UInt8 * const bytes = CFDataGetBytePtr(nameTable);
	NSAssert1(OSReadBigInt16(bytes, 0) == 0, @"name table for font %@ has bad version number",
			  (__bridge id)CFCopyDescription(self.cgFont));
	const UInt16 count = OSReadBigInt16(bytes, 2);
	const UInt16 stringOffset = OSReadBigInt16(bytes, 4);
	const UInt8 * const nameRecords = &bytes[6];
	UInt16 nameLength = 0;
	UInt16 nameOffset = 0;
	NSStringEncoding encoding = 0;
	for (UInt16 i = 0; i < count; i++) {
		const uintptr_t recordOffset = 12 * i;
		const UInt16 nameId = OSReadBigInt16(nameRecords, recordOffset + 6);
		if (nameId != aNameId) {
			continue;
		}
		const UInt16 platformId = OSReadBigInt16(nameRecords, recordOffset + 0);
		const UInt16 platformSpecificId = OSReadBigInt16(nameRecords, recordOffset + 2);
		encoding = 0;
		// for now, we only support a subset of encodings
		switch (platformId) {
			case 0: // Unicode
				encoding = NSUTF16StringEncoding;
				break;
			case 1: // Macintosh
				switch (platformSpecificId) {
					case 0:
						encoding = NSMacOSRomanStringEncoding;
						break;
				}
			case 3: // Microsoft
				switch (platformSpecificId) {
					case 1:
						encoding = NSUTF16StringEncoding;
						break;
				}
		}
		if (encoding == 0) {
			continue;
		}
		nameLength = OSReadBigInt16(nameRecords, recordOffset + 8);
		nameOffset = OSReadBigInt16(nameRecords, recordOffset + 10);
		break;
	}
	NSString *result = nil;
	if (nameOffset > 0) {
		const UInt8 *nameBytes = &bytes[stringOffset + nameOffset];
		result = [[NSString alloc] initWithBytes:nameBytes length:nameLength encoding:encoding];
	}
	CFRelease(nameTable);
	return result;
}

#pragma mark - Public methods

- (CGFloat)ascender
{
	return ceilf(self.ratio * CGFontGetAscent(self.cgFont));
}

- (CGFloat)descender
{
	return floorf(self.ratio * CGFontGetDescent(self.cgFont));
}

- (CGFloat)leading
{
	return (self.ascender - self.descender);
}

- (CGFloat)capHeight
{
	return ceilf(self.ratio * CGFontGetCapHeight(self.cgFont));
}

- (CGFloat)xHeight
{
	return ceilf(self.ratio * CGFontGetXHeight(self.cgFont));
}

- (NSString *)familyName
{
	if (!_familyName) {
		_familyName = [self copyNameTableEntryForId:1];
	}
	return _familyName;
}

- (NSString *)fontName
{
	if (!_fontName) {
		_fontName = [self copyNameTableEntryForId:1];
	}
	return _fontName;
}

- (NSString *)postScriptName
{
	if (!_postScriptName) {
		_postScriptName = [self copyNameTableEntryForId:6];
	}
	return _postScriptName;
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[PXPFont class]]) {
		return NO;
	}

	PXPFont *font = (PXPFont *)object;
	return (font.cgFont == self.cgFont && font.pointSize == self.pointSize);
}

+ (instancetype)fontWithCGFont:(CGFontRef)font size:(CGFloat)fontSize
{
	return [[self alloc] initWithCGFont:font size:fontSize];
}

+ (instancetype)fontWithUIFont:(UIFont *)aFont
{
	NSParameterAssert(aFont != nil);
	CGFontRef cgFont = CGFontCreateWithFontName((CFStringRef)aFont.fontName);
	PXPFont *font = [[self alloc] initWithCGFont:cgFont size:aFont.pointSize];
	CGFontRelease(cgFont);
	return font;
}

@end
