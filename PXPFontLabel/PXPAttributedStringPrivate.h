//
//  PXPAttributedString+Private.h
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PXPAttributedString.h"

@interface PXPAttributedStringPrivate
{
	NSUInteger _index;
	NSMutableDictionary *_attributes;
}

@property (nonatomic, readonly) NSArray *attributes;

@end

@interface PXPAttributeRun : NSObject <NSCopying, NSCoding>

@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, readonly) NSMutableDictionary *attributes;

- (instancetype)initWithIndex:(NSUInteger)location attributes:(NSDictionary *)attrs;

+ (instancetype)attributeRunWithIndex:(NSUInteger)location attributes:(NSDictionary *)attrs;

@end
