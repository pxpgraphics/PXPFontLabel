//
//  PXPAttributedString.m
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import "PXPAttributedString.h"
#import "PXPAttributedStringPrivate.h"

NSUInteger const PXPAttributedStringUnderlineStyleMask = 0x00FF;
NSUInteger const PXPAttributedStringUnderlinePatternMask = 0xFF00;

NSString * const PXPFontAttributeName = @"PXPFontAttributeName";
NSString * const PXPForegroundColorAttributeName = @"PXPForegroundColorAttributeName";
NSString * const PXPBackgroundColorAttributeName = @"PXPBackgroundColorAttributeName";
NSString * const PXPUnderlineStyleAttributeName = @"PXPUnderlineStyleAttributeName";

@interface PXPAttributedString ()

- (NSUInteger)indexOfEffectiveAttributeRunForIndex:(NSUInteger)location;
- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)aRange uniquingOnName:(NSString *)attributeName;
- (NSDictionary *)attributesAtIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)aRange inRange:(NSRange)rangeLimit uniquingOnName:(NSString *)attributeName;

@end

@implementation PXPAttributedString

#pragma mark - Lifecycle methods

- (instancetype)init
{
	return [self initWithString:@"" attributes:nil];
}

- (instancetype)initWithAttributedString:(PXPAttributedString *)attrStr
{
	NSParameterAssert(attrStr != nil);
	self = [super init];
	if (self) {
		_buffer = [attrStr->_buffer mutableCopy];
		_attributes = [[NSMutableArray alloc] initWithArray:attrStr->_attributes copyItems:YES];
	}
	return self;
}

- (instancetype)initWithString:(NSString *)str
{
	return [self initWithString:str attributes:nil];
}

- (instancetype)initWithString:(NSString *)str attributes:(NSDictionary *)attrs
{
	self = [super init];
	if (self) {
		_buffer = [str mutableCopy];
		_attributes = [[NSMutableArray alloc] initWithObjects:[PXPAttributeRun attributeRunWithIndex:0 attributes:attrs], nil];
	}
	return self;
}

#pragma mark - NSCoding delegate

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
	if (self) {
		_buffer = [[aDecoder decodeObjectForKey:@"buffer"] mutableCopy];
		_attributes = [[aDecoder decodeObjectForKey:@"attributes"] mutableCopy];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:_buffer forKey:@"buffer"];
	[aCoder encodeObject:_attributes forKey:@"attributes"];
}

#pragma mark - NSCopying delegate

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [(PXPMutableAttributedString *)[PXPMutableAttributedString allocWithZone:zone] initWithAttributedString:self];
}

#pragma mark - Private methods

- (NSUInteger)length
{
	return [_buffer length];
}

- (NSString *)description
{
	NSMutableArray *components = [NSMutableArray arrayWithCapacity:[_attributes count] * 2];
	NSRange range = NSMakeRange(0, 0);
	for (NSUInteger i = 0; i <= [_attributes count]; i++) {
		range.location = NSMaxRange(range);
		PXPAttributeRun *run;
		if (i < [_attributes count]) {
			run = _attributes[i];
			range.length = run.index - range.location;
		} else {
			run = nil;
			range.length = [_buffer length] - range.location;
		}

		if (range.length > 0) {
			[components addObject:[NSString stringWithFormat:@"\"%@\"", [_buffer substringWithRange:range]]];
		}

		if (run != nil) {
			NSMutableArray *attrDesc = [NSMutableArray arrayWithCapacity:[run.attributes count]];
			for (id key in run.attributes) {
				[attrDesc addObject:[NSString stringWithFormat:@"%@: %@", key, [run.attributes objectForKey:key]]];
			}
			[components addObject:[NSString stringWithFormat:@"{%@}", [attrDesc componentsJoinedByString:@", "]]];
		}
	}
	return [NSString stringWithFormat:@"%@", [components componentsJoinedByString:@" "]];
}

#pragma mark - Public methods

- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)index effectiveRange:(NSRangePointer)aRange {
	NSParameterAssert(attributeName != nil);
	return [[self attributesAtIndex:index effectiveRange:aRange uniquingOnName:attributeName] objectForKey:attributeName];
}

- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)aRange inRange:(NSRange)rangeLimit {
	NSParameterAssert(attributeName != nil);
	return [[self attributesAtIndex:index longestEffectiveRange:aRange inRange:rangeLimit uniquingOnName:attributeName] objectForKey:attributeName];
}

- (instancetype)attributedSubstringFromRange:(NSRange)aRange {
	if (NSMaxRange(aRange) > [_buffer length]) {
		@throw [NSException exceptionWithName:NSRangeException reason:@"range was outisde of the attributed string" userInfo:nil];
	}
	PXPMutableAttributedString *newStr = [self mutableCopy];
	if (aRange.location > 0) {
		[newStr deleteCharactersInRange:NSMakeRange(0, aRange.location)];
	}
	if (NSMaxRange(aRange) < [_buffer length]) {
		[newStr deleteCharactersInRange:NSMakeRange(aRange.length, [_buffer length] - NSMaxRange(aRange))];
	}
	return newStr;
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)aRange {
	return [NSDictionary dictionaryWithDictionary:[self attributesAtIndex:index effectiveRange:aRange uniquingOnName:nil]];
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)aRange inRange:(NSRange)rangeLimit {
	return [NSDictionary dictionaryWithDictionary:[self attributesAtIndex:index longestEffectiveRange:aRange inRange:rangeLimit uniquingOnName:nil]];
}

- (BOOL)isEqualToAttributedString:(PXPAttributedString *)otherString
{
	return ([_buffer isEqualToString:otherString->_buffer] && [_attributes isEqualToArray:otherString->_attributes]);
}

- (BOOL)isEqual:(id)object
{
	return [object isKindOfClass:[self class]] && [self isEqualToAttributedString:(PXPAttributedString *)object];
}


#warning This code has not been tested. The only guarantee is that it compiles.
- (void)enumerateAttribute:(NSString *)attrName inRange:(NSRange)enumerationRange options:(PXPAttributedStringEnumerationOptions)opts
				usingBlock:(void (^)(id, NSRange, BOOL*))block
{
	if (opts & PXPAttributedStringEnumerationLongestEffectiveRangeNotRequired) {
		[self enumerateAttributesInRange:enumerationRange options:opts usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
			id value = [attrs objectForKey:attrName];
			if (value != nil) {
				block(value, range, stop);
			}
		}];
	} else {
		__block id oldValue = nil;
		__block NSRange effectiveRange = NSMakeRange(0, 0);
		[self enumerateAttributesInRange:enumerationRange options:opts usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
			id value = [attrs objectForKey:attrName];
			if (oldValue == nil) {
				oldValue = value;
				effectiveRange = range;
			} else if (value != nil && [oldValue isEqual:value]) {
				// Combine the attributes.
				effectiveRange = NSUnionRange(effectiveRange, range);
			} else {
				BOOL innerStop = NO;
				block(oldValue, effectiveRange, &innerStop);
				if (innerStop) {
					*stop = YES;
					oldValue = nil;
				} else {
					oldValue = value;
				}
			}
		}];
		if (oldValue != nil) {
			BOOL innerStop = NO; // Necessary for the block, but unused.
			block(oldValue, effectiveRange, &innerStop);
		}
	}
}

