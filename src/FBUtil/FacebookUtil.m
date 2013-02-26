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
- (void)processAchievementData:(id)result;
@end

@implementation FacebookUtil
{
    Facebook *_facebook;
    BOOL _loggedIn, _fetchUserInfo, _fromDialog;
    NSMutableSet *_achievements;
    FBShareApp *_shareDialog;
    FBFeedPublish *_feedDialog;
    NSString *_namespace, *_appID, *_appSuffix;
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
                _facebook.accessToken = FBSession.activeSession.accessTokenData.accessToken;
                _facebook.expirationDate = FBSession.activeSession.accessTokenData.expirationDate;
                
                _loggedIn = YES;
                
                if (_fetchUserInfo) {
                    [[FBRequest requestForMe] startWithCompletionHandler:
                     ^(FBRequestConnection *connection,
                       NSDictionary<FBGraphUser> *user,
                       NSError *error) {
                         if (!error) {
                             _fullname = [user.name copy];
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
            _fullname = nil;
            _userID = nil;
            _loggedIn = NO;
            _facebook = nil;
            if (state != FBSessionStateClosedLoginFailed) { // No need to notify if we simply failed to log in
                if ([_delegate respondsToSelector:@selector(facebookLoggedOut)]) {
                    [_delegate facebookLoggedOut];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedOutNotification
                                                                    object:self];
            }
            break;
        default:
            break;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FBSessionStateChangedNotification
                                                        object:session];
    
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Facebook Error"
                                  message:error.localizedDescription
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
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
        _appID = [appID copy];
        _appSuffix = [suffix copy];
        _delegate = delegate;
        _achievements = [[NSMutableSet alloc] init];
        [self login:NO andThen:nil];
    }
    return self;
}

- (BOOL) publishTimeline {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"facebook_timeline"];
}

/**
 * Open a Facebook page in the FB app or Safari.
 * @return boolean - whether the page was successfully opened.
 */

+ (BOOL)openPage:(unsigned long long)uid {
	NSString *fburl = [NSString stringWithFormat:@"fb://profile/%lld",uid];
	if ([[UIApplication sharedApplication] openURL:[NSURL URLWithString:fburl]] == NO) {
        // We can redirect iPad users to the regular site
        NSString *site = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) ? @"touch" : @"www";
		NSString *url = [NSString stringWithFormat:@"http://%@.facebook.com/profile.php?id=%lld",site,uid];
		return [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
	}
	return NO;
}

- (void)handleDidBecomeActive {
    [FBSession.activeSession handleDidBecomeActive];
}

- (BOOL)login:(BOOL)doAuthorize withPermissions:(NSArray *)perms andThen:(void (^)(void))handler {
    _afterLogin = [handler copy];
    FBSession *session = [[FBSession alloc] initWithAppID:_appID
                                              permissions:perms
                                          defaultAudience:FBSessionDefaultAudienceEveryone
                                          urlSchemeSuffix:_appSuffix
                                       tokenCacheStrategy:nil];
    [FBSession setActiveSession:session];

    // Check whether we have a token for an old app ID - force reset if the ID changed!
    if (session.state == FBSessionStateCreatedTokenLoaded && ![session.appID isEqualToString:_appID]) {
        [session closeAndClearTokenInformation];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    BOOL facebook_reset = [defaults boolForKey:@"facebook_reset"];
    if (facebook_reset) {
        [session closeAndClearTokenInformation];
        [defaults setBool:NO forKey:@"facebook_reset"]; // Don't do it on the next start
        [defaults synchronize];
    } else if (doAuthorize || (session.state == FBSessionStateCreatedTokenLoaded)) {
        [session openWithBehavior:FBSessionLoginBehaviorUseSystemAccountIfPresent
                completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
            [self sessionStateChanged:session
                                state:status
                                error:error];
        }];        
    }
    return session.isOpen;
}

- (BOOL)login:(BOOL)doAuthorize andThen:(void (^)(void))handler {
    return [self login:doAuthorize withPermissions:nil andThen:handler];
}

- (void)logout {
    [FBSession.activeSession closeAndClearTokenInformation];
}

- (BOOL)isSessionValid {
    return FBSession.activeSession.isOpen;
}

- (BOOL)isNativeSession {
    return FBSession.activeSession.accessTokenData.loginType == FBSessionLoginTypeSystemAccount;
}

- (UIView *)profilePictureViewOfSize:(CGFloat)side {
    FBProfilePictureView *profileView = [[FBProfilePictureView alloc] initWithProfileID:self.userID
                                                                        pictureCropping:FBProfilePictureCroppingSquare];
    profileView.bounds = CGRectMake(0.0f, 0.0f, side, side);
    return profileView;
}

/**
 * A function for parsing URL parameters.
 */
- (NSDictionary*)parseURLParams:(NSString *)query {
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
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
#ifdef DEBUG
        NSLog(@"Available permissions: %@", FBSession.activeSession.permissions);
#endif
        if ([FBSession.activeSession.permissions containsObject:permission]) {
            handler();
        } else {
#ifdef DEBUG
            NSLog(@"Requesting new permission: %@", permission);
#endif
            [FBSession.activeSession requestNewPublishPermissions:@[permission]
                                                  defaultAudience:FBSessionDefaultAudienceEveryone
                                                completionHandler:^(FBSession *session, NSError *error) {
                                                    handler();
                                                }];
        }
    } else {
        [self login:YES withPermissions:[NSArray arrayWithObject:permission] andThen:^{
            [self doWithPermission:permission toDo:handler];
        }];
    }
}

#pragma mark - Utility dialog methods

