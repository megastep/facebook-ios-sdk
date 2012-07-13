//
//  FacebookUtil.m
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import "FacebookUtil.h"
#import "FBShareApp.h"
#import "FBFeedPublish.h"

@interface FacebookUtil ()
- (NSDictionary*)parseURLParams:(NSString *)query;
@end

@implementation FacebookUtil
{
    NSArray *_permissions;
    BOOL _loggedIn, _fetchUserInfo, _fromDialog;
    NSString *_namespace;
    id<FacebookUtilDialog> _dialog;
}

@synthesize loggedIn = _loggedIn, facebook = _facebook, appName = _appName,
    delegate = _delegate, fullName = _fullname, userID = _userID;

+ (void)initialize {
	if (self == [FacebookUtil class]) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                                                            forKey:@"facebook_timeline"]];
    }
}

- (id)initWithAppID:(NSString *)appID
        permissions:(NSArray *)perms
       appNamespace:(NSString *)ns
          fetchUser:(BOOL)fetch
           delegate:(id<FacebookUtilDelegate>)delegate
{
    self = [super init];
    if (self) {
        _permissions = [perms retain];
        _fetchUserInfo = fetch;
        _namespace = [ns copy];
        _delegate = delegate;
		_facebook = [[Facebook alloc] initWithAppId:appID andDelegate:self];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        BOOL facebook_reset = [defaults boolForKey:@"facebook_reset"];
        if (facebook_reset) {
            [self forgetAccessToken];
            [defaults setBool:NO forKey:@"facebook_reset"]; // Don't do it on the next start
            [defaults synchronize];
        } else {
            [self login:NO];
        }
    }
    return self;
}

- (void)dealloc {
    [_permissions release];
    [_fullname release];
    [_facebook release];
    [_dialog release];
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

- (void)forgetAccessToken {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:@"FBAccessToken"];
	[defaults removeObjectForKey:@"FBExpDate"];
    [defaults synchronize];
}

- (void)login:(BOOL)doAuthorize {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];		
	_facebook.accessToken = [defaults stringForKey:@"FBAccessToken"];
	_facebook.expirationDate = (NSDate *) [defaults objectForKey:@"FBExpDate"];
	if ([_facebook isSessionValid] == NO) {
        if (doAuthorize)
            [_facebook authorize:_permissions];
	} else if (_fetchUserInfo) {
        _loggedIn = YES;
        [_facebook requestWithGraphPath:@"me" 
                              andParams:[NSMutableDictionary dictionaryWithObjectsAndKeys:@"name",@"fields",nil]
                            andDelegate:self];
    } else {
        _loggedIn = YES;
    }
    [_facebook extendAccessTokenIfNeeded];
    [_facebook enableFrictionlessRequests];
}

- (void)logout {
    [_facebook logout];   
}

- (BOOL)isSessionValid {
    return [_facebook isSessionValid];
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
    return [_facebook handleOpenURL:url];
}

#pragma mark - Utility dialog methods

- (void)showDialogOrAuthorize {
	if ([_facebook isSessionValid] == NO) {
        [_facebook authorize:_permissions];
	} else {
        [_dialog showDialog];
    }
}

- (void)publishToFeedWithCaption:(NSString *)caption 
                     description:(NSString *)desc
                            name:(NSString *)name
                      properties:(NSDictionary *)props
                          appURL:(NSString *)appURL
                        imageURL:(NSString *)img
                       imageLink:(NSString *)imgURL
{
    [_dialog release];
    _dialog = [[FBFeedPublish alloc] initWithFacebookUtil:self
                                                  caption:caption
                                              description:desc
                                                     name:name
                                               properties:props
                                                   appURL:appURL
                                                 imageURL:img
                                                imageLink:imgURL];
    [self showDialogOrAuthorize];
}