- (void)enumerateAttributesInRange:(NSRange)enumerationRange options:(PXPAttributedStringEnumerationOptions)opts
						usingBlock:(void (^)(NSDictionary*, NSRange, BOOL*))block
{
	/*
	 * Copy the attributes so we can mutate the string if necessary during enumeration.
	 * Also clip the array during copy to only the subarray of attributes that cover the requested range.
	 */
	NSArray *attrs;
	if (NSEqualRanges(enumerationRange, NSMakeRange(0, 0))) {
		attrs = [NSArray arrayWithArray:_attributes];
	} else {
		// In this binary search, last is the first run after the range.
		NSUInteger first = 0, last = [_attributes count];
		while (last > first+1) {
			NSUInteger pivot = (last + first) / 2;
			PXPAttributeRun *run = [_attributes objectAtIndex:pivot];
			if (run.index < enumerationRange.location) {
				first = pivot;
			} else if (run.index >= NSMaxRange(enumerationRange)) {
				last = pivot;
			}
		}
		attrs = [_attributes subarrayWithRange:NSMakeRange(first, last-first)];
	}
	if (opts & PXPAttributedStringEnumerationReverse) {
		NSUInteger end = [_buffer length];
		for (PXPAttributeRun *run in [attrs reverseObjectEnumerator]) {
			BOOL stop = NO;
			NSUInteger start = run.index;
			// Clip to enumerationRange.
			start = MAX(start, enumerationRange.location);
			end = MIN(end, NSMaxRange(enumerationRange));
			block(run.attributes, NSMakeRange(start, end - start), &stop);
			if (stop) break;
			end = run.index;
		}
	} else {
		NSUInteger start = 0;
		PXPAttributeRun *run = [attrs objectAtIndex:0];
		NSInteger offset = 0;
		NSInteger oldLength = [_buffer length];
		for (NSUInteger i = 1;;i++) {
			NSUInteger end;
			if (i >= [attrs count]) {
				end = oldLength;
			} else {
				end = [[attrs objectAtIndex:i] index];
			}
			BOOL stop = NO;
			NSUInteger clippedStart = MAX(start, enumerationRange.location);
			NSUInteger clippedEnd = MIN(end, NSMaxRange(enumerationRange));
			block(run.attributes, NSMakeRange(clippedStart + offset, clippedEnd - start), &stop);
			if (stop || i >= [attrs count]) break;
			start = end;
			NSUInteger newLength = [_buffer length];
			offset += (newLength - oldLength);
			oldLength = newLength;
		}
	}
}

- (NSUInteger)indexOfEffectiveAttributeRunForIndex:(NSUInteger)location
{
	NSUInteger first = 0, last = [_attributes count];
	while (last > first + 1) {
		NSUInteger pivot = (last + first) / 2;
		PXPAttributeRun *run = [_attributes objectAtIndex:pivot];
		NSUInteger currentIndex = (NSUInteger)&index;
		if (run.index > currentIndex) {
			last = pivot;
		} else if (run.index < currentIndex) {
			first = pivot;
		} else {
			first = pivot;
			break;
		}
	}
	return first;
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)aRange uniquingOnName:(NSString *)attributeName {
	if (index >= [_buffer length]) {
		@throw [NSException exceptionWithName:NSRangeException reason:@"index beyond range of attributed string" userInfo:nil];
	}
	NSUInteger runIndex = [self indexOfEffectiveAttributeRunForIndex:index];
	PXPAttributeRun *run = [_attributes objectAtIndex:runIndex];
	if (aRange != NULL) {
		aRange->location = run.index;
		runIndex++;
		if (runIndex < [_attributes count]) {
			aRange->length = [[_attributes objectAtIndex:runIndex] index] - aRange->location;
		} else {
			aRange->length = [_buffer length] - aRange->location;
		}
	}
	return run.attributes;
}
- (NSDictionary *)attributesAtIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)aRange
							inRange:(NSRange)rangeLimit uniquingOnName:(NSString *)attributeName {
	if (index >= [_buffer length]) {
		@throw [NSException exceptionWithName:NSRangeException reason:@"index beyond range of attributed string" userInfo:nil];
	} else if (NSMaxRange(rangeLimit) > [_buffer length]) {
		@throw [NSException exceptionWithName:NSRangeException reason:@"rangeLimit beyond range of attributed string" userInfo:nil];
	}
	NSUInteger runIndex = [self indexOfEffectiveAttributeRunForIndex:index];
	PXPAttributeRun *run = [_attributes objectAtIndex:runIndex];
	if (aRange != NULL) {
		if (attributeName != nil) {
			id value = [run.attributes objectForKey:attributeName];
			NSUInteger endRunIndex = runIndex+1;
			runIndex--;
			// Search backwards.
			while (1) {
				if (run.index <= rangeLimit.location) {
					break;
				}
				PXPAttributeRun *prevRun = [_attributes objectAtIndex:runIndex];
				id prevValue = [prevRun.attributes objectForKey:attributeName];
				if (prevValue == value || (value != nil && [prevValue isEqual:value])) {
					runIndex--;
					run = prevRun;
				} else {
					break;
				}
			}
			// Search forwards.
			PXPAttributeRun *endRun = nil;
			while (endRunIndex < [_attributes count]) {
				PXPAttributeRun *nextRun = [_attributes objectAtIndex:endRunIndex];
				if (nextRun.index >= NSMaxRange(rangeLimit)) {
					endRun = nextRun;
					break;
				}
				id nextValue = [nextRun.attributes objectForKey:attributeName];
				if (nextValue == value || (value != nil && [nextValue isEqual:value])) {
					endRunIndex++;
				} else {
					endRun = nextRun;
					break;
				}
			}
			aRange->location = MAX(run.index, rangeLimit.location);
			aRange->length = MIN((endRun ? endRun.index : [_buffer length]), NSMaxRange(rangeLimit)) - aRange->location;
		} else {
			/*
			 * With no attribute name, we don't need to do any real searching,
			 * as we already guarantee each run has unique attributes.
			 * Just make sure to clip the range to the rangeLimit.
			 */
			aRange->location = MAX(run.index, rangeLimit.location);
			PXPAttributeRun *endRun = (runIndex+1 < [_attributes count] ? [_attributes objectAtIndex:runIndex+1] : nil);
			aRange->length = MIN((endRun ? endRun.index : [_buffer length]), NSMaxRange(rangeLimit)) - aRange->location;
		}
	}
	return run.attributes;
}

