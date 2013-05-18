//
//  SynthHoster.h
//  amsynth
//
//  Created by Nick Dowell on 18/05/2013.
//  Copyright (c) 2013 Nick Dowell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SynthHoster : NSObject

- (void)start;

- (void)noteDown:(NSUInteger)note velocity:(float)velocity;
- (void)noteUp:(NSUInteger)note velocity:(float)velocity;

@property (readonly, nonatomic) NSArray *bankNames;
@property (assign, nonatomic) NSUInteger currentBankIndex;

@property (readonly, nonatomic) NSArray *presetNames;
@property (assign, nonatomic) NSUInteger currentPresetIndex;

@end
