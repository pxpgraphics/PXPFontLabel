//
//  PXPFontLabelStringDrawing.m
//  PXPFontLabelDemo
//
//  Created by Paris Pinkney on 7/21/14.
//  Copyright (c) 2014 PXPGraphics. All rights reserved.
//

#import "PXPFontLabelStringDrawing.h"
#import "PXPFont.h"
#import "PXPAttributedStringPrivate.h"
#import <CoreText/CoreText.h>

@interface PXPFont (PXPFOntPrivate)

@property (nonatomic, readonly) CGFloat ratio;

@end

#define kUnicodeHighSurrogateStart 0xD800
#define kUnicodeHighSurrogateEnd 0xDBFF
#define kUnicodeHighSurrogateMask kUnicodeHighSurrogateStart
#define kUnicodeLowSurrogateStart 0xDC00
#define kUnicodeLowSurrogateEnd 0xDFFF
#define kUnicodeLowSurrogateMask kUnicodeLowSurrogateStart
#define kUnicodeSurrogateTypeMask 0xFC00
#define UnicharIsHighSurrogate(c) ((c & kUnicodeSurrogateTypeMask) == kUnicodeHighSurrogateMask)
#define UnicharIsLowSurrogate(c) ((c & kUnicodeSurrogateTypeMask) == kUnicodeLowSurrogateMask)
#define ConvertSurrogatePairToUTF32(high, low) ((UInt32)((high - 0xD800) * 0x400 + (low - 0xDC00) + 0x10000))

typedef NS_ENUM(NSUInteger, FontTableFormat) {
	kFontTableFormat4 = 4,
	kFontTableFormat12 = 12
};

typedef struct fontTable {
	NSUInteger retainCount;
	CFDataRef cmapTable;
	FontTableFormat format;
	union {
		struct {
			UInt16 segCountX2;
			UInt16 *endCodes;
			UInt16 *startCodes;
			UInt16 *idDeltas;
			UInt16 *idRangeOffsets;
		} format4;

		struct {
			UInt32 nGroups;
			struct {
				UInt32 startCharCode;
				UInt32 endCharCode;
				UInt32 startGlyphCode;
			} *groups;
		} format12;
	} cmap;
} fontTable;

static FontTableFormat supportedFormats[] = { kFontTableFormat4, kFontTableFormat12 };
static size_t supportedFormatsCount = sizeof(supportedFormats) / sizeof(FontTableFormat);

static fontTable *newFontTable(CFDataRef cmapTable, FontTableFormat format) {
	fontTable *table = (struct fontTable *)malloc(sizeof(struct fontTable));
	table->retainCount = 1;
	table->cmapTable = CFRetain(cmapTable);
	table->format = format;
	return table;
}

static fontTable *retainFontTable(fontTable *table) {
	if (table != NULL) {
		table->retainCount++;
	}
	return table;
}

static void releaseFontTable(fontTable *table) {
	if (table != NULL) {
		if (table->retainCount <= 1) {
			CFRelease(table->cmapTable);
			free(table);
		} else {
			table->retainCount--;
		}
	}
}

static const void *fontTableRetainCallback(CFAllocatorRef allocator, const void *value) {
	return retainFontTable((fontTable *)value);
}

static void fontTableReleaseCallback(CFAllocatorRef allocator, const void *value) {
	releaseFontTable((fontTable *)value);
}

static const CFDictionaryValueCallBacks kFontTableDictionaryValueCallBacks = {
	.version = 0,
	.retain = &fontTableRetainCallback,
	.release = &fontTableReleaseCallback,
	.copyDescription = NULL,
	.equal = NULL
};

/*
 * Read the cmap table from the font/
 * We only know how to understand some of the table formats at the moment.
 */
