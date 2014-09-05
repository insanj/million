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

static const NSInteger kMILPixelsPerStar = 30;  // average size for sustained calls (shown below). the simulator looks good with about 16 pixels per star.
static const NSInteger kMILCallsPerCycle = 111; // amount of stars that can be feasibly generated in 1 sec, according to iPhone 5s capabilities. however, the
												// iPhone 5 (8.0) simulator can run up to around 255 calls per cycle without hinderance (as seen in screenies)

typedef NS_ENUM(NSUInteger, MILViewControllerState) {
	MILViewControllerIntroducingState = 1 << 0,
	MILViewControllerPlayingState = 1 << 1,
	MILViewControllerPausedState = 1 << 2,
	MILViewControllerStoppedState = 1 << 3,
};

@interface MILViewController ()

@property (strong, nonatomic, readonly) NSMutableArray *uniqueColors;

@property (nonatomic, readwrite) MILViewControllerState millionState;

@property (strong, nonatomic) UILabel *introductionHeaderLabel;

@property (strong, nonatomic) UILabel *introductionDescriptionLabel;

@property (strong, nonatomic) UILabel *introductionAttributionLabel;

@property (strong, nonatomic) UITapGestureRecognizer *pausePlayGestureRecognizer;

@property (strong, nonatomic) UILongPressGestureRecognizer *stopGestureRecognizer;

@property (nonatomic, readwrite) NSInteger possibleStarsForDisplay;

@property (strong, nonatomic, readwrite) NSNumber *pixelsUnoccupiedCount;

@property (strong, nonatomic) UILabel *pixelsUnoccupiedCountLabel;

@property (strong, nonatomic, readwrite) CADisplayLink *starDisplayLink;

@property (strong, nonatomic, readonly) UIImageView *starImageView;

@end

