//
//  MILViewController.m
//  million
//
//  Created by Julian Weiss on 9/4/14.
//  Copyright (c) 2014 insanj. All rights reserved.
//

#import "MILViewController.h"
#import <QuartzCore/QuartzCore.h>

#define ONE_MILLION 1000000.0

static const NSInteger kMILPixelsPerStar = 5;

typedef NS_ENUM(NSUInteger, MILViewControllerState) {
	MILViewControllerIntroducingState = 1 << 0,
	MILViewControllerPlayingState = 1 << 1,
	MILViewControllerPausedState = 1 << 2,
	MILViewControllerStoppedState = 1 << 3,
};

@interface MILViewController ()

@property (nonatomic, readwrite) MILViewControllerState millionState;

@property (strong, nonatomic) UILabel *introductionHeaderLabel;

@property (strong, nonatomic) UILabel *introductionDescriptionLabel;

@property (strong, nonatomic) UITapGestureRecognizer *pausePlayGestureRecognizer;

@property (strong, nonatomic) UILongPressGestureRecognizer *stopGestureRecognizer;

@property (nonatomic, readonly) CGRect displayBounds;

@property (nonatomic, readwrite) NSInteger possibleStarsForDisplay;

@property (strong, nonatomic, readonly) NSMutableArray *uniqueColors;

@end

@implementation MILViewController

- (instancetype)init {
	self = [super init];
	
	if (self) {
		_displayBounds = [UIScreen mainScreen].nativeBounds;
	}
	
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.view.backgroundColor = [UIColor clearColor];
	
	UIActivityIndicatorView *introductionLoadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	introductionLoadingIndicator.center = self.view.center;
	[introductionLoadingIndicator startAnimating];
	[self.view addSubview:introductionLoadingIndicator];
	
	_uniqueColors = [[NSMutableArray alloc] initWithCapacity:ONE_MILLION];
	[self performSelectorInBackground:@selector(loadIntroduction:) withObject:introductionLoadingIndicator];
}

- (void)loadIntroduction:(UIActivityIndicatorView *)indicatorView {
	while (_uniqueColors.count < ONE_MILLION) {
		CGFloat hue = (arc4random() % 256 / 256.0);
		CGFloat saturation = (arc4random() % 128 / 256.0) + 0.5;
		CGFloat brightness = (arc4random() % 128 / 256.0) + 0.5;
		
		UIColor *hopefullyUniqueColor = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
		[_uniqueColors addObject:hopefullyUniqueColor];
	}
	
	[self performSelectorOnMainThread:@selector(finishedLoadingIntroduction:) withObject:indicatorView waitUntilDone:NO];
}

- (void)finishedLoadingIntroduction:(UIActivityIndicatorView *)indicatorView {
	_pausePlayGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognized:)];
	[self.view addGestureRecognizer:_pausePlayGestureRecognizer];
	
	_stopGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognized:)];
	[self.view addGestureRecognizer:_stopGestureRecognizer];
	
	[UIView animateWithDuration:0.2 animations:^(void) {
		indicatorView.alpha = 0.0;
	} completion:^(BOOL finished) {
		[indicatorView removeFromSuperview];
		[self presentIntroduction];
	}];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	
	[self stopGeneratingMillion];
}

#pragma mark - gestures

- (void)tapGestureRecognized:(UITapGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateEnded) {
		if (_millionState & MILViewControllerIntroducingState) {
			[self dismissIntroduction];
		}
			
		else if (_millionState & (MILViewControllerPausedState | MILViewControllerStoppedState)) {
			[self startGeneratingMillion];
		}
		
		else {
			[self pauseGeneratingMillion];
		}
	}
}

- (void)longPressGestureRecognized:(UILongPressGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateEnded) {
		if (_millionState & (MILViewControllerPausedState | MILViewControllerPlayingState)) {
			[self stopGeneratingMillion];
		}
		
		else {
			[self presentIntroduction];
		}
	}
}

#pragma mark - presentation

