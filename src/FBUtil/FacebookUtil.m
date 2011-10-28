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

@implementation FacebookUtil

@synthesize loggedIn = _loggedIn, facebook = _facebook, appName = _appName, delegate = _delegate, apiKey = _apiKey;

- (id)initWithAppID:(NSString *)appID
             apiKey:(NSString *)key
        permissions:(NSArray *)perms 
          fetchUser:(BOOL)fetch
           delegate:(id<FacebookUtilDelegate>)delegate
{
    self = [super init];
    if (self) {
        _permissions = [perms retain];
        _apiKey = [key copy];
        _fetchUserInfo = fetch;
        _delegate = delegate;
		_facebook = [[Facebook alloc] initWithAppId:appID andDelegate:self];
        [self login:NO];
    }
    return self;
}

- (void)dealloc {
    [_permissions release];
    [_apiKey release];
    [_fullname release];
    [_facebook release];
    [_dialog release];
    [super dealloc];
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
    }
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
                          appURL:(NSString *)appURL
                        imageURL:(NSString *)img
{
    [_dialog release];
    _dialog = [[FBFeedPublish alloc] initWithFacebookUtil:self
                                                  caption:caption
                                              description:desc
                                                     name:name
                                                   appURL:appURL
                                                 imageURL:img];
    [self showDialogOrAuthorize];
}


- (void)shareAppWithFriends:(NSString *)message {
    [_dialog release];
    _dialog = [[FBShareApp alloc] initWithFacebookUtil:self message:message];
    [self showDialogOrAuthorize];
}


#pragma mark - FBSession delegate methods

- (void)fbDidLogin {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:_facebook.accessToken forKey:@"FBAccessToken"];
	[defaults setObject:_facebook.expirationDate forKey:@"FBExpDate"];
	_loggedIn = YES;
    [defaults synchronize];
    if (_fetchUserInfo) {
        [_facebook requestWithGraphPath:@"me" 
                              andParams:[NSMutableDictionary dictionaryWithObjectsAndKeys:@"name",@"fields",nil]
                            andDelegate:self];
    }
    if (_dialog) {
        [_dialog showDialog];
    }
#ifdef DEBUG
	NSLog(@"Facebook logged in.");
#endif
}

- (void)fbDidNotLogin:(BOOL)cancelled {
    // TODO?
#ifdef DEBUG
    NSLog(@"FB did not login. Cancel = %d", cancelled);
#endif
}

- (void)fbDidLogout {
    [_fullname release];
    _fullname = nil;
    _userID = 0LL;
	_loggedIn = NO;
	[self forgetAccessToken];
#ifdef DEBUG
	NSLog(@"Facebook logged out.");
#endif
}

#pragma mark - FBRequest delegate methods

- (void)request:(FBRequest *)request didLoad:(id)result {
    id uid = [result objectForKey:@"id"];
    
    if (uid) { // Results from the "me" query
        _userID = [uid longLongValue];
        _fullname = [[result objectForKey:@"name"] retain];
    }
}

@end
