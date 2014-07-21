//
//  PXPFontLabel.m
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import "PXPFontLabel.h"
#import "PXPFontManager.h"
#import "PXPFontLabelStringDrawing.h"
#import "PXPFont.h"

@interface PXPFont (PXPFontPrivate)

@property (nonatomic, readonly) CGFloat ratio;

@end

@interface PXPFontLabel ()

//@property (nonatomic, strong, readwrite) PXPFont *pxpFont;
//@property (nonatomic, strong, readwrite) PXPAttributedString *pxpAttributedText;

@end

@implementation PXPFontLabel

#pragma mark - Lifecycle methods

- (instancetype)initWithFrame:(CGRect)frame fontName:(NSString *)fontName pointSize:(CGFloat)pointSize {
	return [self initWithFrame:frame pxpFont:[[PXPFontManager sharedManager] pxpFontWithName:fontName pointSize:pointSize]];
}

- (id)initWithFrame:(CGRect)frame pxpFont:(PXPFont *)font {
	if ((self = [super initWithFrame:frame])) {
		_pxpFont = font;
	}
	return self;
}

- (id)initWithFrame:(CGRect)frame font:(CGFontRef)font pointSize:(CGFloat)pointSize {
	return [self initWithFrame:frame pxpFont:[PXPFont fontWithCGFont:font size:pointSize]];
}

#pragma mark - Public methods

- (CGFontRef)cgFont {
	return self.pxpFont.cgFont;
}

- (void)setCGFont:(CGFontRef)font {
	if (self.pxpFont.cgFont != font) {
		self.pxpFont = [PXPFont fontWithCGFont:font size:self.pxpFont.pointSize];
	}
}

- (CGFloat)pointSize {
	return self.pxpFont.pointSize;
}

- (void)setPointSize:(CGFloat)pointSize {
	if (self.pxpFont.pointSize != pointSize) {
		self.pxpFont = [PXPFont fontWithCGFont:self.pxpFont.cgFont size:pointSize];
	}
}

- (void)setZAttributedText:(PXPAttributedString *)attStr {
	if (_pxpAttributedText != attStr) {
		_pxpAttributedText = [attStr copy];
		[self setNeedsDisplay];
	}
}

