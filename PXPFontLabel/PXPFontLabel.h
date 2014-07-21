//
//  PXPFontLabel.h
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <UIKit/UIKit.h>

@class PXPFont;
@class PXPAttributedString;

@interface PXPFontLabel : UILabel
{
	void *reserved; // Works around a bug in UILabel.
}

@property (nonatomic, setter=setCGFont:) CGFontRef cgFont __AVAILABILITY_INTERNAL_DEPRECATED;
@property (nonatomic, assign) CGFloat pointSize __AVAILABILITY_INTERNAL_DEPRECATED;
@property (nonatomic, retain, setter=setZFont:) PXPFont *pxpFont;

/*
 * If attributedText is nil, fall back on using the inherited UILabel properties.
 * If attributedText is non-nil, the font/text/textColor.
 * In addition, adjustsFontSizeToFitWidth does not work with attributed text.
 */
@property (nonatomic, copy) PXPAttributedString *pxpAttributedText;
// -initWithFrame:fontName:pointSize: uses FontManager to look up the font name
- (instancetype)initWithFrame:(CGRect)frame fontName:(NSString *)fontName pointSize:(CGFloat)pointSize;
- (instancetype)initWithFrame:(CGRect)frame pxpFont:(PXPFont *)font;
- (instancetype)initWithFrame:(CGRect)frame font:(CGFontRef)font pointSize:(CGFloat)pointSize __AVAILABILITY_INTERNAL_DEPRECATED;

@end