static fontTable *readFontTableFromCGFont(CGFontRef font) {
	CFDataRef cmapTable = CGFontCopyTableForTag(font, 'cmap');
	NSCAssert1(cmapTable != NULL, @"CGFontCopyTableForTag returned NULL for 'cmap' tag in font %@",
			   (font ? (__bridge id)CFCopyDescription(font) : @"(null)"));
	const UInt8 * const bytes = CFDataGetBytePtr(cmapTable);
	NSCAssert1(OSReadBigInt16(bytes, 0) == 0, @"cmap table for font %@ has bad version number",
			   (font ? (__bridge id)CFCopyDescription(font) : @"(null)"));
	UInt16 numberOfSubtables = OSReadBigInt16(bytes, 2);
	const UInt8 *unicodeSubtable = NULL;
	// UInt16 unicodeSubtablePlatformID;
	UInt16 unicodeSubtablePlatformSpecificId = 0;
	FontTableFormat unicodeSubtableFormat;
	const UInt8 * const encodingSubtables = &bytes[4];
	for (UInt16 i = 0; i < numberOfSubtables; i++) {
		const UInt8 * const encodingSubtable = &encodingSubtables[8 * i];
		UInt16 platformID = OSReadBigInt16(encodingSubtable, 0);
		UInt16 platformSpecificID = OSReadBigInt16(encodingSubtable, 2);
		/*
		 * Find the best subtable.
		 * Best is defined by a combination of encoding and format.
		 * At the moment we only support format 4, so ignore all other format tables.
		 * We prefer platformID == 0, but we will also accept Microsoft's unicode format.
		 */
		if (platformID == 0 || (platformID == 3 && platformSpecificID == 1)) {
			BOOL preferred = NO;
			if (unicodeSubtable == NULL) {
				preferred = YES;
			} else if (platformID == 0 && platformSpecificID > unicodeSubtablePlatformSpecificId) {
				preferred = YES;
			}
			if (preferred) {
				UInt32 offset = OSReadBigInt32(encodingSubtable, 4);
				const UInt8 *subtable = &bytes[offset];
				UInt16 format = OSReadBigInt16(subtable, 0);
				for (size_t i = 0; i < supportedFormatsCount; i++) {
					if (format == supportedFormats[i]) {
						if (format >= 8) {
							// the version is a fixed-point
							UInt16 formatFrac = OSReadBigInt16(subtable, 2);
							if (formatFrac != 0) {
								// all the current formats with a Fixed version are always *.0
								continue;
							}
						}
						unicodeSubtable = subtable;
						// unicodeSubtablePlatformID = platformID;
						unicodeSubtablePlatformSpecificId = platformSpecificID;
						unicodeSubtableFormat = format;
						break;
					}
				}
			}
		}
	}
	fontTable *table = NULL;
	if (unicodeSubtable != NULL) {
		table = newFontTable(cmapTable, unicodeSubtableFormat);
		switch (unicodeSubtableFormat) {
			case kFontTableFormat4:
				// subtable format 4
				// UInt16 length = OSReadBigInt16(unicodeSubtable, 2);
				// UInt16 language = OSReadBigInt16(unicodeSubtable, 4);
				table->cmap.format4.segCountX2 = OSReadBigInt16(unicodeSubtable, 6);
				// UInt16 searchRange = OSReadBigInt16(unicodeSubtable, 8);
				// UInt16 entrySelector = OSReadBigInt16(unicodeSubtable, 10);
				// UInt16 rangeShift = OSReadBigInt16(unicodeSubtable, 12);
				table->cmap.format4.endCodes = (UInt16*)&unicodeSubtable[14];
				table->cmap.format4.startCodes = (UInt16*)&((UInt8*)table->cmap.format4.endCodes)[table->cmap.format4.segCountX2+2];
				table->cmap.format4.idDeltas = (UInt16*)&((UInt8*)table->cmap.format4.startCodes)[table->cmap.format4.segCountX2];
				table->cmap.format4.idRangeOffsets = (UInt16*)&((UInt8*)table->cmap.format4.idDeltas)[table->cmap.format4.segCountX2];
				// UInt16 *glyphIndexArray = &idRangeOffsets[segCountX2];
				break;
			case kFontTableFormat12:
				table->cmap.format12.nGroups = OSReadBigInt32(unicodeSubtable, 12);
				table->cmap.format12.groups = (void *)&unicodeSubtable[16];
				break;
			default:
				releaseFontTable(table);
				table = NULL;
		}
	}
	CFRelease(cmapTable);
	return table;
}

/*
 * outGlyphs must be at least size n.
 */
