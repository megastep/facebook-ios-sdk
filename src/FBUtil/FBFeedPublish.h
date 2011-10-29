//
//  FBFeedPublish.h
//  Hold data for the FB dialog to publish a feed story
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FacebookUtil.h"

@interface FBFeedPublish : NSObject <FacebookUtilDialog, FBDialogDelegate> {
    FacebookUtil *_facebookUtil;
    NSDictionary *_properties;
    NSString *_caption, *_description, *_name, *_appURL, *_imgURL;
}

- (id)initWithFacebookUtil:(FacebookUtil *)fb
                   caption:(NSString *)caption 
               description:(NSString *)desc
                      name:(NSString *)name
                properties:(NSDictionary *)props
                    appURL:(NSString *)appURL
                  imageURL:(NSString *)img;

@end
