//
//  MILViewController.h
//  million
//
//  Created by Julian Weiss on 9/4/14.
//  Copyright (c) 2014 insanj. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MILViewController : UIViewController

/**
 *  Presents an appropriate introduction to the generation process, at any point in generation.
 */
- (void)presentIntroduction;

/**
 *  Dismisses the introduction presented in @p -presentIntroduction.
 */
- (void)dismissIntroduction;

/**
 *  Begins the generation of a million objects, regardless of previous state, loading them into view.
 */
- (void)startGeneratingMillion;

/**
 *  Pauses the generation of a million objects, leaving them in the view.
 */
- (void)pauseGeneratingMillion;

/**
 *  Stops the generation of a million objects, and removes all of them from the view.
 */
- (void)stopGeneratingMillion;

@end
