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
#define GEN_DELAY 0.0

static const NSInteger kMILPixelsPerStar = 1;
static const NSInteger kMILCallsPerCycle = 1000;
static const NSInteger kMILStarsPerCycle = kMILCallsPerCycle; // estimated from CADisplayLink averages. obviously not entirely legitamate.

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

@property (strong, nonatomic) UILabel *introductionAttributionLabel;

@property (strong, nonatomic) UITapGestureRecognizer *pausePlayGestureRecognizer;

@property (strong, nonatomic) UILongPressGestureRecognizer *stopGestureRecognizer;

@property (nonatomic, readonly) CGRect displayBounds;

@property (nonatomic, readwrite) NSInteger possibleStarsForDisplay;

@property (strong, nonatomic, readonly) NSMutableArray *uniqueColors;

@property (strong, nonatomic, readwrite) NSNumber *starCount;

@property (strong, nonatomic) UILabel *starCountLabel;

// @property (nonatomic, readwrite) NSTimeInterval starDisplayRate;

@property (strong, nonatomic, readwrite) CADisplayLink *starDisplayLink;

@end

@implementation MILViewController

- (instancetype)init {
	self = [super init];
	
	if (self) {
		_displayBounds = [UIScreen mainScreen].bounds; // nativeBounds is only supported on iOS 8
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
		CGFloat randomHue = arc4random_uniform(256) / 256.0;
		CGFloat randomSaturation = (arc4random_uniform(128) / 256.0) + 0.5;
		CGFloat randomBrightness = (arc4random_uniform(128) / 256.0) + 0.5;
		
		UIColor *hopefullyUniqueColor = [UIColor colorWithHue:randomHue saturation:randomSaturation brightness:randomBrightness alpha:1.0];
		[_uniqueColors addObject:hopefullyUniqueColor];
	}
	
	[self performSelectorOnMainThread:@selector(finishedLoadingIntroduction:) withObject:indicatorView waitUntilDone:NO];
}

