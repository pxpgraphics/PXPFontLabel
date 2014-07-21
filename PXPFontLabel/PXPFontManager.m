//
//  PXPFontManager.m
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import "PXPFontManager.h"
#import "PXPFont.h"

@implementation PXPFontManager

#pragma mark - Lifecycle methods

- (instancetype)init
{
	self = [super init];
	if (self) {
		_fonts = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		_urls = [NSMutableDictionary dictionary];
	}
	return self;
}

+ (instancetype)sharedManager
{
	static PXPFontManager *sharedManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[PXPFontManager alloc] init];
	});
	return sharedManager;
}

- (void)dealloc {
	CFRelease(_fonts);
}

#pragma mark - Public methods

- (BOOL)loadFont:(NSString *)filename {
	NSString *fontPath = [[NSBundle mainBundle] pathForResource:filename ofType:@"ttf"];
	if (fontPath == nil) {
		fontPath = [[NSBundle mainBundle] pathForResource:filename ofType:nil];
	}
	if (fontPath == nil) return NO;

	NSURL *url = [NSURL fileURLWithPath:fontPath];
	if ([self loadFontURL:url]) {
		[_urls setObject:url forKey:filename];
		return YES;
	}
	return NO;
}

- (BOOL)loadFontURL:(NSURL *)url {
	CGDataProviderRef fontDataProvider = CGDataProviderCreateWithURL((CFURLRef)url);
	if (fontDataProvider == NULL) return NO;
	CGFontRef newFont = CGFontCreateWithDataProvider(fontDataProvider);
	CGDataProviderRelease(fontDataProvider);
	if (newFont == NULL) return NO;

	CFDictionarySetValue(_fonts, (__bridge const void *)(url), newFont);
	CGFontRelease(newFont);
	return YES;
}

- (CGFontRef)fontWithName:(NSString *)filename {
	CGFontRef font = NULL;
	NSURL *url = [_urls objectForKey:filename];
	if (url == nil && [self loadFont:filename]) {
		url = [_urls objectForKey:filename];
	}
	if (url != nil) {
		font = (CGFontRef)CFDictionaryGetValue(_fonts, (__bridge const void *)(url));
	}
	return font;
}

- (PXPFont *)pxpFontWithName:(NSString *)filename pointSize:(CGFloat)pointSize {
	NSURL *url = [_urls objectForKey:filename];
	if (url == nil && [self loadFont:filename]) {
		url = [_urls objectForKey:filename];
	}
	if (url != nil) {
		CGFontRef cgFont = (CGFontRef)CFDictionaryGetValue(_fonts, (__bridge const void *)(url));
		if (cgFont != NULL) {
			return [PXPFont fontWithCGFont:cgFont size:pointSize];
		}
	}
	return nil;
}

- (PXPFont *)pxpFontWithURL:(NSURL *)url pointSize:(CGFloat)pointSize {
	CGFontRef cgFont = (CGFontRef)CFDictionaryGetValue(_fonts, (__bridge const void *)(url));
	if (cgFont == NULL && [self loadFontURL:url]) {
		cgFont = (CGFontRef)CFDictionaryGetValue(_fonts, (__bridge const void*)(url));
	}
	if (cgFont != NULL) {
		return [PXPFont fontWithCGFont:cgFont size:pointSize];
	}
	return nil;
}

- (CFArrayRef)copyAllFonts {
	CFIndex count = CFDictionaryGetCount(_fonts);
	CGFontRef *values = (CGFontRef *)malloc(sizeof(CGFontRef) * count);
	CFDictionaryGetKeysAndValues(_fonts, NULL, (const void **)values);
	CFArrayRef array = CFArrayCreate(NULL, (const void **)values, count, &kCFTypeArrayCallBacks);
	free(values);
	return array;
}

@end
