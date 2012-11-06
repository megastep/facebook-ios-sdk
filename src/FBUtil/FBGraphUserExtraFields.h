//
//  FBGraphUserExtraFields.h
//  facebook-ios-sdk
//
//  Created by Stéphane Peter on 10/17/12.
//
//

#import <Foundation/Foundation.h>
#import "FacebookSDK.h"

@protocol FBGraphUserExtraFields <FBGraphUser>

@property (nonatomic, retain) NSArray *devices;

@property (nonatomic, retain) NSNumber *installed;

@end