//
//  FBFeedPublish.m
//  Hold data for the FB dialog to publish a feed story
//
//  Created by Stéphane Peter on 10/26/11.
//
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import "FBFeedPublish.h"
#import "FBSBJSON.h"

@implementation FBFeedPublish {
    FacebookUtil *_facebookUtil;
    NSDictionary *_properties;
    NSString *_caption, *_description, *_textDesc, *_name, *_appURL, *_imgURL, *_imgLink, *_imgPath;
}

- (id)initWithFacebookUtil:(FacebookUtil *)fb
                   caption:(NSString *)caption 
               description:(NSString *)desc
           textDescription:(NSString *)txt
                      name:(NSString *)name
                properties:(NSDictionary *)props
                    appURL:(NSString *)appURL
                 imagePath:(NSString *)path
                  imageURL:(NSString *)img
                 imageLink:(NSString *)imgURL
{
    self = [super init];
    if (self) {
        _facebookUtil = fb;
        _caption = [caption copy];
        _description = [desc copy];
        _textDesc = [txt copy];
        _name = [name copy];
        _properties = props;
        _appURL = [appURL copy];
        _imgURL = [img copy];
        _imgLink = [imgURL copy];
        _imgPath = [path copy];
    }
    return self;
}

- (void)showDialogFrom:(UIViewController *)vc {
    // First try to set up a native dialog - we can't use the properties so make them part of the description.
    NSMutableString *nativeDesc = [NSMutableString stringWithFormat:@"%@\n",_textDesc];
    for (NSString *key in _properties) {
        [nativeDesc appendString:[NSString stringWithFormat:@"%@: %@\n",key,[_properties objectForKey:key]]];
    }
    BOOL nativeSuccess = [FBNativeDialogs presentShareDialogModallyFrom:vc
                                                            initialText:nativeDesc
                                                                  image:(_imgPath ? [UIImage imageNamed:_imgPath] : nil)
                                                                    url:[NSURL URLWithString:_appURL]
                                                                handler:^(FBNativeDialogResult result, NSError *error) {
                                                                    // Only show the error if it is not due to the dialog
                                                                    // not being supporte, i.e. code = 7, otherwise ignore
                                                                    // because our fallback will show the share view controller.
                                                                    if (error && [error code] == 7) {
                                                                        return;
                                                                    }
                                                                    
                                                                    if (error) {
                                                                        NSLog(@"FBNativeDialogs error: %@", error);
                                                                    }
                                                                }];
    
    if (!nativeSuccess) {
        FBSBJSON *jsonWriter = [FBSBJSON new];
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
}

#pragma mark - FBDialog delegate methods

- (void)dialog:(FBDialog *)dialog didFailWithError:(NSError*)error {
#ifdef DEBUG
    NSLog(@"FB feed dialog failed with error: %@", error);
#endif
	if ([error code] == 190) {
		// Invalid token - force login
		[_facebookUtil logout];
		[_facebookUtil login:YES andThen:nil];
	} else {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
														message:[NSString stringWithFormat:@"%@.",[error localizedDescription]] 
													   delegate:nil
											  cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
											  otherButtonTitles:nil];
		[alert show];
	}
}

- (void)dialogDidComplete:(FBDialog *)dialog {
    if ([_facebookUtil.delegate respondsToSelector:@selector(publishedToFeed)])
        [_facebookUtil.delegate publishedToFeed];
}

@end