@end

@interface PXPMutableAttributedString ()

@property (nonatomic, readonly) NSArray *attributes;

- (void)cleanupAttributesInRange:(NSRange)range;
- (NSRange)rangeOfAttributeRunsForRange:(NSRange)range;
- (void)offsetRunsInRange:(NSRange)range byOffset:(NSInteger)offset;

@end

@implementation PXPMutableAttributedString

#pragma mark - NSCopying delegate

- (id)copyWithZone:(NSZone *)zone
{
	return [(PXPAttributedString *)[PXPAttributedString allocWithZone:zone] initWithAttributedString:self];
}

#pragma mark - Private methods

/*
 * Splits the existing runs to provide one or more new runs for the given range.
 */
- (NSRange)rangeOfAttributeRunsForRange:(NSRange)range {
	NSParameterAssert(NSMaxRange(range) <= [_buffer length]);

	// Find (or create) the first run.
	NSUInteger first = 0;
	PXPAttributeRun *lastRun = nil;
	for (;;first++) {
		if (first >= [_attributes count]) {
			// we didn't find a run
			first = [_attributes count];
			PXPAttributeRun *newRun = [[PXPAttributeRun alloc] initWithIndex:range.location attributes:lastRun.attributes];
			[_attributes addObject:newRun];
			break;
		}
		PXPAttributeRun *run = [_attributes objectAtIndex:first];
		if (run.index == range.location) {
			break;
		} else if (run.index > range.location) {
			PXPAttributeRun *newRun = [[PXPAttributeRun alloc] initWithIndex:range.location attributes:lastRun.attributes];
			[_attributes insertObject:newRun atIndex:first];
			break;
		}
		lastRun = run;
	}

	if (((PXPAttributeRun *)[_attributes lastObject]).index < NSMaxRange(range)) {
		NSRange subrange = NSMakeRange(first, [_attributes count] - first);
		if (NSMaxRange(range) < [_buffer length]) {
			PXPAttributeRun *newRun = [[PXPAttributeRun alloc] initWithIndex:NSMaxRange(range)
																  attributes:(NSDictionary*)[(PXPAttributeRun *)[_attributes lastObject] attributes]];
			[_attributes addObject:newRun];
		}
		return subrange;
	} else {
		// Find the last run within and the first run after the range.
		NSUInteger lastIn = first, firstAfter = [_attributes count]-1;
		while (firstAfter > lastIn + 1) {
			NSUInteger idx = (firstAfter + lastIn) / 2;
			PXPAttributeRun *run = [_attributes objectAtIndex:idx];
			if (run.index < range.location) {
				lastIn = idx;
			} else if (run.index > range.location) {
				firstAfter = idx;
			} else {
				// This is definitively the first run after the range.
				firstAfter = idx;
				break;
			}
		}
		if ([[_attributes objectAtIndex:firstAfter] index] > NSMaxRange(range)) {
			// The first after is too far after, insert another run!
			PXPAttributeRun *newRun = [[PXPAttributeRun alloc] initWithIndex:NSMaxRange(range)
																  attributes:[(PXPAttributeRun *)[_attributes objectAtIndex:firstAfter-1] attributes]];
			[_attributes insertObject:newRun atIndex:firstAfter];
		}
		return NSMakeRange(lastIn, firstAfter - lastIn);
	}
}