- (void)finishedLoadingIntroduction:(UIActivityIndicatorView *)indicatorView {
	_pausePlayGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognized:)];
	[self.view addGestureRecognizer:_pausePlayGestureRecognizer];
	
	_stopGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognized:)];
	_stopGestureRecognizer.minimumPressDuration = 1.0;
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
	[UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
		sender.view.alpha = 0.8;
	}completion:^(BOOL finished) {
		[UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^(void) {
			sender.view.alpha = 1.0;
		}completion:nil];
	}];
	
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
	if (sender.state == UIGestureRecognizerStateBegan) {
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
	
	NSString *introductionLabelText = [NSString stringWithFormat:@"every second millions of things are whirring around you. a million atoms pulse through your breath, a million wavelengths of color permeate your retinas, a million things pile up ahead of you. tap to see a million in lights. tap and hold to start over.\n\nthis display has %@ pixels. to show a million %lu-pixel stars, %lu cycles would have to occur. for now, estimated time is %@ minutes.", [NSNumberFormatter localizedStringFromNumber:@(numberOfPixels) numberStyle:NSNumberFormatterDecimalStyle], (unsigned long)kMILPixelsPerStar, (unsigned long)rateOfAppearance, [NSNumberFormatter localizedStringFromNumber:@(ONE_MILLION / kMILStarsPerCycle /* * 60.0 * 60.0)*/ ) numberStyle:NSNumberFormatterDecimalStyle]];
	UIFont *introductionDescriptionFont = [UIFont fontWithName:@"AvenirNext-UltraLight" size:20.0];

	CGRect introductionHeaderLabelFrame = CGRectMake(0.0, 0.0, self.view.frame.size.width, 50.0);
	CGRect introductionDescriptionLabelFrame = CGRectMake(20.0, introductionHeaderLabelFrame.size.height, self.view.frame.size.width - 40.0, 0.0); // self.view.frame.size.height - introductionHeaderLabelFrame.size.height);
	introductionDescriptionLabelFrame.size.height = [introductionLabelText boundingRectWithSize:CGSizeMake(introductionDescriptionLabelFrame.size.width, self.view.frame.size.height - introductionHeaderLabelFrame.size.height) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName : introductionDescriptionFont } context:nil].size.height;
	
	CGFloat initialOffsetAmount = 10.0;
	
	CGRect introductionInitialHeaderLabelFrame = introductionHeaderLabelFrame;
	introductionInitialHeaderLabelFrame.origin.y -= initialOffsetAmount;
	
	CGRect introductionInitialDescriptionLabelFrame = introductionDescriptionLabelFrame;
	introductionInitialDescriptionLabelFrame.origin.y += initialOffsetAmount;
	
	CGRect introductionAttributionLabelFrame = self.view.frame;
	introductionAttributionLabelFrame.origin.y = introductionAttributionLabelFrame.size.height;
	introductionAttributionLabelFrame.size.height = 30.0;
	introductionAttributionLabelFrame.origin.y -= introductionAttributionLabelFrame.size.height;
	introductionAttributionLabelFrame.origin.x -= 10.0;
	
	if (!_introductionHeaderLabel) {
		_introductionHeaderLabel = [[UILabel alloc] initWithFrame:introductionInitialHeaderLabelFrame];
		_introductionHeaderLabel.backgroundColor = [UIColor clearColor];
		_introductionHeaderLabel.font = [UIFont fontWithName:@"AvenirNext-UltraLight" size:50.0];
		_introductionHeaderLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
		_introductionHeaderLabel.text = @"million";
		_introductionHeaderLabel.textAlignment = NSTextAlignmentCenter;
		_introductionHeaderLabel.alpha = 0.0;
		_introductionHeaderLabel.numberOfLines = 0;
		
		_introductionDescriptionLabel = [[UILabel alloc] initWithFrame:introductionInitialDescriptionLabelFrame];
		_introductionDescriptionLabel.backgroundColor = [UIColor clearColor];
		_introductionDescriptionLabel.font = introductionDescriptionFont;
		_introductionDescriptionLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
		_introductionDescriptionLabel.text = introductionLabelText;
		_introductionDescriptionLabel.textAlignment = NSTextAlignmentCenter;
		_introductionDescriptionLabel.alpha = 0.0;
		_introductionDescriptionLabel.numberOfLines = 0;
		_introductionDescriptionLabel.lineBreakMode = NSLineBreakByWordWrapping;
		
		_introductionAttributionLabel = [[UILabel alloc] initWithFrame:introductionAttributionLabelFrame];
		_introductionAttributionLabel.backgroundColor = [UIColor clearColor];
		_introductionAttributionLabel.font = [UIFont fontWithName:@"AvenirNext-Light" size:10.0];
		_introductionAttributionLabel.textColor = [UIColor colorWithWhite:0.8 alpha:0.1];
		_introductionAttributionLabel.text = @"© Julian Weiss";
		_introductionAttributionLabel.textAlignment = NSTextAlignmentRight;
		_introductionAttributionLabel.alpha = 0.0;
		_introductionAttributionLabel.numberOfLines = 1;
		
		UIView *introductionContainerView = [[UIView alloc] initWithFrame:CGRectUnion(introductionInitialHeaderLabelFrame, introductionInitialDescriptionLabelFrame)];
		introductionContainerView.backgroundColor = [UIColor clearColor];
		introductionContainerView.center = self.view.center;
		
		[introductionContainerView addSubview:_introductionHeaderLabel];
		[introductionContainerView addSubview:_introductionDescriptionLabel];
		
		[self.view addSubview:introductionContainerView];
		[self.view addSubview:_introductionAttributionLabel];
	}
	
	_introductionHeaderLabel.alpha = 0.0;
	_introductionDescriptionLabel.alpha = 0.0;
	
	[UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^(void) {
		_introductionHeaderLabel.alpha = 1.0;
		_introductionDescriptionLabel.alpha = 1.0;
		_introductionAttributionLabel.alpha = 1.0;
		
		_introductionHeaderLabel.frame = introductionHeaderLabelFrame;
		_introductionDescriptionLabel.frame = introductionDescriptionLabelFrame;
	} completion:^(BOOL finished) {
		_millionState = MILViewControllerIntroducingState;
	}];
}

- (void)dismissIntroduction {
		[UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
		_introductionHeaderLabel.alpha = 0.0;
		_introductionDescriptionLabel.alpha = 0.0;
		_introductionAttributionLabel.alpha = 0.0;
	} completion:^(BOOL finished) {
		[self startGeneratingMillion];
	}];
}

#pragma mark - begin