static void mapCharactersToGlyphsInFont(const fontTable *table, unichar characters[], size_t charLen, CGGlyph outGlyphs[], size_t *outGlyphLen) {
	if (table != NULL) {
		NSUInteger j = 0;
		switch (table->format) {
			case kFontTableFormat4: {
				for (NSUInteger i = 0; i < charLen; i++, j++) {
					unichar c = characters[i];
					UInt16 segOffset;
					BOOL foundSegment = NO;
					for (segOffset = 0; segOffset < table->cmap.format4.segCountX2; segOffset += 2) {
						UInt16 endCode = OSReadBigInt16(table->cmap.format4.endCodes, segOffset);
						if (endCode >= c) {
							foundSegment = YES;
							break;
						}
					}
					if (!foundSegment) {
						/*
						 * No segment.
						 * This is an invalid font.
						 */
						outGlyphs[j] = 0;
					} else {
						UInt16 startCode = OSReadBigInt16(table->cmap.format4.startCodes, segOffset);
						if (!(startCode <= c)) {
							// The code falls in a hole between segments.
							outGlyphs[j] = 0;
						} else {
							UInt16 idRangeOffset = OSReadBigInt16(table->cmap.format4.idRangeOffsets, segOffset);
							if (idRangeOffset == 0) {
								UInt16 idDelta = OSReadBigInt16(table->cmap.format4.idDeltas, segOffset);
								outGlyphs[j] = (c + idDelta) % 65536;
							} else {
								// Use the glyphIndexArray.
								UInt16 glyphOffset = idRangeOffset + 2 * (c - startCode);
								outGlyphs[j] = OSReadBigInt16(&((UInt8*)table->cmap.format4.idRangeOffsets)[segOffset], glyphOffset);
							}
						}
					}
				}
				break;
			}
			case kFontTableFormat12: {
				UInt32 lastSegment = UINT32_MAX;
				for (NSUInteger i = 0; i < charLen; i++, j++) {
					unichar c = characters[i];
					UInt32 c32 = c;
					if (UnicharIsHighSurrogate(c)) {
						if (i+1 < charLen) { // Do we have another character after this one?
							unichar cc = characters[i+1];
							if (UnicharIsLowSurrogate(cc)) {
								c32 = ConvertSurrogatePairToUTF32(c, cc);
								i++;
							}
						}
					}
					/*
					 * Start the heuristic search.
					 * If this is an ASCII char, just do a linear search.
					 * Otherwise do a hinted, modified binary search.
					 * Start the first pivot at the last range found.
					 * And when moving the pivot, limit the movement by increasing
					 * powers of two. This should help with locality.
					 */
					__typeof__(table->cmap.format12.groups[0]) *foundGroup = NULL;
					if (c32 <= 0x7F) {
						// ASCII
						for (UInt32 idx = 0; idx < table->cmap.format12.nGroups; idx++) {
							__typeof__(table->cmap.format12.groups[idx]) *group = &table->cmap.format12.groups[idx];
							if (c32 < OSSwapBigToHostInt32(group->startCharCode)) {
								// We've fallen into a hole.
								break;
							} else if (c32 <= OSSwapBigToHostInt32(group->endCharCode)) {
								// This is the range.
								foundGroup = group;
								break;
							}
						}
					} else {
						// Heuristic search.
						UInt32 maxJump = (lastSegment == UINT32_MAX ? UINT32_MAX / 2 : 8);
						UInt32 lowIdx = 0, highIdx = table->cmap.format12.nGroups; // highIdx is the first invalid idx.
						UInt32 pivot = (lastSegment == UINT32_MAX ? lowIdx + (highIdx - lowIdx) / 2 : lastSegment);
						while (highIdx > lowIdx) {
							__typeof__(table->cmap.format12.groups[pivot]) *group = &table->cmap.format12.groups[pivot];
							if (c32 < OSSwapBigToHostInt32(group->startCharCode)) {
								highIdx = pivot;
							} else if (c32 > OSSwapBigToHostInt32(group->endCharCode)) {
								lowIdx = pivot + 1;
							} else {
								// We've hit the range.
								foundGroup = group;
								break;
							}
							if (highIdx - lowIdx > maxJump * 2) {
								if (highIdx == pivot) {
									pivot -= maxJump;
								} else {
									pivot += maxJump;
								}
								maxJump *= 2;
							} else {
								pivot = lowIdx + (highIdx - lowIdx) / 2;
							}
						}
						if (foundGroup != NULL) lastSegment = pivot;
					}
					if (foundGroup == NULL) {
						outGlyphs[j] = 0;
					} else {
						outGlyphs[j] = (CGGlyph)(OSSwapBigToHostInt32(foundGroup->startGlyphCode) +
												 (c32 - OSSwapBigToHostInt32(foundGroup->startCharCode)));
					}
				}
				break;
			}
		}
		if (outGlyphLen != NULL) *outGlyphLen = j;
	} else {
		// We have no table, so just null out the glyphs.
		bzero(outGlyphs, charLen*sizeof(CGGlyph));
		if (outGlyphLen != NULL) *outGlyphLen = 0;
	}
}

static BOOL mapGlyphsToAdvancesInFont(PXPFont *font, size_t n, CGGlyph glyphs[], CGFloat outAdvances[]) {
	int advances[n];
	if (CGFontGetGlyphAdvances(font.cgFont, glyphs, n, advances)) {
		CGFloat ratio = font.ratio;

		for (size_t i = 0; i < n; i++) {
			outAdvances[i] = advances[i]*ratio;
		}
		return YES;
	} else {
		bzero(outAdvances, n*sizeof(CGFloat));
	}
	return NO;
}

static id getValueOrDefaultForRun(PXPAttributeRun *run, NSString *key) {
	id value = [run.attributes objectForKey:key];
	if (value == nil) {
		static NSDictionary *defaultValues = nil;
		if (defaultValues == nil) {
			defaultValues = [[NSDictionary alloc] initWithObjectsAndKeys:
							 [PXPFont fontWithUIFont:[UIFont systemFontOfSize:12.0]], PXPFontAttributeName,
							 [UIColor blackColor], PXPForegroundColorAttributeName,
							 [UIColor clearColor], PXPBackgroundColorAttributeName,
							 [NSNumber numberWithInt:PXPUnderlineStyleNone], PXPUnderlineStyleAttributeName,
							 nil];
		}
		value = [defaultValues objectForKey:key];
	}
	return value;
}