- (void)presentIntroduction {
	NSInteger numberOfPixels = _displayBounds.size.width * _displayBounds.size.height;
	_possibleStarsForDisplay = floorf(numberOfPixels / kMILPixelsPerStar);
	NSInteger rateOfAppearance = ceilf(ONE_MILLION / _possibleStarsForDisplay);
	
	if (!_introductionHeaderLabel) {
		CGRect introductionHeaderLabelFrame = CGRectMake(0.0, 0.0, self.view.frame.size.width, 50.0);
		CGRect introductioDescriptionLabelFrame = CGRectMake(20.0, introductionHeaderLabelFrame.size.height, self.view.frame.size.width - 40.0, 400.0);

		_introductionHeaderLabel = [[UILabel alloc] initWithFrame:introductionHeaderLabelFrame];
		_introductionHeaderLabel.backgroundColor = [UIColor clearColor];
		_introductionHeaderLabel.font = [UIFont fontWithName:@"AvenirNext-UltraLight" size:50.0];
		_introductionHeaderLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
		_introductionHeaderLabel.text = @"million";
		_introductionHeaderLabel.textAlignment = NSTextAlignmentCenter;
		_introductionHeaderLabel.alpha = 0.0;
		_introductionHeaderLabel.contentMode = UIViewContentModeCenter;
		_introductionHeaderLabel.numberOfLines = 0;
		
		_introductionDescriptionLabel = [[UILabel alloc] initWithFrame:introductioDescriptionLabelFrame];
		_introductionDescriptionLabel.backgroundColor = [UIColor clearColor];
		_introductionDescriptionLabel.font = [UIFont fontWithName:@"AvenirNext-UltraLight" size:20.0];
		_introductionDescriptionLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
		_introductionDescriptionLabel.text = [NSString stringWithFormat:@"every second millions of things are whirring around you. a million atoms pulse through your breath, a million wavelengths of color permeate your retinas, a million things pile up ahead of you. tap to see a million in lights. tap and hold to start over.\n\nthis display has %lu pixels. to show a million %lu-pixel stars, %lu cycles would have to occur.", (unsigned long)numberOfPixels, (unsigned long)kMILPixelsPerStar, (unsigned long)rateOfAppearance];
 		_introductionDescriptionLabel.textAlignment = NSTextAlignmentCenter;
		_introductionDescriptionLabel.alpha = 0.0;
		_introductionDescriptionLabel.contentMode = UIViewContentModeTop;
		_introductionDescriptionLabel.numberOfLines = 0;
		_introductionDescriptionLabel.lineBreakMode = NSLineBreakByWordWrapping;
		
		UIView *introductionContainerView = [[UIView alloc] initWithFrame:CGRectUnion(introductionHeaderLabelFrame, introductioDescriptionLabelFrame)];
		introductionContainerView.backgroundColor = [UIColor clearColor];
		introductionContainerView.center = self.view.center;
		
		[introductionContainerView addSubview:_introductionHeaderLabel];
		[introductionContainerView addSubview:_introductionDescriptionLabel];
		
		[self.view addSubview:introductionContainerView];
	}
	
	[UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^(void) {
		_introductionHeaderLabel.alpha = 1.0;
		_introductionDescriptionLabel.alpha = 1.0;
	} completion:^(BOOL finished) {
		_millionState = MILViewControllerIntroducingState;
	}];
}

- (void)dismissIntroduction {
		[UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
		_introductionHeaderLabel.alpha = 0.0;
		_introductionDescriptionLabel.alpha = 0.0;
	} completion:^(BOOL finished) {
		[self startGeneratingMillion];
	}];
}

#pragma mark - begin

- (void)startGeneratingMillion {
	_millionState = MILViewControllerPlayingState;
	
	[self repeatedlyGenerateStar];
}

#pragma mark - generation

- (void)repeatedlyGenerateStar {
	for (int i = 0; i < _possibleStarsForDisplay; i++) {
		// [self generateStarWithColor:[_uniqueColors objectAtIndex:arc4random_uniform(_uniqueColors.count)]];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self generateStarWithColor:[_uniqueColors objectAtIndex:arc4random_uniform(_uniqueColors.count)]];
		});
		// [self performSelectorOnMainThread:@selector(generateStarWithColor:) withObject:[_uniqueColors objectAtIndex:arc4random_uniform(_uniqueColors.count)] waitUntilDone:YES];
	}
	
	if (_millionState & MILViewControllerPlayingState) {
		NSLog(@"Starting new generation cycle...");
		// [self.view.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
	}
}

- (void)generateStarWithColor:(UIColor *)color {
	
	/*CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextMoveToPoint(context, 10.0, 20.0);
	CGContextAddLineToPoint(context, 20.0, 40.0);
	CGContextStrokePath(context);*/
	
	// UIGraphicsBeginImageContextWithOptions(CGSizeMake(kMILPixelsPerStar, kMILPixelsPerStar), YES, 1.0);
	
	/*CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	
	CGContextFillRect(context, CGRectMake(arc4random_uniform(_displayBounds.size.width - 1.0), arc4random_uniform(_displayBounds.size.height - 1.0), kMILPixelsPerStar, kMILPixelsPerStar));
	CGContextSetFillColor(context, CGColorGetComponents(color.CGColor));
	CGContextFillPath(context);
	CGContextRestoreGState(context);
*/
	
	/*
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextFillRect(context, CGRectMake(, kMILPixelsPerStar, kMILPixelsPerStar));
	CGContextSetFillColor(context, CGColorGetComponents(color.CGColor));
	CGContextFillPath(context);*/
	
	// UIGraphicsEndImageContext();
	
	CALayer *starLayer = [CALayer layer];
	starLayer.frame = CGRectMake(arc4random_uniform(_displayBounds.size.width - 1.0), arc4random_uniform(_displayBounds.size.height - 1.0), kMILPixelsPerStar, kMILPixelsPerStar);
	starLayer.backgroundColor = color.CGColor;
	[self.view.layer addSublayer:starLayer];
	
	/*
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetLineWidth(context, kMILPixelsPerStar / 2.0);
	CGContextSetStrokeColorWithColor(context, color.CGColor);
	
	CGPoint randomPoint = CGPointMake(arc4random_uniform(_displayBounds.size.width - 1.0), arc4random_uniform(_displayBounds.size.height - 1.0));
	
	CGContextMoveToPoint(context, randomPoint.x, randomPoint.y);
	CGContextAddLineToPoint(context, randomPoint.x + (kMILPixelsPerStar / 2.0), randomPoint.y + (kMILPixelsPerStar / 2.0));

	CGContextStrokePath(context);*/
}

#pragma mark - control

- (void)pauseGeneratingMillion {
	_millionState = MILViewControllerPausedState;
}

#pragma mark - end

- (void)stopGeneratingMillion {
	_millionState = MILViewControllerStoppedState;
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetFillColor(context, CGColorGetComponents(self.view.window.backgroundColor.CGColor));
	CGContextFillRect(context, self.view.bounds);
	CGContextStrokePath(context);
}

@end