@implementation MILViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.view.backgroundColor = [UIColor clearColor];
	
	_starImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
	[self.view addSubview:_starImageView];
	
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
		CGFloat randomAlpha = (arc4random_uniform(100) + 1) / 100.0;
		
		UIColor *hopefullyUniqueColor = [UIColor colorWithHue:randomHue saturation:randomSaturation brightness:randomBrightness alpha:randomAlpha];
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
	CGRect displayBounds = [UIScreen mainScreen].bounds; // nativeBounds is only supported on iOS 8
	CGFloat displayScale = [UIScreen mainScreen].scale;
	
	NSInteger numberOfPixels = (displayBounds.size.width * displayScale) * (displayBounds.size.height * displayScale);
	_possibleStarsForDisplay = numberOfPixels / kMILPixelsPerStar;
	
	NSString *introductionLabelText = [NSString stringWithFormat:@"every second millions of things are whirring around you. a million atoms pulse through your breath, a million wavelengths of color permeate your retinas, a million things pile up ahead of you. tap to see a million in lights. tap and hold to start over.\n\nthis display has %@ pixels, which means, to light several layers of %@-pixel stars, it will take about %@ minutes.", [NSNumberFormatter localizedStringFromNumber:@(numberOfPixels) numberStyle:NSNumberFormatterDecimalStyle], /* [NSNumberFormatter localizedStringFromNumber:@(_possibleStarsForDisplay) numberStyle:NSNumberFormatterDecimalStyle], */ [NSNumberFormatter localizedStringFromNumber:@(kMILPixelsPerStar) numberStyle:NSNumberFormatterSpellOutStyle], [NSNumberFormatter localizedStringFromNumber:@(((ONE_MILLION / kMILPixelsPerStar) / kMILCallsPerCycle) / 60.0) numberStyle:NSNumberFormatterDecimalStyle]];
	UIFont *introductionDescriptionFont = [UIFont fontWithName:@"Avenir-Light" size:17.0];

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
		_introductionDescriptionLabel.textColor = [UIColor colorWithWhite:0.58 alpha:1.0];
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
		_starImageView.image = [UIImage new];
		
		if (!_pixelsUnoccupiedCountLabel) {
			_pixelsUnoccupiedCountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
			_pixelsUnoccupiedCountLabel.layer.cornerRadius = 4.0;
			_pixelsUnoccupiedCountLabel.textAlignment = NSTextAlignmentLeft;
			_pixelsUnoccupiedCountLabel.numberOfLines = 0;
			_pixelsUnoccupiedCountLabel.font = [UIFont fontWithName:@"AvenirNext" size:12.0];
			_pixelsUnoccupiedCountLabel.minimumScaleFactor = 0.9;
			_pixelsUnoccupiedCountLabel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.3];
			_pixelsUnoccupiedCountLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
			[self.view addSubview:_pixelsUnoccupiedCountLabel];
		}
		
		_pixelsUnoccupiedCount = @(ONE_MILLION);

		_pixelsUnoccupiedCountLabel.text = [NSNumberFormatter localizedStringFromNumber:_pixelsUnoccupiedCount numberStyle:NSNumberFormatterDecimalStyle];
		_pixelsUnoccupiedCountLabel.frame = UIEdgeInsetsInsetRect(self.view.frame, UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0));
		_pixelsUnoccupiedCountLabel.alpha = 0.0;
		
		[_pixelsUnoccupiedCountLabel sizeToFit];
		
		[UIView animateWithDuration:0.2 animations:^(void){
			_pixelsUnoccupiedCountLabel.alpha = 1.0;
			_starImageView.alpha = 1.0;
		}];
	}

	// Start up the clock...
	_starDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(immediatelyGenerateStar)];
	[_starDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

#pragma mark - generation

- (void)immediatelyGenerateStar {
	NSInteger pixelsUnoccupiedCountInteger = _pixelsUnoccupiedCount.integerValue;
	
	if (pixelsUnoccupiedCountInteger > 0) {
		for (NSInteger i = 0, mischievouslyRandomNumber = arc4random_uniform((int)_uniqueColors.count); i < kMILCallsPerCycle; i++, mischievouslyRandomNumber++) {
			[self generateStarWithColor:[_uniqueColors objectAtIndex:arc4random_uniform((int)_uniqueColors.count)]];
		}
	}
	
	else {
		_starDisplayLink.paused = YES;
		
		[UIView animateWithDuration:0.2 animations:^(void) {
			_pixelsUnoccupiedCountLabel.alpha = 0.0;
		}];
	}
	
	NSInteger pixelsUnoccupiedAfterGeneration = pixelsUnoccupiedCountInteger - (kMILCallsPerCycle * kMILPixelsPerStar);

	_pixelsUnoccupiedCount = @(pixelsUnoccupiedAfterGeneration);
	_pixelsUnoccupiedCountLabel.text = [NSNumberFormatter localizedStringFromNumber:_pixelsUnoccupiedCount numberStyle:NSNumberFormatterDecimalStyle];
	[_pixelsUnoccupiedCountLabel sizeToFit];
}

- (void)generateStarWithColor:(UIColor *)color {
	CGRect starImageDrawRect = _starImageView.frame;
	UIGraphicsBeginImageContextWithOptions(starImageDrawRect.size, NO, [UIScreen mainScreen].scale);
	CGContextRef starContext = UIGraphicsGetCurrentContext();
	
	[_starImageView.image drawInRect:starImageDrawRect];

	CGContextSetFillColorWithColor(starContext, color.CGColor);
	CGContextFillEllipseInRect(starContext, CGRectMake(arc4random_uniform(starImageDrawRect.size.width - kMILPixelsPerStar), arc4random_uniform(starImageDrawRect.size.height - kMILPixelsPerStar), kMILPixelsPerStar, kMILPixelsPerStar));

	UIImage *starCompositeImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	[UIView transitionWithView:_starImageView duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		_starImageView.image = starCompositeImage;
	} completion:nil];
	
/*	CALayer *starLayer = [CALayer layer];
	starLayer.frame = CGRectMake(arc4random_uniform(_displayBounds.size.width - 1.0), arc4random_uniform(_displayBounds.size.height - 1.0), kMILPixelsPerStar, kMILPixelsPerStar);
	starLayer.backgroundColor = color.CGColor;
	[self.view.layer addSublayer:starLayer]; */
}

#pragma mark - control

- (void)pauseGeneratingMillion {
	_millionState = MILViewControllerPausedState;
	
	_starDisplayLink.paused = YES;
}

#pragma mark - end

- (void)stopGeneratingMillion {
	_millionState = MILViewControllerStoppedState;
	
	_starDisplayLink.paused = YES;
	
	CGSize starSize = CGSizeMake(kMILPixelsPerStar, kMILPixelsPerStar);
	for (int i = (int)self.view.layer.sublayers.count - 1; i >= 0; i--) {
		CALayer *sublayer = self.view.layer.sublayers[i];
		if (CGSizeEqualToSize(sublayer.frame.size, starSize)) {
			[UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
				sublayer.opacity = 0.0;
			} completion:^(BOOL finished) {
				[sublayer removeFromSuperlayer];
			}];
		}
	}
	
	[UIView animateWithDuration:0.2 animations:^(void) {
		_pixelsUnoccupiedCountLabel.alpha = 0.0;
		_starImageView.alpha = 0.15;
	}];

	[self presentIntroduction];
}

@end