- (void)publishToFeedWithCaption:(NSString *)caption 
                     description:(NSString *)desc
                 textDescription:(NSString *)text
                            name:(NSString *)name
                      properties:(NSDictionary *)props
                expandProperties:(BOOL)expand
                          appURL:(NSString *)appURL
                       imagePath:(NSString *)imgPath
                        imageURL:(NSString *)img
                       imageLink:(NSString *)imgURL
                            from:(UIViewController *)vc
{
    [self doWithPermission:@"publish_actions" toDo:^{
        _feedDialog = [[FBFeedPublish alloc] initWithFacebookUtil:self
                                                          caption:caption
                                                      description:desc
                                                  textDescription:text
                                                             name:name
                                                       properties:props
                                                           appURL:appURL
                                                        imagePath:imgPath
                                                         imageURL:img
                                                        imageLink:imgURL];
        _feedDialog.expandProperties = expand;
        [_feedDialog showDialogFrom:vc];
    }];
}


- (void)shareAppWithFriends:(NSString *)message from:(UIViewController *)vc {
    _shareDialog = [[FBShareApp alloc] initWithFacebookUtil:self message:message];
    [_shareDialog presentFromViewController:vc];
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

- (void)publishLike:(NSString *)url andThen:(void (^)(NSString *likeID))completion {
    if (!self.publishTimeline) {
        if (completion)
            completion(nil);
        return;
    }
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:@"me/og.likes"
                                              parameters:@{@"object":url}
                                              HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSDictionary *errDict = [[error userInfo] objectForKey:@"error"];
                if ([[errDict objectForKey:@"code"] integerValue] != 3501) { // Duplicate error code from FB
                    NSLog(@"Error publishing like: %@", error);
                }
            }
            if (completion) {
                completion([result objectForKey:@"id"]);
            }
        }];
    }];
}

- (void)publishUnlike:(NSString *)likeID {
    if (!self.publishTimeline)
        return;
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:likeID
                                              parameters:nil
                                              HTTPMethod:@"DELETE"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error deleting like: %@", error);
            }
        }];
    }];
}

// Submit the URL to a registered achievement page
- (BOOL)publishAchievement:(NSString *)achievementURL {
    if (!self.publishTimeline)
        return NO;
    
    if ([_achievements containsObject:achievementURL])
        return YES;
    
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:@"me/achievements"
                                              parameters:@{@"achievement":achievementURL}
                                              HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSDictionary *errDict = [[error userInfo] objectForKey:@"error"];
                if ([[errDict objectForKey:@"code"] integerValue] != 3501) { // Duplicate achievement error code from FB
                    NSLog(@"Error publishing achievement: %@", error);
                } else {
                    [_achievements addObject:achievementURL];
                }
            } else {
                [_achievements addObject:achievementURL];
            }
        }];
    }];
    return NO;
}

- (void)removeAchievement:(NSString *)achievementURL {
    if (![_achievements containsObject:achievementURL])
        return;
    
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:@"me/achievements"
                                              parameters:@{@"achievement":achievementURL}
                                              HTTPMethod:@"DELETE"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSDictionary *errDict = [[error userInfo] objectForKey:@"error"];
                if ([[errDict objectForKey:@"code"] integerValue] != 3404) { // No such achievement for user error code from FB
                    NSLog(@"Error deleting achievement: %@", error);
                } else {
                    [_achievements removeObject:achievementURL];
                }
            } else {
                [_achievements removeObject:achievementURL];
            }
        }];
    }];

}

- (void)removeAllAchievements {
    if ([_achievements count] == 0)
        return;
 
    [self doWithPermission:@"publish_actions" toDo:^{
        for (NSString *achievementURL in _achievements) {
            FBRequest *req = [FBRequest requestWithGraphPath:@"me/achievements"
                                                  parameters:@{@"achievement":achievementURL}
                                                  HTTPMethod:@"DELETE"];
            [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                if (error) {
                    NSDictionary *errDict = [[error userInfo] objectForKey:@"error"];
                    if ([[errDict objectForKey:@"code"] integerValue] != 3404) { // No such achievement for user error code from FB
                        NSLog(@"Error deleting achievement: %@", error);
                    }
                 }
            }];
        }
        [_achievements removeAllObjects];
    }];

}

- (void)processAchievementData:(id)result {

    for (NSDictionary *dict in result[@"data"]) {
        [_achievements addObject:dict[@"achievement"][@"url"]];
    }
    NSDictionary *paging = result[@"paging"];
    if (paging[@"next"]) { // need to send another request
        FBRequest *request = [[FBRequest alloc] initWithSession:nil
                                                      graphPath:nil];
        FBRequestConnection *connection = [[FBRequestConnection alloc] init];
        [connection addRequest:request completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error processing paging: %@", error);
            } else {
                [self processAchievementData:result];
            }
        }];
        NSURL *url = [NSURL URLWithString:paging[@"next"]];
        connection.urlRequest = [NSMutableURLRequest requestWithURL:url];
        [connection start];
    }
}

// Retrieve the list of achievements earned from Facebook
- (void)fetchAchievementsAndThen:(void (^)(NSSet *achievements))handler
{
    // We probably don't need to request extended permissions just to get the list of earned achievements
    FBRequest *req = [FBRequest requestWithGraphPath:@"me/achievements"
                                          parameters:nil
                                          HTTPMethod:@"GET"];
    [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (error) {
            NSLog(@"Failed to retrieve FB achievements: %@", error);
        } else {
            [_achievements removeAllObjects];
            [self processAchievementData:result];
            if (handler) {
                handler(_achievements);
            }
        }
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