- (void)shareAppWithFriends:(NSString *)message {
    [_dialog release];
    _dialog = [[FBShareApp alloc] initWithFacebookUtil:self message:message];
    [self showDialogOrAuthorize];
}

- (void)publishAction:(NSString *)action withObject:(NSString *)object objectURL:(NSString *)url {
    if (self.publishTimeline) {
        [_facebook requestWithGraphPath:[NSString stringWithFormat:@"me/%@:%@",_namespace,action]
                              andParams:[NSMutableDictionary dictionaryWithObject:url forKey:object]
                          andHttpMethod:@"POST"
                            andDelegate:self];
    }
}

- (void)publishLike:(NSString *)url {
    if (self.publishTimeline) {
        [_facebook requestWithGraphPath:@"me/og.likes"
                              andParams:[NSMutableDictionary dictionaryWithObject:url forKey:@"object"]
                          andHttpMethod:@"POST"
                            andDelegate:self];
    }
}

#pragma mark - FBSession delegate methods

- (void)fbDidLogin:(BOOL)fromDialog {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:_facebook.accessToken forKey:@"FBAccessToken"];
	[defaults setObject:_facebook.expirationDate forKey:@"FBExpDate"];
	_loggedIn = YES;
    _fromDialog = fromDialog;
    [defaults synchronize];
    if (_fetchUserInfo) {
        [_facebook requestWithGraphPath:@"me" 
                              andParams:[NSMutableDictionary dictionaryWithObjectsAndKeys:@"name",@"fields",nil]
                            andDelegate:self];
        // Notification is posted after we get the info
    } else {
        if ([_delegate respondsToSelector:@selector(facebookLoggedIn:)])
            [_delegate facebookLoggedIn:nil];
        if (_fromDialog && [_delegate respondsToSelector:@selector(facebookAuthenticated)]) {
            [_delegate facebookAuthenticated];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedInNotification
                                                            object:self];
    }
    
    if (_dialog) {
        [_dialog showDialog];
    }
#ifdef DEBUG
	NSLog(@"Facebook logged in.");
#endif
}

- (void)fbDidNotLogin:(BOOL)cancelled {
    // Make sure we are really not logged in
    [_fullname release];
    _fullname = nil;
    _userID = 0LL;
	_loggedIn = NO;
#ifdef DEBUG
    NSLog(@"FB did not login. Cancelled = %d", cancelled);
#endif
}

- (void)fbDidLogout {
    [_fullname release];
    _fullname = nil;
    _userID = 0LL;
	_loggedIn = NO;
	[self forgetAccessToken];
    if ([_delegate respondsToSelector:@selector(facebookLoggedOut)]) {
        [_delegate facebookLoggedOut];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedOutNotification
                                                        object:self];
#ifdef DEBUG
	NSLog(@"Facebook logged out.");
#endif
}

- (void)fbDidExtendToken:(NSString*)accessToken
               expiresAt:(NSDate*)expiresAt
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:accessToken forKey:@"FBAccessToken"];
	[defaults setObject:expiresAt forKey:@"FBExpDate"];
    [defaults synchronize];
}

- (void)fbSessionInvalidated
{
    [self fbDidLogout];
}

#pragma mark - FBRequest delegate methods

- (void)request:(FBRequest *)request didLoad:(id)result {
    id name = [result objectForKey:@"name"];
    id uid = [result objectForKey:@"id"];
    
    if (name && uid) { // Results from the "me" query
        _userID = [uid longLongValue];
        [_fullname release];
        _fullname = [name retain];
        if ([_delegate respondsToSelector:@selector(facebookLoggedIn:)]) {
            [_delegate facebookLoggedIn:_fullname];
        }
        if (_fromDialog && [_delegate respondsToSelector:@selector(facebookAuthenticated)]) {
            [_delegate facebookAuthenticated];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedInNotification
                                                            object:self];
    }
}

- (void)request:(FBRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"FB Request failed: %@ with error: %@", request, error);
}


@end