static void readRunInformation(NSArray *attributes, NSUInteger len, CFMutableDictionaryRef fontTableMap,
							   NSUInteger index, PXPAttributeRun **currentRun, NSUInteger *nextRunStart,
							   PXPFont **currentFont, fontTable **currentTable) {
	*currentRun = [attributes objectAtIndex:index];
	*nextRunStart = ([attributes count] > index+1 ? [[attributes objectAtIndex:index+1] index] : len);
	*currentFont = getValueOrDefaultForRun(*currentRun, PXPFontAttributeName);
	if (!CFDictionaryGetValueIfPresent(fontTableMap, (*currentFont).cgFont, (const void **)currentTable)) {
		*currentTable = readFontTableFromCGFont((*currentFont).cgFont);
		CFDictionarySetValue(fontTableMap, (*currentFont).cgFont, *currentTable);
		releaseFontTable(*currentTable);
	}
}

static CGSize drawOrSizeTextConstrainedToSize(BOOL performDraw, NSString *string, NSArray *attributes, CGSize constrainedSize, NSUInteger maxLines,
											  NSLineBreakMode lineBreakMode, NSTextAlignment alignment, BOOL ignoreColor) {
	NSUInteger len = [string length];
	NSUInteger idx = 0;
	CGPoint drawPoint = CGPointZero;
	CGSize retValue = CGSizeZero;
	CGContextRef ctx = (performDraw ? UIGraphicsGetCurrentContext() : NULL);

	BOOL convertNewlines = (maxLines == 1);

	/*
	 * Extract the characters from the string.
	 * Convert newlines to spaces if necessary.
	 */
	unichar *characters = (unichar *)malloc(sizeof(unichar) * len);
	if (convertNewlines) {
		NSCharacterSet *charset = [NSCharacterSet newlineCharacterSet];
		NSRange range = NSMakeRange(0, len);
		size_t cIdx = 0;
		while (range.length > 0) {
			NSRange newlineRange = [string rangeOfCharacterFromSet:charset options:0 range:range];
			if (newlineRange.location == NSNotFound) {
				[string getCharacters:&characters[cIdx] range:range];
				cIdx += range.length;
				break;
			} else {
				NSUInteger delta = newlineRange.location - range.location;
				if (newlineRange.location > range.location) {
					[string getCharacters:&characters[cIdx] range:NSMakeRange(range.location, delta)];
				}
				cIdx += delta;
				characters[cIdx] = (unichar)' ';
				cIdx++;
				delta += newlineRange.length;
				range.location += delta, range.length -= delta;
				if (newlineRange.length == 1 && range.length >= 1 &&
					[string characterAtIndex:newlineRange.location] == (unichar)'\r' &&
					[string characterAtIndex:range.location] == (unichar)'\n') {
					// CRLF sequence, skip the LF.
					range.location += 1, range.length -= 1;
				}
			}
		}
		len = cIdx;
	} else {
		[string getCharacters:characters range:NSMakeRange(0, len)];
	}

	// Create storage for glyphs and advances.
	CGGlyph *glyphs;
	CGFloat *advances;
	{
		NSUInteger maxRunLength = 0;
		PXPAttributeRun *a = [attributes objectAtIndex:0];
		for (NSUInteger i = 1; i < [attributes count]; i++) {
			PXPAttributeRun *b = [attributes objectAtIndex:i];
			maxRunLength = MAX(maxRunLength, b.index - a.index);
			a = b;
		}
		maxRunLength = MAX(maxRunLength, len - a.index);
		maxRunLength++; // For a potential ellipsis.
		glyphs = (CGGlyph *)malloc(sizeof(CGGlyph) * maxRunLength);
		advances = (CGFloat *)malloc(sizeof(CGFloat) * maxRunLength);
	}

	// Use this table to cache all fontTable objects.
	CFMutableDictionaryRef fontTableMap = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks,
																	&kFontTableDictionaryValueCallBacks);

	// Fetch initial style values.
	NSUInteger currentRunIdx = 0;
	PXPAttributeRun *currentRun;
	NSUInteger nextRunStart;
	PXPFont *currentFont;
	fontTable *currentTable;

#define READ_RUN() readRunInformation(attributes, len, fontTableMap, \
currentRunIdx, &currentRun, &nextRunStart, \
&currentFont, &currentTable)

	READ_RUN();

	// Fetch the glyphs for the first run.
	size_t glyphCount;
	NSUInteger glyphIdx;

