//
//  PXPFont.h
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PXPFont : NSObject

@property (nonatomic, readonly) CGFontRef cgFont;
@property (nonatomic, readonly) CGFloat pointSize;
@property (nonatomic, readonly) CGFloat ascender;
@property (nonatomic, readonly) CGFloat descender;
@property (nonatomic, readonly) CGFloat leading;
@property (nonatomic, readonly) CGFloat xHeight;
@property (nonatomic, readonly) CGFloat capHeight;
@property (nonatomic, readonly) NSString *familyName;
@property (nonatomic, readonly) NSString *fontName;
@property (nonatomic, readonly) NSString *postScriptName;

- (instancetype)initWithCGFont:(CGFontRef)font size:(CGFloat)fontSize;
- (instancetype)fontWithSize:(CGFloat)fontSize;

+ (instancetype)fontWithCGFont:(CGFontRef)font size:(CGFloat)fontSize;
+ (instancetype)fontWithUIFont:(UIFont *)font;

@end