- (void)drawTextInRect:(CGRect)rect {
	if (self.pxpFont == NULL && self.pxpAttributedText == nil) {
		[super drawTextInRect:rect];
		return;
	}

	if (self.pxpAttributedText == nil) {
		// this method is documented as setting the text color for us, but that doesn't appear to be the case
		if (self.highlighted) {
			[(self.highlightedTextColor ?: [UIColor whiteColor]) setFill];
		} else {
			[(self.textColor ?: [UIColor blackColor]) setFill];
		}

		PXPFont *actualFont = self.pxpFont;
		CGSize origSize = rect.size;
		if (self.numberOfLines == 1) {
			origSize.height = actualFont.leading;
			CGPoint point = CGPointMake(rect.origin.x,
										rect.origin.y + roundf(((rect.size.height - actualFont.leading) / 2.0f)));
			CGSize size = [self.text sizeWithPXPFont:actualFont];
			if (self.adjustsFontSizeToFitWidth && self.minimumFontSize < actualFont.pointSize) {
				if (size.width > origSize.width) {
					CGFloat desiredRatio = (origSize.width * actualFont.ratio) / size.width;
					CGFloat desiredPointSize = desiredRatio * actualFont.pointSize / actualFont.ratio;
					actualFont = [actualFont fontWithSize:MAX(MAX(desiredPointSize, self.minimumFontSize), 1.0f)];
					size = [self.text sizeWithPXPFont:actualFont];
				}
				if (!CGSizeEqualToSize(origSize, size)) {
					switch (self.baselineAdjustment) {
						case UIBaselineAdjustmentAlignCenters:
							point.y += roundf((origSize.height - size.height) / 2.0f);
							break;
						case UIBaselineAdjustmentAlignBaselines:
							point.y += (self.pxpFont.ascender - actualFont.ascender);
							break;
						case UIBaselineAdjustmentNone:
							break;
					}
				}
			}
			size.width = MIN(size.width, origSize.width);
			// adjust the point for alignment
			switch (self.textAlignment) {
				case NSTextAlignmentLeft:
					break;
				case NSTextAlignmentCenter:
					point.x += (origSize.width - size.width) / 2.0f;
					break;
				case NSTextAlignmentRight:
					point.x += origSize.width - size.width;
					break;
#if __IPHONE_OS_VERSION_MAX_ALLOWED   >  __IPHONE_5_1
                case NSTextAlignmentJustified:
                    NSLog(@"not supported alignment");
                    break;
                case NSTextAlignmentNatural:
                    NSLog(@"not supported alignment");
                    break;
#endif
			}
			[self.text drawAtPoint:point forWidth:size.width withPXPFont:actualFont lineBreakMode:self.lineBreakMode];
		} else {
			CGSize size = [self.text sizeWithPXPFont:actualFont constrainedToSize:origSize lineBreakMode:self.lineBreakMode numberOfLines:self.numberOfLines];
			CGPoint point = rect.origin;
			point.y += roundf((rect.size.height - size.height) / 2.0f);
			rect = (CGRect){point, CGSizeMake(rect.size.width, size.height)};
			[self.text drawInRect:rect withPXPFont:actualFont lineBreakMode:self.lineBreakMode alignment:self.textAlignment numberOfLines:self.numberOfLines];
		}
	} else {
		PXPAttributedString *attStr = self.pxpAttributedText;
		if (self.highlighted) {
			// Mmodify the string to change the base color.
			PXPMutableAttributedString *mutStr = [attStr mutableCopy];
			NSRange activeRange = NSMakeRange(0, attStr.length);
			while (activeRange.length > 0) {
				NSRange effective;
				UIColor *color = [attStr attribute:PXPForegroundColorAttributeName atIndex:activeRange.location
							 longestEffectiveRange:&effective inRange:activeRange];
				if (color == nil) {
					[mutStr addAttribute:PXPForegroundColorAttributeName value:[UIColor whiteColor] range:effective];
				}
				activeRange.location += effective.length, activeRange.length -= effective.length;
			}
			attStr = mutStr;
		}
		CGSize size = [attStr sizeConstrainedToSize:rect.size lineBreakMode:self.lineBreakMode numberOfLines:self.numberOfLines];
		CGPoint point = rect.origin;
		point.y += roundf((rect.size.height - size.height) / 2.0f);
		rect = (CGRect){point, CGSizeMake(rect.size.width, size.height)};
		[attStr drawInRect:rect withLineBreakMode:self.lineBreakMode alignment:self.textAlignment numberOfLines:self.numberOfLines];
	}
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines {
	if (self.pxpFont == NULL && self.pxpAttributedText == nil) {
		return [super textRectForBounds:bounds limitedToNumberOfLines:numberOfLines];
	}

	if (numberOfLines == 1) {
		// if numberOfLines == 1 we need to use the version that converts spaces
		CGSize size;
		if (self.pxpAttributedText == nil) {
			size = [self.text sizeWithPXPFont:self.pxpFont];
		} else {
			size = [self.pxpAttributedText size];
		}
		bounds.size.width = MIN(bounds.size.width, size.width);
		bounds.size.height = MIN(bounds.size.height, size.height);
	} else {
		if (numberOfLines > 0) bounds.size.height = MIN(bounds.size.height, self.pxpFont.leading * numberOfLines);
		if (self.pxpAttributedText == nil) {
			bounds.size = [self.text sizeWithPXPFont:self.pxpFont constrainedToSize:bounds.size lineBreakMode:self.lineBreakMode];
		} else {
			bounds.size = [self.pxpAttributedText sizeConstrainedToSize:bounds.size lineBreakMode:self.lineBreakMode];
		}
	}
	return bounds;
}

@end