#define READ_GLYPHS() do { \
mapCharactersToGlyphsInFont(currentTable, &characters[currentRun.index], (nextRunStart - currentRun.index), glyphs, &glyphCount); \
mapGlyphsToAdvancesInFont(currentFont, (nextRunStart - currentRun.index), glyphs, advances); \
glyphIdx = 0; \
} while (0)

	READ_GLYPHS();

	NSMutableCharacterSet *alphaCharset = [NSMutableCharacterSet alphanumericCharacterSet];
	[alphaCharset addCharactersInString:@"([{'\"\u2019\u02BC"];

	/*
	 * Scan left-to-right looking for newlines or until we hit the width constraint.
	 * When we hit a wrapping point, calculate truncation as follows:
	 * If we have room to draw at least one more character on the next line, no truncation.
	 * Otherwise apply the truncation algorithm to the current line.
	 * After calculating any truncation, draw.
	 * Each time we hit the end of an attribute run, calculate the new font and make sure
	 * it fits (vertically) within the size constraint. If not, truncate this line.
	 * When we draw, iterate over the attribute runs for this line and draw each run separately.
	 */
	BOOL lastLine = NO; // Used to indicate truncation and to stop the iterating.
	NSUInteger lineCount = 1;
	while (idx < len && !lastLine) {
		if (maxLines > 0 && lineCount == maxLines) {
			lastLine = YES;
		}
		// Scan left-to-right.
		struct {
			NSUInteger index;
			NSUInteger glyphIndex;
			NSUInteger currentRunIdx;
		} indexCache = { idx, glyphIdx, currentRunIdx };
		CGSize lineSize = CGSizeMake(0, currentFont.leading);
		CGFloat lineAscender = currentFont.ascender;
		struct {
			NSUInteger index;
			NSUInteger glyphIndex;
			NSUInteger currentRunIdx;
			CGSize lineSize;
		} lastWrapCache = {0, 0, 0, CGSizeZero};
		BOOL inAlpha = NO; // Used for calculating wrap points.

		BOOL finishLine = NO;
		for (;idx <= len && !finishLine;) {
			NSUInteger skipCount = 0;
			if (idx == len) {
				finishLine = YES;
				lastLine = YES;
			} else {
				if (idx >= nextRunStart) {
					// Cycle the font and table and grab the next set of glyphs.
					do {
						currentRunIdx++;
						READ_RUN();
					} while (idx >= nextRunStart);
					READ_GLYPHS();
					// Re-scan the characters to synchronize the glyph index.
					for (NSUInteger j = currentRun.index; j < idx; j++) {
						if (UnicharIsHighSurrogate(characters[j]) && j+1<len && UnicharIsLowSurrogate(characters[j+1])) {
							j++;
						}
						glyphIdx++;
					}
					if (currentFont.leading > lineSize.height) {
						lineSize.height = currentFont.leading;
						if (retValue.height + currentFont.ascender > constrainedSize.height) {
							lastLine = YES;
							finishLine = YES;
						}
					}
					lineAscender = MAX(lineAscender, currentFont.ascender);
				}
				unichar c = characters[idx];
				// Mark a wrap point before spaces and after any stretch of non-alpha characters.
				BOOL markWrap = NO;
				if (c == (unichar)' ') {
					markWrap = YES;
				} else if ([alphaCharset characterIsMember:c]) {
					if (!inAlpha) {
						markWrap = YES;
						inAlpha = YES;
					}
				} else {
					inAlpha = NO;
				}
				if (markWrap) {
					lastWrapCache = (__typeof__(lastWrapCache)){
						.index = idx,
						.glyphIndex = glyphIdx,
						.currentRunIdx = currentRunIdx,
						.lineSize = lineSize
					};
				}
				// Process the line.
				if (c == (unichar)'\n' || c == 0x0085) { // U+0085 is the NEXT_LINE unicode character.
					finishLine = YES;
					skipCount = 1;
				} else if (c == (unichar)'\r') {
					finishLine = YES;
					// Check for CRLF.
					if (idx+1 < len && characters[idx+1] == (unichar)'\n') {
						skipCount = 2;
					} else {
						skipCount = 1;
					}
				} else if (lineSize.width + advances[glyphIdx] > constrainedSize.width) {
					finishLine = YES;
					if (retValue.height + lineSize.height + currentFont.ascender > constrainedSize.height) {
						lastLine = YES;
					}
					// Walk backwards if wrapping is necessary.
					if (lastWrapCache.index > indexCache.index && lineBreakMode != NSLineBreakByCharWrapping &&
						(!lastLine || lineBreakMode != NSLineBreakByClipping)) {
						// we're doing some sort of word wrapping
						idx = lastWrapCache.index;
						lineSize = lastWrapCache.lineSize;
						if (!lastLine) {
							// re-check if this is the last line
							if (lastWrapCache.currentRunIdx != currentRunIdx) {
								currentRunIdx = lastWrapCache.currentRunIdx;
								READ_RUN();
								READ_GLYPHS();
							}
							if (retValue.height + lineSize.height + currentFont.ascender > constrainedSize.height) {
								lastLine = YES;
							}
						}
						glyphIdx = lastWrapCache.glyphIndex;
						// skip any spaces
						for (NSUInteger j = idx; j < len && characters[j] == (unichar)' '; j++) {
							skipCount++;
						}
					}
				}
			}
			if (finishLine) {
				// TODO: support head/middle truncation
				if (lastLine && idx < len && lineBreakMode == NSLineBreakByTruncatingTail) {
					// truncate
					unichar ellipsis = 0x2026; // ellipsis (…)
					CGGlyph ellipsisGlyph;
					mapCharactersToGlyphsInFont(currentTable, &ellipsis, 1, &ellipsisGlyph, NULL);
					CGFloat ellipsisWidth;
					mapGlyphsToAdvancesInFont(currentFont, 1, &ellipsisGlyph, &ellipsisWidth);
					while ((idx - indexCache.index) > 1 && lineSize.width + ellipsisWidth > constrainedSize.width) {
						// we have more than 1 character and we're too wide, so back up
						idx--;
						if (UnicharIsHighSurrogate(characters[idx]) && UnicharIsLowSurrogate(characters[idx+1])) {
							idx--;
						}
						if (idx < currentRun.index) {
							PXPFont *oldFont = currentFont;
							do {
								currentRunIdx--;
								READ_RUN();
							} while (idx < currentRun.index);
							READ_GLYPHS();
							glyphIdx = glyphCount-1;
							if (oldFont != currentFont) {
								mapCharactersToGlyphsInFont(currentTable, &ellipsis, 1, &ellipsisGlyph, NULL);
								mapGlyphsToAdvancesInFont(currentFont, 1, &ellipsisGlyph, &ellipsisWidth);
							}
						} else {
							glyphIdx--;
						}
						lineSize.width -= advances[glyphIdx];
					}
					// skip any spaces before truncating
					while ((idx - indexCache.index) > 1 && characters[idx-1] == (unichar)' ') {
						idx--;
						if (idx < currentRun.index) {
							currentRunIdx--;
							READ_RUN();
							READ_GLYPHS();
							glyphIdx = glyphCount-1;
						} else {
							glyphIdx--;
						}
						lineSize.width -= advances[glyphIdx];
					}
					lineSize.width += ellipsisWidth;
					glyphs[glyphIdx] = ellipsisGlyph;
					idx++;
					glyphIdx++;
				}
				retValue.width = MAX(retValue.width, lineSize.width);
				retValue.height += lineSize.height;

				// draw
				if (performDraw) {
					switch (alignment) {
						case NSTextAlignmentLeft:
							drawPoint.x = 0;
							break;
						case NSTextAlignmentCenter:
							drawPoint.x = (constrainedSize.width - lineSize.width) / 2.0f;
							break;
						case NSTextAlignmentRight:
							drawPoint.x = constrainedSize.width - lineSize.width;
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
					NSUInteger stopGlyphIdx = glyphIdx;
					NSUInteger lastRunIdx = currentRunIdx;
					NSUInteger stopCharIdx = idx;
					idx = indexCache.index;
					if (currentRunIdx != indexCache.currentRunIdx) {
						currentRunIdx = indexCache.currentRunIdx;
						READ_RUN();
						READ_GLYPHS();
					}
					glyphIdx = indexCache.glyphIndex;
					for (NSUInteger drawIdx = currentRunIdx; drawIdx <= lastRunIdx; drawIdx++) {
						if (drawIdx != currentRunIdx) {
							currentRunIdx = drawIdx;
							READ_RUN();
							READ_GLYPHS();
						}
						NSUInteger numGlyphs;
						if (drawIdx == lastRunIdx) {
							numGlyphs = stopGlyphIdx - glyphIdx;
							idx = stopCharIdx;
						} else {
							numGlyphs = glyphCount - glyphIdx;
							idx = nextRunStart;
						}
						CGContextSetFont(ctx, currentFont.cgFont);
						CGContextSetFontSize(ctx, currentFont.pointSize);
						// calculate the fragment size
						CGFloat fragmentWidth = 0;
						for (NSUInteger g = 0; g < numGlyphs; g++) {
							fragmentWidth += advances[glyphIdx + g];
						}

						if (!ignoreColor) {
							UIColor *foregroundColor = getValueOrDefaultForRun(currentRun, PXPForegroundColorAttributeName);
							UIColor *backgroundColor = getValueOrDefaultForRun(currentRun, PXPBackgroundColorAttributeName);
							if (backgroundColor != nil && ![backgroundColor isEqual:[UIColor clearColor]]) {
								[backgroundColor setFill];
								UIRectFillUsingBlendMode((CGRect){ drawPoint, { fragmentWidth, lineSize.height } }, kCGBlendModeNormal);
							}
							[foregroundColor setFill];
						}

						CGContextShowGlyphsAtPoint(ctx, drawPoint.x, drawPoint.y + lineAscender, &glyphs[glyphIdx], numGlyphs);
						NSNumber *underlineStyle = getValueOrDefaultForRun(currentRun, PXPUnderlineStyleAttributeName);
						if ([underlineStyle	integerValue] & PXPAttributedStringUnderlineStyleMask) {
							// we only support single for the time being
							UIRectFill(CGRectMake(drawPoint.x, drawPoint.y + lineAscender, fragmentWidth, 1));
						}
						drawPoint.x += fragmentWidth;
						glyphIdx += numGlyphs;
					}
					drawPoint.y += lineSize.height;
				}
				idx += skipCount;
				glyphIdx += skipCount;
				lineCount++;
			} else {
				lineSize.width += advances[glyphIdx];
				glyphIdx++;
				idx++;
				if (idx < len && UnicharIsHighSurrogate(characters[idx-1]) && UnicharIsLowSurrogate(characters[idx])) {
					// skip the second half of the surrogate pair
					idx++;
				}
			}
		}
	}
	CFRelease(fontTableMap);
	free(glyphs);
	free(advances);
	free(characters);

#undef READ_GLYPHS
#undef READ_RUN

	return retValue;
}

