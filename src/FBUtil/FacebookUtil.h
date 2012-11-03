//
//  FacebookUtil.h
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011-2012 Catloaf Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FacebookSDK.h"

@class FacebookUtil;
@class Facebook;

@protocol FacebookUtilDelegate <NSObject>
@optional
// Notified upon login/logout 
- (void)facebookLoggedIn:(NSString *)fullName;
- (void)facebookLoggedOut;

// Called upon completion of first authentication through dialog or app
- (void)facebookAuthenticated;

// Called upon successful completion of the dialogs
- (void)publishedToFeed;
- (void)sharedWithFriends;

// Implement these methods to show a HUD to the user while data is being fetched
- (void)startedFetchingFromFacebook:(FacebookUtil *)fb;
- (void)endedFetchingFromFacebook:(FacebookUtil *)fb;

@end

///// Notifications that get posted for FB status changes (alternative to delegate methods)
#define kFBUtilLoggedInNotification     @"FacebookUtilLoggedInNotification"
#define kFBUtilLoggedOutNotification    @"FacebookUtilLoggedOutNotification"

extern NSString *const FBSessionStateChangedNotification;

@interface FacebookUtil : NSObject

@property (nonatomic,readonly) BOOL loggedIn, publishTimeline;
@property (nonatomic,readonly) NSString *fullName, *userID;
@property (nonatomic,readonly) id<FacebookUtilDelegate> delegate;
@property (nonatomic,readonly) Facebook *facebook;
@property (nonatomic,copy) NSString *appName;

+ (BOOL)openPage:(unsigned long long)uid;

- (id)initWithAppID:(NSString *)appID 
       schemeSuffix:(NSString *)suffix
       appNamespace:(NSString *)ns
          fetchUser:(BOOL)fetch
           delegate:(id<FacebookUtilDelegate>)delegate;

// Returns the target_url passed from FB if available, or nil
- (NSString *)getTargetURL:(NSURL *)url;
- (BOOL)handleOpenURL:(NSURL *)url;

- (BOOL)login:(BOOL)doAuthorize andThen:(void (^)(void))handler;
- (void)logout;

- (BOOL)isSessionValid;
// Did we use the native iOS 6 Facebook login from the system?
- (BOOL)isNativeSession;

- (void)handleDidBecomeActive;

// Open Graph actions
- (void)publishAction:(NSString *)action withObject:(NSString *)object objectURL:(NSString *)url;
- (void)publishLike:(NSString *)url andThen:(void (^)(NSString *likeID))completion;
- (void)publishUnlike:(NSString *)likeID;

- (void)fetchAchievementsAndThen:(void (^)(NSSet *achievements))handler;
// Returns YES if the achievement was already submitted
- (BOOL)publishAchievement:(NSString *)achievement;
- (void)publishScore:(NSUInteger)score;

// Get a square FBProfilePictureView for the logged-in user
- (UIView *)profilePictureViewOfSize:(CGFloat)side;

// Common dialogs - handle authentification automatically when needed

// Publish a story on the users's feed
- (void)publishToFeedWithCaption:(NSString *)caption 
                     description:(NSString *)desc // May include HTML
                 textDescription:(NSString *)text
                            name:(NSString *)name
                      properties:(NSDictionary *)props
                          appURL:(NSString *)appURL
                       imagePath:(NSString *)imgPath
                        imageURL:(NSString *)img
                       imageLink:(NSString *)imgURL
                            from:(UIViewController *)vc;

// Share the app with the Facebook friends of the logged in user (app request)
- (void)shareAppWithFriends:(NSString *)message from:(UIViewController *)vc;

@end
