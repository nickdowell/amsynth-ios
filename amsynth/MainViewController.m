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
	}
	if (tableView == self.presetsTableView) {
		self.synthHoster.currentPresetIndex = [indexPath row];
	}
}

@end

#pragma mark -

static const int keyWidth = 55;

@implementation KeyboardView
{
	NSMutableDictionary *_touchNotes;
}

- (int)noteForWhiteKeyAtIndex:(int)index
{
	int key = index % 7;
	int oct = index / 7;

	int note = 52;
	note = note + (oct * 12);
	if (key < 3)
		note = note + key * 2;
	else
		note = note + key * 2 - 1;

	return note;
}

- (int)noteForLocation:(CGPoint)location
{
	int key = (int)(location.x / keyWidth) % 7;
	int oct = (int)(location.x / keyWidth) / 7;

	int note = 52;
	note = note + (oct * 12);
	if (key < 3)
		note = note + key * 2;
	else
		note = note + key * 2 - 1;

	return note;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (_touchNotes == nil)
		_touchNotes = [NSMutableDictionary dictionary];

	for (UITouch *touch in touches) {
		int note = [self noteForLocation:[touch locationInView:self]];
		[_touchNotes setObject:[NSNumber numberWithInt:note] forKey:[NSValue valueWithNonretainedObject:touch]];
		[_delegate keyboardNoteDown:note];
		[self setNeedsDisplay];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (UITouch *touch in touches) {
		int last = [[_touchNotes objectForKey:[NSValue valueWithNonretainedObject:touch]] intValue];
		int note = [self noteForLocation:[touch locationInView:self]];
		if (note != last) {
			[_touchNotes setObject:[NSNumber numberWithInt:note] forKey:[NSValue valueWithNonretainedObject:touch]];
			[_delegate keyboardNoteUp:last];
			[_delegate keyboardNoteDown:note];
			[self setNeedsDisplay];
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (UITouch *touch in touches) {
		int note = [[_touchNotes objectForKey:[NSValue valueWithNonretainedObject:touch]] intValue];
		[_touchNotes removeObjectForKey:[NSValue valueWithNonretainedObject:touch]];
		[_delegate keyboardNoteUp:note];
		[self setNeedsDisplay];
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (UITouch *touch in touches) {
		int note = [[_touchNotes objectForKey:[NSValue valueWithNonretainedObject:touch]] intValue];
		[_touchNotes removeObjectForKey:[NSValue valueWithNonretainedObject:touch]];
		[_delegate keyboardNoteUp:note];
		[self setNeedsDisplay];
	}
}

- (void)drawRect:(CGRect)rect
{
	NSArray *notes = [_touchNotes allValues];

	int numWhites = CGRectGetWidth(self.bounds) / keyWidth;
	for (int i=0; i<numWhites; i++) {
		BOOL isPressed = [notes containsObject:[NSNumber numberWithInt:[self noteForWhiteKeyAtIndex:i]]];
		UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(i * 55, -5, 55, CGRectGetHeight(self.bounds) + 5) cornerRadius:5];
		[[UIColor colorWithWhite:isPressed ? 0.7 : 1 alpha:1] setFill];
		[[UIColor blackColor] setStroke];
		path.lineWidth = 1;
		[path fill];
		[path stroke];
	}

	CGFloat offset = 33;
	for (int i=0; offset < CGRectGetWidth(self.bounds); i++) {
		if ((i % 7) == 2) {
			offset += 33;
			continue;
		}
		if ((i % 7) == 6) {
			offset += 40;
			continue;
		}
		UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(offset, -5, 33, 180) cornerRadius:5];
		[[UIColor blackColor] setFill];
		[path fill];
		if ((i % 7) < 2)
			offset += 66;
		else
			offset += 60;
	}
}

@end