- (void)startGeneratingMillion {
	BOOL starsArePaused = _millionState & MILViewControllerPausedState;
	_millionState = MILViewControllerPlayingState;

	if (!starsArePaused) {
		if (_starCountLabel) {
			_starCountLabel.text = @"";
		}
		
		else {
			CGRect starCountLabel = self.view.frame;
			starCountLabel.origin.x += 10.0;
			starCountLabel.size.width -= 20.0;
			starCountLabel.origin.y += 10.0;
			starCountLabel.size.height -= 20.0;
			
			_starCountLabel = [[UILabel alloc] initWithFrame:starCountLabel];
			_starCountLabel.layer.cornerRadius = 4.0;
			_starCountLabel.textAlignment = NSTextAlignmentLeft;
			_starCountLabel.numberOfLines = 0;
			_starCountLabel.font = [UIFont fontWithName:@"AvenirNext" size:12.0];
			_starCountLabel.minimumScaleFactor = 0.9;
			_starCountLabel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.3];
			_starCountLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
			[self.view.superview addSubview:_starCountLabel];
		}
		
		_starCountLabel.alpha = 0.0;
		_starCount = @(ONE_MILLION);
		
		[UIView animateWithDuration:0.2 animations:^(void){
			_starCountLabel.alpha = 1.0;
		}];
	}
	
	// CADisplayLink *phonyDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:nil];
	// _starDisplayRate = phonyDisplayLink.duration * phonyDisplayLink.frameInterval;
	// 	[self repeatedlyGenerateStar];

	// Start up the clock...
	_starDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(immediatelyGenerateStar)];
	[_starDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

	// [self repeatedlyGenerateStar:@(ONE_MILLION)];
}

#pragma mark - generation

- (void)repeatedlyGenerateStar {
	NSInteger starCountInteger = _starCount.integerValue;
	_starCount = @(starCountInteger - 1);
	
	_starCountLabel.text = [NSNumberFormatter localizedStringFromNumber:_starCount numberStyle:NSNumberFormatterDecimalStyle];
	[_starCountLabel sizeToFit];
	
	if (starCountInteger > 0) {
		[self generateStarWithColor:[_uniqueColors objectAtIndex:arc4random_uniform(_uniqueColors.count)]];
		[self performSelector:@selector(repeatedlyGenerateStar) withObject:nil afterDelay:GEN_DELAY];
		// [self performSelectorInBackground:@selector(repeatedlyGenerateStar) withObject:nil];
	}
	
	else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(repeatedlyGenerateStar) object:nil];
		
		[UIView animateWithDuration:0.2 animations:^(void) {
			_starCountLabel.alpha = 0.0;
		}];
	}
}

- (void)immediatelyGenerateStar {
	NSInteger starCountInteger = _starCount.integerValue;
	_starCount = @(starCountInteger - kMILCallsPerCycle);
	
	if (starCountInteger > 1) {
		for (int i = 0, mischievouslyRandomNumber = arc4random_uniform(_uniqueColors.count); i < kMILCallsPerCycle; i++, mischievouslyRandomNumber++) {
			[self generateStarWithColor:[_uniqueColors objectAtIndex:arc4random_uniform(_uniqueColors.count)]];
		}

		// [self performSelectorInBackground:@selector(repeatedlyGenerateStar) withObject:nil];
	}
	
	else {
		_starDisplayLink.paused = YES;
		[self repeatedlyGenerateStar];
	}
	
	_starCountLabel.text = [NSNumberFormatter localizedStringFromNumber:_starCount numberStyle:NSNumberFormatterDecimalStyle];
	[_starCountLabel sizeToFit];
}

- (void)generateStarWithColor:(UIColor *)color {
	CALayer *starLayer = [CALayer layer];
	starLayer.frame = CGRectMake(arc4random_uniform(_displayBounds.size.width - 1.0), arc4random_uniform(_displayBounds.size.height - 1.0), kMILPixelsPerStar, kMILPixelsPerStar);
	starLayer.backgroundColor = color.CGColor;
	[self.view.layer addSublayer:starLayer];
}

#pragma mark - control

- (void)pauseGeneratingMillion {
	_millionState = MILViewControllerPausedState;
	
	_starDisplayLink.paused = YES;
	// [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(repeatedlyGenerateStar) object:nil];
}

#pragma mark - end

- (void)stopGeneratingMillion {
	_millionState = MILViewControllerStoppedState;
	
	_starDisplayLink.paused = YES;
	// [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(repeatedlyGenerateStar) object:nil];
	
	CGSize starSize = CGSizeMake(kMILPixelsPerStar, kMILPixelsPerStar);
	for (int i = self.view.layer.sublayers.count - 1; i >= 0; i--) {
		CALayer *sublayer = self.view.layer.sublayers[i];
		if (CGSizeEqualToSize(sublayer.frame.size, starSize)) {
			[UIView animateWithDuration:0.1 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
				sublayer.opacity = 0.0;
			} completion:^(BOOL finished) {
				[sublayer removeFromSuperlayer];
			}];
		}
	}
	
	_starCountLabel.alpha = 0.0;
	[self presentIntroduction];
}

@end
