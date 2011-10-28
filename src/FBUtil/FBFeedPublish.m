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
                    appURL:(NSString *)appURL
                  imageURL:(NSString *)img
{
    self = [super init];
    if (self) {
        _facebookUtil = fb;
        _caption = [caption copy];
        _description = [desc copy];
        _name = [name copy];
        _appURL = [appURL copy];
        _imgURL = [img copy];
    }
    return self;
}

- (void)showDialog {
    SBJSON *jsonWriter = [[SBJSON new] autorelease];
	//jsonWriter.humanReadable = YES;
    
	NSDictionary *image = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"image",@"type",
                           _imgURL,@"src",
                           _appURL,@"href",
						   nil];
	NSDictionary *attachment = [NSDictionary dictionaryWithObjectsAndKeys:
                                _name, @"name",
								_caption, @"caption",
								_description, @"description",
								[NSArray arrayWithObject:image], @"media",
								nil
								];
	NSArray *actionLinks = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     @"<fb:intl>Get The App!</fb:intl>", @"text",
                                                     _appURL, @"href",
                                                     nil
                                                     ]];
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								   _facebookUtil.apiKey, @"api_key",
								   NSLocalizedString(@"Care to comment?", @"Facebook user message prompt"), @"user_message_prompt",
								   [jsonWriter stringWithObject:actionLinks], @"action_links",
								   [jsonWriter stringWithObject:attachment], @"attachment",
								   nil];
	
	//NSLog(@"Story params: %@", [jsonWriter stringWithObject:params]);
	[_facebookUtil.facebook dialog:@"stream.publish"
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
    [_appURL release];
    [_imgURL release];
    [super dealloc];
}

@end
