//
//  PXPFontLabelStringDrawing.h
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PXPAttributedString.h"

@class PXPFont;

@interface NSString (PXPFontLabelStringDrawing)

// CGFontRef-based methods
- (CGSize)sizeWithCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize __AVAILABILITY_INTERNAL_DEPRECATED;
- (CGSize)sizeWithCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize constrainedToSize:(CGSize)size __AVAILABILITY_INTERNAL_DEPRECATED;
- (CGSize)sizeWithCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize constrainedToSize:(CGSize)size
		   lineBreakMode:(NSLineBreakMode)lineBreakMode __AVAILABILITY_INTERNAL_DEPRECATED;
- (CGSize)drawAtPoint:(CGPoint)point withCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize __AVAILABILITY_INTERNAL_DEPRECATED;
- (CGSize)drawInRect:(CGRect)rect withCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize __AVAILABILITY_INTERNAL_DEPRECATED;
- (CGSize)drawInRect:(CGRect)rect withCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize
	   lineBreakMode:(NSLineBreakMode)lineBreakMode __AVAILABILITY_INTERNAL_DEPRECATED;
- (CGSize)drawInRect:(CGRect)rect withCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize
	   lineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment __AVAILABILITY_INTERNAL_DEPRECATED;

// PXPFont-based methods
- (CGSize)sizeWithPXPFont:(PXPFont *)font;
- (CGSize)sizeWithPXPFont:(PXPFont *)font constrainedToSize:(CGSize)size;
- (CGSize)sizeWithPXPFont:(PXPFont *)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)sizeWithPXPFont:(PXPFont *)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode
		  numberOfLines:(NSUInteger)numberOfLines;
- (CGSize)drawAtPoint:(CGPoint)point withPXPFont:(PXPFont *)font;
- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width withPXPFont:(PXPFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)drawInRect:(CGRect)rect withPXPFont:(PXPFont *)font;
- (CGSize)drawInRect:(CGRect)rect withPXPFont:(PXPFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)drawInRect:(CGRect)rect withPXPFont:(PXPFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode
		   alignment:(NSTextAlignment)alignment;
- (CGSize)drawInRect:(CGRect)rect withPXPFont:(PXPFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode
		   alignment:(NSTextAlignment)alignment numberOfLines:(NSUInteger)numberOfLines;

@end

@interface PXPAttributedString (PXPAttributedStringDrawing)
- (CGSize)size;
- (CGSize)sizeConstrainedToSize:(CGSize)size;
- (CGSize)sizeConstrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)sizeConstrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode
				  numberOfLines:(NSUInteger)numberOfLines;
- (CGSize)drawAtPoint:(CGPoint)point;
- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)drawInRect:(CGRect)rect;
- (CGSize)drawInRect:(CGRect)rect withLineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)drawInRect:(CGRect)rect withLineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment;
- (CGSize)drawInRect:(CGRect)rect withLineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment
	   numberOfLines:(NSUInteger)numberOfLines;
@end