static NSArray *attributeRunForFont(PXPFont *font) {
	return [NSArray arrayWithObject:[PXPAttributeRun attributeRunWithIndex:0
																attributes:[NSDictionary dictionaryWithObject:font
																									   forKey:PXPFontAttributeName]]];
}

static CGSize drawTextInRect(CGRect rect, NSString *text, NSArray *attributes, NSLineBreakMode lineBreakMode,
							 NSTextAlignment alignment, NSUInteger numberOfLines, BOOL ignoreColor) {
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	CGContextSaveGState(ctx);

	// flip it upside-down because our 0,0 is upper-left, whereas ttfs are for screens where 0,0 is lower-left
	CGAffineTransform textTransform = CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f);
	CGContextSetTextMatrix(ctx, textTransform);

	CGContextTranslateCTM(ctx, rect.origin.x, rect.origin.y);

	CGContextSetTextDrawingMode(ctx, kCGTextFill);
	CGSize size = drawOrSizeTextConstrainedToSize(YES, text, attributes, rect.size, numberOfLines, lineBreakMode, alignment, ignoreColor);

	CGContextRestoreGState(ctx);

	return size;
}

@implementation NSString (FontLabelStringDrawing)
// CGFontRef-based methods
- (CGSize)sizeWithCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize {
	return [self sizeWithPXPFont:[PXPFont fontWithCGFont:font size:pointSize]];
}

