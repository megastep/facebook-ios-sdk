//
//  FacebookUtil.m
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011-2012 Catloaf Software, LLC. All rights reserved.
//

#import "Facebook.h"
#import "FacebookUtil.h"
#import "FBShareApp.h"
#import "FBFeedPublish.h"

NSString *const FBSessionStateChangedNotification = @"com.catloafsoft:FBSessionStateChangedNotification";


@interface FacebookUtil ()
- (NSDictionary*)parseURLParams:(NSString *)query;
@end

@implementation FacebookUtil
{
    Facebook *_facebook;
    BOOL _loggedIn, _fetchUserInfo, _fromDialog;
    NSString *_namespace;
    void (^_afterLogin)(void);
}

@synthesize loggedIn = _loggedIn, appName = _appName, facebook = _facebook,
    delegate = _delegate, fullName = _fullname, userID = _userID;

+ (void)initialize {
	if (self == [FacebookUtil class]) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"facebook_timeline":@(YES)}];
    }
}

- (void)sessionStateChanged:(FBSession *)session
                      state:(FBSessionState) state
                      error:(NSError *)error
{
    switch (state) {
        case FBSessionStateOpen:
            if (!error) {
                // We have a valid session
                // Initiate a Facebook instance
                _facebook = [[Facebook alloc] initWithAppId:FBSession.activeSession.appID
                                                andDelegate:nil];
                
                // Store the Facebook session information
                _facebook.accessToken = FBSession.activeSession.accessToken;
                _facebook.expirationDate = FBSession.activeSession.expirationDate;
                
                _loggedIn = YES;
                
                if (_fetchUserInfo) {
                    [[FBRequest requestForMe] startWithCompletionHandler:
                     ^(FBRequestConnection *connection,
                       NSDictionary<FBGraphUser> *user,
                       NSError *error) {
                         if (!error) {
                             [_fullname release];
                             _fullname = [user.name copy];
                             [_userID release];
                             _userID = [user.id copy];
                             if ([_delegate respondsToSelector:@selector(facebookLoggedIn:)])
                                 [_delegate facebookLoggedIn:_fullname];
                             if (_fromDialog && [_delegate respondsToSelector:@selector(facebookAuthenticated)]) {
                                 [_delegate facebookAuthenticated];
                             }
                             [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedInNotification
                                                                                 object:self];
                             if (_afterLogin) {
                                 _afterLogin();
                             }
                         }
                     }];
                } else {
                    if ([_delegate respondsToSelector:@selector(facebookLoggedIn:)])
                        [_delegate facebookLoggedIn:nil];
                    if (_fromDialog && [_delegate respondsToSelector:@selector(facebookAuthenticated)]) {
                        [_delegate facebookAuthenticated];
                    }
                    [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedInNotification
                                                                        object:self];
                    if (_afterLogin) {
                        _afterLogin();
                    }
                }
            }
            break;
        case FBSessionStateClosed:
        case FBSessionStateClosedLoginFailed:
            [FBSession.activeSession closeAndClearTokenInformation];
            [_fullname release];
            _fullname = nil;
            [_userID release];
            _userID = nil;
            _loggedIn = NO;
            [_facebook release];
            _facebook = nil;
            if ([_delegate respondsToSelector:@selector(facebookLoggedOut)]) {
                [_delegate facebookLoggedOut];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedOutNotification
                                                                object:self];
            break;
        default:
            break;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FBSessionStateChangedNotification
                                                        object:session];
    
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"FB Error"
                                  message:error.localizedDescription
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
    }
}

- (id)initWithAppID:(NSString *)appID
       schemeSuffix:(NSString *)suffix
       appNamespace:(NSString *)ns
          fetchUser:(BOOL)fetch
           delegate:(id<FacebookUtilDelegate>)delegate
{
    self = [super init];
    if (self) {
        _fetchUserInfo = fetch;
        _namespace = [ns copy];
        _delegate = delegate;
        
        [FBSession setDefaultAppID:appID];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        BOOL facebook_reset = [defaults boolForKey:@"facebook_reset"];
        if (facebook_reset) {
            [FBSession.activeSession closeAndClearTokenInformation];
            [defaults setBool:NO forKey:@"facebook_reset"]; // Don't do it on the next start
            [defaults synchronize];
        } else {
            [self login:NO andThen:nil];
        }
    }
    return self;
}

- (void)dealloc {
    [_fullname release];
    [_userID release];
    [_namespace release];
    [super dealloc];
}

- (BOOL) publishTimeline {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"facebook_timeline"];
}

/**
 * Open a Facebook page in the FB app or Safari.
 * @return boolean - whether the page was successfully opened.
 */

