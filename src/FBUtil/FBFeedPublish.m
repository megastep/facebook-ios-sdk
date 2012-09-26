//
//  FBFeedPublish.m
//  Hold data for the FB dialog to publish a feed story
//
//  Created by Stéphane Peter on 10/26/11.
//
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import "FBFeedPublish.h"

@implementation FBFeedPublish

- (id)initWithFacebookUtil:(FacebookUtil *)fb
                   caption:(NSString *)caption 
               description:(NSString *)desc
                      name:(NSString *)name
                properties:(NSDictionary *)props
                    appURL:(NSString *)appURL
                  imageURL:(NSString *)img
                 imageLink:(NSString *)imgURL
{
    self = [super init];
    if (self) {
        _facebookUtil = fb;
        _caption = [caption copy];
        _description = [desc copy];
        _name = [name copy];
        _properties = [props retain];
        _appURL = [appURL copy];
        _imgURL = [img copy];
        _imgLink = [imgURL copy];
    }
    return self;
}

- (void)showDialog {
    FBSBJSON *jsonWriter = [[FBSBJSON new] autorelease];
	//jsonWriter.humanReadable = YES;
    
    //  Send a post to the feed for the user with the Graph API
	NSArray *actionLinks = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     @"<fb:intl>Get The App!</fb:intl>", @"name",
                                                     _appURL, @"link",
                                                     nil
                                                     ]];
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								   NSLocalizedString(@"Care to comment?", @"Facebook user message prompt"), @"message",
								   [jsonWriter stringWithObject:actionLinks], @"actions",
								   _imgURL, @"picture",
                                   _name, @"name",
                                   _caption, @"caption",
                                   _description, @"description",
                                   _imgLink ? _imgLink : _appURL, @"link",
								   nil];
    if (_properties) { // Does this even work anymore?
        [params setObject:[jsonWriter stringWithObject:_properties] forKey:@"properties"];
    }

	//NSLog(@"Story params: %@", [jsonWriter stringWithObject:params]);
	[_facebookUtil.facebook dialog:@"feed"
                         andParams:params
                       andDelegate:self];

}

#pragma mark - FBDialog delegate methods

- (void)dialog:(FBDialog *)dialog didFailWithError:(NSError*)error {
#ifdef DEBUG
    NSLog(@"FB feed dialog failed with error: %@", error);
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
    if ([_facebookUtil.delegate respondsToSelector:@selector(publishedToFeed)])
        [_facebookUtil.delegate publishedToFeed];
}

- (void)dealloc {
    [_caption release];
    [_description release];
    [_name release];
    [_properties release];
    [_appURL release];
    [_imgURL release];
    [_imgLink release];
    [super dealloc];
}

@end