- (CGSize)sizeWithCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize constrainedToSize:(CGSize)size {
	return [self sizeWithPXPFont:[PXPFont fontWithCGFont:font size:pointSize] constrainedToSize:size];
}

- (CGSize)sizeWithCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize constrainedToSize:(CGSize)size
		   lineBreakMode:(NSLineBreakMode)lineBreakMode {
	return [self sizeWithPXPFont:[PXPFont fontWithCGFont:font size:pointSize] constrainedToSize:size lineBreakMode:lineBreakMode];
}

- (CGSize)drawAtPoint:(CGPoint)point withCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize {
	return [self drawAtPoint:point withPXPFont:[PXPFont fontWithCGFont:font size:pointSize]];
}

- (CGSize)drawInRect:(CGRect)rect withCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize {
	return [self drawInRect:rect withPXPFont:[PXPFont fontWithCGFont:font size:pointSize]];
}

- (CGSize)drawInRect:(CGRect)rect withCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize lineBreakMode:(NSLineBreakMode)lineBreakMode {
	return [self drawInRect:rect withPXPFont:[PXPFont fontWithCGFont:font size:pointSize] lineBreakMode:lineBreakMode];
}

- (CGSize)drawInRect:(CGRect)rect withCGFont:(CGFontRef)font pointSize:(CGFloat)pointSize
	   lineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment {
	return [self drawInRect:rect withPXPFont:[PXPFont fontWithCGFont:font size:pointSize] lineBreakMode:lineBreakMode alignment:alignment];
}

// PXPFont-based methods
- (CGSize)sizeWithPXPFont:(PXPFont *)font {
	CGSize size = drawOrSizeTextConstrainedToSize(NO, self, attributeRunForFont(font), CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX), 1,
												  NSLineBreakByClipping, NSTextAlignmentLeft, YES);
	return CGSizeMake(ceilf(size.width), ceilf(size.height));
}

- (CGSize)sizeWithPXPFont:(PXPFont *)font constrainedToSize:(CGSize)size {
	return [self sizeWithPXPFont:font constrainedToSize:size lineBreakMode:NSLineBreakByWordWrapping];
}

/*
 According to experimentation with UIStringDrawing, this can actually return a CGSize whose height is greater
 than the one passed in. The two cases are as follows:
 1. If the given size parameter's height is smaller than a single line, the returned value will
 be the height of one line.
 2. If the given size parameter's height falls between multiples of a line height, and the wrapped string
 actually extends past the size.height, and the difference between size.height and the previous multiple
 of a line height is >= the font's ascender, then the returned size's height is extended to the next line.
 To put it simply, if the baseline point of a given line falls in the given size, the entire line will
 be present in the output size.
 */