+ (BOOL)openPage:(unsigned long long)uid {
	NSString *fburl = [NSString stringWithFormat:@"fb://page/%lld",uid];
	if ([[UIApplication sharedApplication] openURL:[NSURL URLWithString:fburl]] == NO) {
		NSString *url = [NSString stringWithFormat:@"http://touch.facebook.com/profile.php?id=%lld",uid];
		return [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
	}
	return NO;
}

- (void)handleDidBecomeActive {
    [FBSession.activeSession handleDidBecomeActive];
}

- (BOOL)login:(BOOL)doAuthorize andThen:(void (^)(void))handler {
    _afterLogin = [handler copy];
    return [FBSession openActiveSessionWithReadPermissions:nil
                                              allowLoginUI:doAuthorize
                                         completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                             [self sessionStateChanged:session
                                                                 state:status
                                                                 error:error];
                                         }];
}

- (void)logout {
    [FBSession.activeSession closeAndClearTokenInformation];
}

- (BOOL)isSessionValid {
    return FBSession.activeSession.isOpen;
}

/**
 * A function for parsing URL parameters.
 */
- (NSDictionary*)parseURLParams:(NSString *)query {
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[[NSMutableDictionary alloc] init]
                                   autorelease];
    for (NSString *pair in pairs) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        NSString *val = [[kv objectAtIndex:1]
                         stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [params setObject:val forKey:[kv objectAtIndex:0]];
    }
    return params;
}

- (NSString *)getTargetURL:(NSURL *)url {
    NSString *query = [url fragment];
    NSDictionary *params = [self parseURLParams:query];
    // Check if target URL exists
    return [params valueForKey:@"target_url"];
}

- (BOOL)handleOpenURL:(NSURL *)url {
    return [FBSession.activeSession handleOpenURL:url];
}

- (void)doWithPermission:(NSString *)permission toDo:(void (^)(void))handler {
    if (FBSession.activeSession.isOpen) {
        [FBSession.activeSession reauthorizeWithPublishPermissions:@[permission]
                                                   defaultAudience:FBSessionDefaultAudienceEveryone
                                                 completionHandler:^(FBSession *session, NSError *error) {
                                                     handler();
                                                 }];
    } else {
        _afterLogin = [handler copy];
        [FBSession openActiveSessionWithPublishPermissions:@[permission]
                                           defaultAudience:FBSessionDefaultAudienceEveryone
                                              allowLoginUI:YES
                                         completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                             [self sessionStateChanged:session
                                                                 state:status
                                                                 error:error];
                                         }];
    }
}

#pragma mark - Utility dialog methods

- (void)publishToFeedWithCaption:(NSString *)caption 
                     description:(NSString *)desc
                 textDescription:(NSString *)text
                            name:(NSString *)name
                      properties:(NSDictionary *)props
                          appURL:(NSString *)appURL
                       imagePath:(NSString *)imgPath
                        imageURL:(NSString *)img
                       imageLink:(NSString *)imgURL
                            from:(UIViewController *)vc
{
    [self doWithPermission:@"publish_actions" toDo:^{
        FBFeedPublish *dialog = [[FBFeedPublish alloc] initWithFacebookUtil:self
                                                      caption:caption
                                                  description:desc
                                              textDescription:text
                                                         name:name
                                                   properties:props
                                                       appURL:appURL
                                                    imagePath:imgPath
                                                     imageURL:img
                                                    imageLink:imgURL];
        [dialog showDialogFrom:vc];
        [dialog autorelease];
    }];
}


- (void)shareAppWithFriends:(NSString *)message from:(UIViewController *)vc {
    // FIXME: Do the reauthorize here too?
    FBShareApp *dialog = [[FBShareApp alloc] initWithFacebookUtil:self message:message];
    [dialog presentFromViewController:vc];
    [dialog autorelease];
}

- (void)publishAction:(NSString *)action withObject:(NSString *)object objectURL:(NSString *)url {
    if (!self.publishTimeline)
        return;
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:[NSString stringWithFormat:@"me/%@:%@",_namespace,action]
                                              parameters:@{object:url}
                                              HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error publishing action: %@", error);
            }
        }];
    }];
}

- (void)publishLike:(NSString *)url andThen:(void (^)(void))completion {
    if (!self.publishTimeline) {
        if (completion)
            completion();
        return;
    }
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:@"me/og.likes"
                                              parameters:@{@"object":url}
                                              HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error publishing like: %@", error);
            }
            if (completion)
                completion();
        }];
    }];
}

// Submit the URL to a registered achievement page
- (void)publishAchievement:(NSString *)achievementURL {
    if (!self.publishTimeline)
        return;
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:@"me/achievements"
                                              parameters:@{@"achievement":achievementURL}
                                              HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSDictionary *errDict = [[error userInfo] objectForKey:@"error"];
                if ([[errDict objectForKey:@"code"] integerValue] != 3501) { // Duplicate achievement error code from FB
                    NSLog(@"Error publishing achievement: %@", error);
                }
            }
        }];
    }];
}

- (void)publishScore:(NSUInteger)score {
    if (self.publishTimeline)
        return;
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:@"me/scores"
                                              parameters:@{@"score":[NSString stringWithFormat:@"%d",score]}
                                              HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error publishing score: %@", error);
            }
        }];
    }];
}

@end
