//
//  FBShareApp.m
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import "FBShareApp.h"

@implementation FBShareApp

- (id)initWithFacebookUtil:(FacebookUtil *)fb message:(NSString *)msg {
    self = [super init];
    if (self) {
        _facebookUtil = fb;
        _message = [msg copy];
    }
    return self;
}

- (void)showActualDialog {
    NSString *friendString = [_fbFriends componentsJoinedByString:@","];
#ifdef DEBUG
    NSLog(@"Users to recommend: %@", friendString);
#endif
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   _message,@"message",
                                   NSLocalizedString(@"Check this app out!",@"Facebook request notification text"), @"notification_text",
                                   nil];
    if (friendString) {
        [params setObject:friendString forKey:@"suggestions"];
    }
    
    [_facebookUtil.facebook dialog:@"apprequests"
                         andParams:params
                       andDelegate:self];
}

- (void)showDialog {
    if (_fbFriends == nil) {
        if ([_facebookUtil.delegate respondsToSelector:@selector(startedFetchingFromFacebook:)]) {
            [_facebookUtil.delegate startedFetchingFromFacebook:_facebookUtil];
        }
        // Fetch the list of friends who are not using the app and present the dialog
        NSString *q = @"{\"users\":\"SELECT uid FROM user WHERE is_app_user=1 AND uid IN (SELECT uid2 FROM friend WHERE uid1=me())\","
                        "\"all\":\"SELECT uid2 FROM friend WHERE uid1=me()\"}";
        [_facebookUtil.facebook requestWithGraphPath:[NSString stringWithFormat:@"fql?q=%@",[q stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]
                                         andDelegate:self];
    } else {
        [self showActualDialog];
    }
}

- (void)request:(FBRequest *)request didFailWithError:(NSError *)error
{
    if ([_facebookUtil.delegate respondsToSelector:@selector(endedFetchingFromFacebook:)]) {
        [_facebookUtil.delegate endedFetchingFromFacebook:_facebookUtil];
    }
}

- (void)request:(FBRequest *)request didLoad:(id)result
{
#ifdef DEBUG
//    NSLog(@"FBShareApp received FB result: %@", result);
#endif
    // Parse results and create list of friends who are not using the app
    NSArray *data = [result objectForKey:@"data"];
    NSAssert([data count] == 2, @"Incorrect number of data returned: %d", [data count]);
    
    NSMutableSet *users = nil;
    NSDictionary *all = nil;
    
    for(NSDictionary *resultSet in data) {
        NSString *name = [resultSet objectForKey:@"name"];
        NSDictionary *result = [resultSet objectForKey:@"fql_result_set"];
        if ([name isEqualToString:@"users"]) {
            users = [NSMutableSet setWithCapacity:[result count]];
            for(NSDictionary *user in result) {
                [users addObject:[user objectForKey:@"uid"]];
            }
        } else if ([name isEqualToString:@"all"]) {
            all = result;
        }
    }
    
    [_fbFriends release];
    _fbFriends = [[NSMutableArray alloc] initWithCapacity:[all count] - [users count]];
    
    if ([users count] == 0) {
        for(NSDictionary *user in all) {
            [_fbFriends addObject:[user objectForKey:@"uid2"]];
        }        
    } else {
        for(NSDictionary *user in all) {
            NSNumber *uid = [user objectForKey:@"uid2"];
            if (![users containsObject:uid]) {
                [_fbFriends addObject:uid];                
            }
        }
    }
    if ([_facebookUtil.delegate respondsToSelector:@selector(endedFetchingFromFacebook:)]) {
        [_facebookUtil.delegate endedFetchingFromFacebook:_facebookUtil];
    }

    [self showActualDialog];
}

- (void)dialog:(FBDialog *)dialog didFailWithError:(NSError*)error {
#ifdef DEBUG
    NSLog(@"FB share dialog failed with error: %@", error);
#endif
	if ([error code] == 190) {
		// Invalid token - force login
		[_facebookUtil forgetAccessToken];
		[_facebookUtil login:YES];
	} else {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
														message:[NSString stringWithFormat:@"%@.",[error localizedDescription]] 
													   delegate:nil
											  cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
											  otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

- (void)dialogDidComplete:(FBDialog *)dialog {
    if ([_facebookUtil.delegate respondsToSelector:@selector(sharedWithFriends)])
        [_facebookUtil.delegate sharedWithFriends];
}

- (void)dealloc {
    [_message release];
    [_fbFriends release];
    [super dealloc];
}

@end
