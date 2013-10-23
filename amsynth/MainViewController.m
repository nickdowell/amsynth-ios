//
//  MainViewController.m
//  amsynth
//
//  Created by Nick Dowell on 18/05/2013.
//  Copyright (c) 2013 Nick Dowell. All rights reserved.
//

#import "MainViewController.h"

#import "SynthHoster.h"

#import <objc/runtime.h>


@protocol KeyboardViewDelegate<NSObject>

- (void)keyboardNoteDown:(NSUInteger)note;
- (void)keyboardNoteUp:(NSUInteger)note;

@end

@interface KeyboardView	: UIControl

@property (weak, nonatomic) IBOutlet id <KeyboardViewDelegate> delegate;

@end



@interface MainViewController () <KeyboardViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *banksTableView;
@property (weak, nonatomic) IBOutlet UITableView *presetsTableView;

@end



@implementation MainViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	self.title = @"amsynth";

	[self.banksTableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.synthHoster.currentBankIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
	[self.presetsTableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.synthHoster.currentPresetIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)keyboardNoteDown:(NSUInteger)note
{
	[self.synthHoster noteDown:note velocity:1];
}

- (void)keyboardNoteUp:(NSUInteger)note
{
	[self.synthHoster noteUp:note velocity:1];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (tableView == self.banksTableView)
		return [self.synthHoster.bankNames count];
	if (tableView == self.presetsTableView)
		return [self.synthHoster.presetNames count];
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
	}
	if (tableView == self.banksTableView)
		cell.textLabel.text = [self.synthHoster.bankNames objectAtIndex:[indexPath row]];
	if (tableView == self.presetsTableView)
		cell.textLabel.text = [self.synthHoster.presetNames objectAtIndex:[indexPath row]];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (tableView == self.banksTableView) {
		self.synthHoster.currentBankIndex = [indexPath row];
		[self.presetsTableView reloadData];
		[self.presetsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	}
	if (tableView == self.presetsTableView) {
		self.synthHoster.currentPresetIndex = [indexPath row];
	}
	[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

@end

#pragma mark -

@interface KeyboardViewKeyInfo : NSObject
@property (assign, nonatomic) int noteOffset;
@property (assign, nonatomic) CGRect rect;
@property (assign, nonatomic) BOOL black;
@property (weak, nonatomic) UITouch *touch;
@end
@implementation KeyboardViewKeyInfo
@end


static const int keyWidth = 55;

@implementation KeyboardView
{
	NSArray *_keys;
	int _baseNote;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder])) {
		_baseNote = 52;

		NSMutableArray *keys = [NSMutableArray array];

		CGFloat offset = 33;
		int noteOffset = 0;

		int numWhites = CGRectGetWidth(self.bounds) / keyWidth;
		for (int i=0; i<numWhites; i++) {
			int noteOffset = ((i / 7) * 12) + ((i % 7) * 2) - ((i % 7) < 3 ? 0 : 1);
			KeyboardViewKeyInfo *key = [[KeyboardViewKeyInfo alloc] init];
			key.noteOffset = noteOffset;
			key.rect = CGRectMake(i * 55, -5, 55, CGRectGetHeight(self.bounds) + 5);
			[keys addObject:key];
			noteOffset += 2;
		}

		noteOffset = 1;
		for (int i=0; offset < CGRectGetWidth(self.bounds); i++) {
			if ((i % 7) == 2) {
				offset += 33;
				noteOffset ++;
				continue;
			}
			if ((i % 7) == 6) {
				offset += 40;
				noteOffset ++;
				continue;
			}
			KeyboardViewKeyInfo *key = [[KeyboardViewKeyInfo alloc] init];
			key.black = YES;
			key.noteOffset = noteOffset;
			key.rect = CGRectMake(offset, -5, 33, 180);
			[keys addObject:key];
			offset += ((i % 7) < 2) ? 66 : 60;
			noteOffset += 2;
		}

		_keys = [keys copy];
	}
	return self;
}

- (KeyboardViewKeyInfo *)keyForLocation:(CGPoint)location
{
	for (KeyboardViewKeyInfo *key in [_keys reverseObjectEnumerator])
		if (CGRectContainsPoint(key.rect, location))
			return key;
	return nil;
}

- (KeyboardViewKeyInfo *)keyForTouch:(UITouch *)touch
{
	for (KeyboardViewKeyInfo *key in _keys)
		if (key.touch == touch)
			return key;
	return nil;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (UITouch *touch in touches) {
		KeyboardViewKeyInfo *key = [self keyForLocation:[touch locationInView:self]];
		NSParameterAssert(key);
		[_delegate keyboardNoteDown:_baseNote + key.noteOffset];
		key.touch = touch;
		[self setNeedsDisplayInRect:key.rect];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (UITouch *touch in touches) {
		KeyboardViewKeyInfo *key = [self keyForTouch:touch];
		KeyboardViewKeyInfo *newKey = [self keyForLocation:[touch locationInView:self]];
		if (newKey != key) {
			[_delegate keyboardNoteUp:_baseNote + key.noteOffset];
			key.touch = nil;
			[self setNeedsDisplayInRect:key.rect];
			if (newKey) {
				[_delegate keyboardNoteDown:_baseNote + newKey.noteOffset];
				newKey.touch = touch;
				[self setNeedsDisplayInRect:newKey.rect];
			}
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (UITouch *touch in touches) {
		KeyboardViewKeyInfo *key = [self keyForTouch:touch];
		[_delegate keyboardNoteUp:_baseNote + key.noteOffset];
		key.touch = nil;
		[self setNeedsDisplayInRect:key.rect];
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (UITouch *touch in touches) {
		KeyboardViewKeyInfo *key = [self keyForTouch:touch];
		[_delegate keyboardNoteUp:_baseNote + key.noteOffset];
		key.touch = nil;
		[self setNeedsDisplayInRect:key.rect];
	}
}

- (void)drawRect:(CGRect)rect
{
	for (KeyboardViewKeyInfo *key in _keys) {
		if (CGRectIntersectsRect(key.rect, rect) == NO)
			continue;
		if (key.black) {
			UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:key.rect cornerRadius:5];
			[(key.touch ? [UIColor colorWithWhite:0.2 alpha:1] : [UIColor blackColor]) setFill];
			[path fill];
		} else {
			UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:key.rect cornerRadius:5];
			[[UIColor colorWithWhite:key.touch ? 0.7 : 1 alpha:1] setFill];
			[[UIColor blackColor] setStroke];
			path.lineWidth = 1;
			[path fill];
			[path stroke];
		}
	}
}

@end
