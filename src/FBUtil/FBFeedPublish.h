//
//  FBFeedPublish.h
//  Hold data for the FB dialog to publish a feed story
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FacebookUtil.h"
#import "Facebook.h"

@interface FBFeedPublish : NSObject <FBDialogDelegate>

- (id)initWithFacebookUtil:(FacebookUtil *)fb
                   caption:(NSString *)caption 
               description:(NSString *)desc // May include HTML
           textDescription:(NSString *)txt
                      name:(NSString *)name
                properties:(NSDictionary *)props
                    appURL:(NSString *)appURL
                 imagePath:(NSString *)path
                  imageURL:(NSString *)img
                 imageLink:(NSString *)imgURL;

- (void)showDialogFrom:(UIViewController *)vc;

@end
