//
//  FBShareApp.h
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FacebookUtil.h"
#import "Facebook.h"

@interface FBShareApp : NSObject <FBFriendPickerDelegate>

- (id)initWithFacebookUtil:(FacebookUtil *)fb message:(NSString *)msg;

- (void)presentFromViewController:(UIViewController *)controller;

@end
