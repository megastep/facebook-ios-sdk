//
//  FacebookUtil.h
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FBConnect.h"

@class FacebookUtil;

@protocol FacebookUtilDelegate <NSObject>
@optional
// Notified upon login/logout 
- (void)facebookLoggedIn:(NSString *)fullName;
- (void)facebookLoggedOut;

// Called upon successful completion of the dialogs
- (void)publishedToFeed;
- (void)sharedWithFriends;

// Implement these methods to show a HUD to the user while data is being fetched
- (void)startedFetchingFromFacebook:(FacebookUtil *)fb;
- (void)endedFetchingFromFacebook:(FacebookUtil *)fb;

@end

@protocol FacebookUtilDialog <NSObject>
@required
- (void)showDialog;
@end

@interface FacebookUtil : NSObject 
        <FBSessionDelegate, FBRequestDelegate>
{
    Facebook *_facebook;
    NSString *_apiKey;
    NSArray *_permissions;
    NSString *_fullname;
    NSString *_appName;
    long long _userID;
    BOOL _loggedIn, _fetchUserInfo;
    id<FacebookUtilDelegate> _delegate;
    id<FacebookUtilDialog> _dialog;
}

@property (nonatomic,readonly) BOOL loggedIn;
@property (nonatomic,readonly) NSString *fullName;
@property (nonatomic,readonly) long long userID;
@property (nonatomic,readonly) Facebook *facebook;
@property (nonatomic,readonly) id<FacebookUtilDelegate> delegate;
@property (nonatomic,copy) NSString *appName, *apiKey;

+ (BOOL)openPage:(unsigned long long)uid;

- (id)initWithAppID:(NSString *)appID 
             apiKey:(NSString *)key
        permissions:(NSArray *)perms
          fetchUser:(BOOL)fetch
           delegate:(id<FacebookUtilDelegate>)delegate;

- (BOOL)handleOpenURL:(NSURL *)url;

- (void)forgetAccessToken;
- (void)login:(BOOL)doAuthorize;
- (void)logout;

- (BOOL)isSessionValid;

// Common dialogs - handle authentification automatically when needed

// Publish a story on the users's feed
- (void)publishToFeedWithCaption:(NSString *)caption 
                     description:(NSString *)desc
                            name:(NSString *)name
                      properties:(NSDictionary *)props
                          appURL:(NSString *)appURL
                        imageURL:(NSString *)img
                       imageLink:(NSString *)imgURL;

// Share the app with the Facebook friends of the logged in user (app request)
- (void)shareAppWithFriends:(NSString *)message;

// Publish a game score action (need publish_action permission)
- (void)publishScore:(NSUInteger)score;

@end
