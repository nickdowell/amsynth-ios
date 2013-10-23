//
//  AppDelegate.m
//  amsynth
//
//  Created by Nick Dowell on 18/05/2013.
//  Copyright (c) 2013 Nick Dowell. All rights reserved.
//

#import "AppDelegate.h"

#import "MainViewController.h"
#import "SynthHoster.h"


@implementation AppDelegate
{
	SynthHoster *_hoster;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	_hoster = [[SynthHoster alloc] init];
	[_hoster start];

	MainViewController *viewController = [[MainViewController alloc] init];
	viewController.synthHoster = _hoster;

	UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
	navigationController.navigationBar.barStyle = UIBarStyleBlack;
#ifdef __IPHONE_7_0
	if ([navigationController respondsToSelector:@selector(setTranslucent:)])
		navigationController.navigationBar.translucent = NO;
#endif

	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.backgroundColor = [UIColor blackColor];
	self.window.rootViewController = navigationController;
	[self.window makeKeyAndVisible];

	return YES;
}

@end