- (void)cleanupAttributesInRange:(NSRange)range {
	// Expand the range to include one surrounding attribute on each side.
	if (range.location > 0) {
		range.location -= 1;
		range.length += 1;
	}
	if (NSMaxRange(range) < [_attributes count]) {
		range.length += 1;
	} else {
		// Make sure the range is capped to the attributes count.
		range.length = [_attributes count] - range.location;
	}
	if (range.length == 0) return;
	PXPAttributeRun *lastRun = [_attributes objectAtIndex:range.location];
	for (NSUInteger i = range.location+1; i < NSMaxRange(range);) {
		PXPAttributeRun *run = [_attributes objectAtIndex:i];
		if ([lastRun.attributes isEqualToDictionary:run.attributes]) {
			[_attributes removeObjectAtIndex:i];
			range.length -= 1;
		} else {
			lastRun = run;
			i++;
		}
	}
}

- (void)offsetRunsInRange:(NSRange)range byOffset:(NSInteger)offset {
	for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
		PXPAttributeRun *run = [_attributes objectAtIndex:i];
		PXPAttributeRun *newRun = [[PXPAttributeRun alloc] initWithIndex:run.index + offset attributes:run.attributes];
		[_attributes replaceObjectAtIndex:i withObject:newRun];
	}
}

#pragma mark - Public methods

- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range {
	range = [self rangeOfAttributeRunsForRange:range];
	for (PXPAttributeRun *run in [_attributes subarrayWithRange:range]) {
		[run.attributes setObject:value forKey:name];
	}
	[self cleanupAttributesInRange:range];
}

- (void)addAttributes:(NSDictionary *)attributes range:(NSRange)range {
	range = [self rangeOfAttributeRunsForRange:range];
	for (PXPAttributeRun *run in [_attributes subarrayWithRange:range]) {
		[run.attributes addEntriesFromDictionary:attributes];
	}
	[self cleanupAttributesInRange:range];
}

- (void)appendAttributedString:(PXPAttributedString *)str {
	[self insertAttributedString:str atIndex:[_buffer length]];
}

- (void)deleteCharactersInRange:(NSRange)range {
	NSRange runRange = [self rangeOfAttributeRunsForRange:range];
	[_buffer replaceCharactersInRange:range withString:@""];
	[_attributes removeObjectsInRange:runRange];
	for (NSUInteger i = runRange.location; i < [_attributes count]; i++) {
		PXPAttributeRun *run = [_attributes objectAtIndex:i];
		PXPAttributeRun *newRun = [[PXPAttributeRun alloc] initWithIndex:(run.index - range.length) attributes:run.attributes];
		[_attributes replaceObjectAtIndex:i withObject:newRun];
	}
	[self cleanupAttributesInRange:NSMakeRange(runRange.location, 0)];
}

- (void)insertAttributedString:(PXPAttributedString *)str atIndex:(NSUInteger)idx {
	[self replaceCharactersInRange:NSMakeRange(idx, 0) withAttributedString:str];
}

