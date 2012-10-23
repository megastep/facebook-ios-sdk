//
//  FBShareApp.m
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import "FBShareApp.h"
#import "FBGraphUserExtraFields.h"

@implementation FBShareApp {
    NSString *_message;
    NSMutableArray *_fbFriends;
    FacebookUtil *_facebookUtil;
    FBFriendPickerViewController *_friendPickerController;
    UIViewController *_presenter;
}


- (id)initWithFacebookUtil:(FacebookUtil *)fb message:(NSString *)msg {
    self = [super init];
    if (self) {
        _facebookUtil = fb;
        _message = [msg copy];
    }
    return self;
}

- (void)presentFromViewController:(UIViewController *)controller {
    if (FBSession.activeSession.isOpen) {
        _friendPickerController = [[FBFriendPickerViewController alloc] init];
        
        // Configure the picker ...
        _friendPickerController.title = NSLocalizedString(@"Select Friends",@"Facebook friend picker title");
        // Set this view controller as the friend picker delegate
        _friendPickerController.delegate = self;
        // Ask for friend device data
        _friendPickerController.fieldsForRequest = [NSSet setWithObjects:@"devices", @"installed", nil];
        
        // Fetch the data
        [_friendPickerController loadData];
        [_friendPickerController clearSelection];
        
        // Present view controller modally.
        _presenter = controller;
        if ([_presenter respondsToSelector:@selector(presentViewController:animated:completion:)]) {
            // iOS 5+
            [_presenter presentViewController:_friendPickerController
                                     animated:YES
                                   completion:nil];
        } else {
            [_presenter presentModalViewController:_friendPickerController
                                          animated:YES];
        }
        
    } else {
        [_facebookUtil login:YES andThen:^{
            [self presentFromViewController:controller];
        }];
    }
}

- (BOOL)friendPickerViewController:(FBFriendPickerViewController *)friendPicker
                 shouldIncludeUser:(id<FBGraphUserExtraFields>)user
{
    // Ignore users who are already using the app
    if ([user.installed boolValue] == YES)
        return NO;
    
    NSArray *deviceData = user.devices;
    // Loop through list of devices
    for (NSDictionary *deviceObject in deviceData) {
        // Check if there is a device match
        if ([@"iOS" isEqualToString:[deviceObject objectForKey:@"os"]]) {
            // Friend is an iOS user, include them in the display
            return YES;
        }
    }
    // Friend is not an iOS user, do not include them
    return NO;
}

- (void)friendPickerViewController:(FBFriendPickerViewController *)friendPicker
                       handleError:(NSError *)error
{
    NSLog(@"FriendPickerViewController error: %@", error);
}

- (void)facebookViewControllerCancelWasPressed:(id)sender
{
#ifdef DEBUG
    NSLog(@"Friend selection cancelled.");
#endif
    if ([_presenter respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        [_presenter dismissViewControllerAnimated:YES completion:^{
            _presenter = nil;
        }];
    } else {
        [_presenter dismissModalViewControllerAnimated:YES];
        _presenter = nil;
    }
}

- (void)facebookViewControllerDoneWasPressed:(id)sender
{
    FBFriendPickerViewController *fpc = (FBFriendPickerViewController *)sender;
    _fbFriends = [[NSMutableArray alloc] initWithCapacity:[fpc.selection count]];
    for (id<FBGraphUserExtraFields> user in fpc.selection) {
#ifdef DEBUG
        NSLog(@"Friend selected: %@", user.name);
#endif
        [_fbFriends addObject:user.id];
    }
    if ([_presenter respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        [_presenter dismissViewControllerAnimated:YES completion:^{
            [self showActualDialog];
            _presenter = nil;
        }];
    } else {
        [_presenter dismissModalViewControllerAnimated:YES];
        [self showActualDialog];
        _presenter = nil;
    }
}

- (void)showActualDialog {
    if ([_fbFriends count] == 0) {
        return;
    }
    
    NSString *friendString = [_fbFriends componentsJoinedByString:@","];
#ifdef DEBUG
    NSLog(@"Users to send to: %@", friendString);
#endif
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   _message,@"message",
                                   NSLocalizedString(@"Check this app out!",@"Facebook request notification text"), @"notification_text",
                                   nil];
    if (friendString) {
        [params setObject:friendString forKey:@"to"];
    }
    
    [_facebookUtil.facebook dialog:@"apprequests"
                         andParams:params
                       andDelegate:self];
}

- (void)dialog:(FBDialog *)dialog didFailWithError:(NSError*)error {
#ifdef DEBUG
    NSLog(@"FB share dialog failed with error: %@", error);
#endif
	if ([error code] == 190) {
		// Invalid token - force login
		[_facebookUtil logout];
		[_facebookUtil login:YES andThen:nil];
	} else {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
														message:[NSString stringWithFormat:@"%@.",[error localizedDescription]] 
													   delegate:nil
											  cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
											  otherButtonTitles:nil];
		[alert show];
	}
}

- (void)dialogDidComplete:(FBDialog *)dialog {
    if ([_facebookUtil.delegate respondsToSelector:@selector(sharedWithFriends)])
        [_facebookUtil.delegate sharedWithFriends];
}

- (void)dealloc
{
    _friendPickerController.delegate = nil;
}

@end