- (CGSize)sizeWithPXPFont:(PXPFont *)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode {
	size = drawOrSizeTextConstrainedToSize(NO, self, attributeRunForFont(font), size, 0, lineBreakMode, NSTextAlignmentLeft, YES);
	return CGSizeMake(ceilf(size.width), ceilf(size.height));
}

- (CGSize)sizeWithPXPFont:(PXPFont *)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode
		  numberOfLines:(NSUInteger)numberOfLines {
	size = drawOrSizeTextConstrainedToSize(NO, self, attributeRunForFont(font), size, numberOfLines, lineBreakMode, NSTextAlignmentLeft, YES);
	return CGSizeMake(ceilf(size.width), ceilf(size.height));
}

- (CGSize)drawAtPoint:(CGPoint)point withPXPFont:(PXPFont *)font {
	return [self drawAtPoint:point forWidth:CGFLOAT_MAX withPXPFont:font lineBreakMode:NSLineBreakByClipping];
}

- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width withPXPFont:(PXPFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode {
	return drawTextInRect((CGRect){ point, { width, CGFLOAT_MAX } }, self, attributeRunForFont(font), lineBreakMode, NSTextAlignmentLeft, 1, YES);
}

- (CGSize)drawInRect:(CGRect)rect withPXPFont:(PXPFont *)font {
	return [self drawInRect:rect withPXPFont:font lineBreakMode:NSLineBreakByWordWrapping];
}

- (CGSize)drawInRect:(CGRect)rect withPXPFont:(PXPFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode {
	return [self drawInRect:rect withPXPFont:font lineBreakMode:lineBreakMode alignment:NSTextAlignmentLeft];
}

- (CGSize)drawInRect:(CGRect)rect withPXPFont:(PXPFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode
		   alignment:(NSTextAlignment)alignment {
	return drawTextInRect(rect, self, attributeRunForFont(font), lineBreakMode, alignment, 0, YES);
}

- (CGSize)drawInRect:(CGRect)rect withPXPFont:(PXPFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode
		   alignment:(NSTextAlignment)alignment numberOfLines:(NSUInteger)numberOfLines {
	return drawTextInRect(rect, self, attributeRunForFont(font), lineBreakMode, alignment, numberOfLines, YES);
}
@end

@implementation PXPAttributedString (PXPZAttributedStringDrawing)
- (CGSize)size {
	CGSize size = drawOrSizeTextConstrainedToSize(NO, self.string, self.attributes, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX), 1,
												  NSLineBreakByClipping, NSTextAlignmentLeft, NO);
	return CGSizeMake(ceilf(size.width), ceilf(size.height));
}

- (CGSize)sizeConstrainedToSize:(CGSize)size {
	return [self sizeConstrainedToSize:size lineBreakMode:NSLineBreakByWordWrapping];
}

- (CGSize)sizeConstrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode {
	size = drawOrSizeTextConstrainedToSize(NO, self.string, self.attributes, size, 0, lineBreakMode, NSTextAlignmentLeft, NO);
	return CGSizeMake(ceilf(size.width), ceilf(size.height));
}

- (CGSize)sizeConstrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode
				  numberOfLines:(NSUInteger)numberOfLines {
	size = drawOrSizeTextConstrainedToSize(NO, self.string, self.attributes, size, numberOfLines, lineBreakMode, NSTextAlignmentLeft, NO);
	return CGSizeMake(ceilf(size.width), ceilf(size.height));
}

- (CGSize)drawAtPoint:(CGPoint)point {
	return [self drawAtPoint:point forWidth:CGFLOAT_MAX lineBreakMode:NSLineBreakByClipping];
}

- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode {
	return drawTextInRect((CGRect){ point, { width, CGFLOAT_MAX } }, self.string, self.attributes, lineBreakMode, NSTextAlignmentLeft, 1, NO);
}

- (CGSize)drawInRect:(CGRect)rect {
	return [self drawInRect:rect withLineBreakMode:NSLineBreakByWordWrapping];
}

- (CGSize)drawInRect:(CGRect)rect withLineBreakMode:(NSLineBreakMode)lineBreakMode {
	return [self drawInRect:rect withLineBreakMode:lineBreakMode alignment:NSTextAlignmentLeft];
}

- (CGSize)drawInRect:(CGRect)rect withLineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment {
	return drawTextInRect(rect, self.string, self.attributes, lineBreakMode, alignment, 0, NO);
}

- (CGSize)drawInRect:(CGRect)rect withLineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment
	   numberOfLines:(NSUInteger)numberOfLines {
	return drawTextInRect(rect, self.string, self.attributes, lineBreakMode, alignment, numberOfLines, NO);
}
@end