- (void)removeAttribute:(NSString *)name range:(NSRange)range {
	range = [self rangeOfAttributeRunsForRange:range];
	for (PXPAttributeRun *run in [_attributes subarrayWithRange:range]) {
		[run.attributes removeObjectForKey:name];
	}
	[self cleanupAttributesInRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(PXPAttributedString *)str {
	NSRange replaceRange = [self rangeOfAttributeRunsForRange:range];
	NSInteger offset = [str->_buffer length] - range.length;
	[_buffer replaceCharactersInRange:range withString:str->_buffer];
	[_attributes replaceObjectsInRange:replaceRange withObjectsFromArray:str->_attributes];
	NSRange newRange = NSMakeRange(replaceRange.location, [str->_attributes count]);
	[self offsetRunsInRange:newRange byOffset:range.location];
	[self offsetRunsInRange:NSMakeRange(NSMaxRange(newRange), [_attributes count] - NSMaxRange(newRange)) byOffset:offset];
	[self cleanupAttributesInRange:NSMakeRange(newRange.location, 0)];
	[self cleanupAttributesInRange:NSMakeRange(NSMaxRange(newRange), 0)];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
	[self replaceCharactersInRange:range withAttributedString:[[PXPAttributedString alloc] initWithString:str]];
}

- (void)setAttributedString:(PXPAttributedString *)str {
	_buffer = [str->_buffer mutableCopy];
	_attributes = [str->_attributes mutableCopy];
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)range {
	range = [self rangeOfAttributeRunsForRange:range];
	for (PXPAttributeRun *run in [_attributes subarrayWithRange:range]) {
		[run.attributes setDictionary:attributes];
	}
	[self cleanupAttributesInRange:range];
}

@end

@interface PXPAttributeRun ()

@property (nonatomic, readwrite) NSUInteger index;
@property (nonatomic, readwrite) NSMutableDictionary *attributes;

@end

@implementation PXPAttributeRun

#pragma mark - Lifecycle methods

- (instancetype)init
{
	return [self initWithIndex:0 attributes:@{ }];
}

- (instancetype)initWithIndex:(NSUInteger)location attributes:(NSDictionary *)attrs
{
	NSParameterAssert(location >= 0);
	self = [super init];
	if (self) {
		_index = location;
		if (attrs) {
			_attributes = [NSMutableDictionary dictionary];
		} else {
			_attributes = [attrs mutableCopy];
		}
	}
	return self;
}

+ (instancetype)attributeRunWithIndex:(NSUInteger)location attributes:(NSDictionary *)attrs
{
	return [[self alloc] initWithIndex:location attributes:attrs];
}

#pragma mark - NSCoding delegate

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
	if (self) {
		_index = [[aDecoder decodeObjectForKey:@"index"] unsignedIntegerValue];
		_attributes = [[aDecoder decodeObjectForKey:@"attributes"] mutableCopy];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:[NSNumber numberWithUnsignedInteger:_index] forKey:@"index"];
	[aCoder encodeObject:_attributes forKey:@"attributes"];
}

#pragma mark - NSCopying delegate

- (id)copyWithZone:(NSZone *)zone
{
	return [[PXPAttributeRun allocWithZone:zone] initWithIndex:_index attributes:_attributes];
}

#pragma mark - Public methods

- (NSString *)description
{
	NSMutableArray *components = [NSMutableArray arrayWithCapacity:[_attributes count]];
	for (id key in _attributes) {
		[components addObject:[NSString stringWithFormat:@"%@=%@", key, [_attributes objectForKey:key]]];
	}
	return [NSString stringWithFormat:@"<%@: %p index=%lu attributes={%@}>", NSStringFromClass([self class]), self, (unsigned long)_index, [components componentsJoinedByString:@" "]];
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[PXPAttributeRun class]]) {
		return NO;
	}

	PXPAttributeRun *otherRun = (PXPAttributeRun *)object;
	return _index == otherRun->_index && [_attributes isEqualToDictionary:otherRun->_attributes];
}

@end
