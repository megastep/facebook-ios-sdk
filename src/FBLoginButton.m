/*
 * Copyright 2010 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

#import "FBLoginButton.h"
#import "Facebook.h"

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation FBLoginButton

@synthesize style = _style, delegate = _delegate;

///////////////////////////////////////////////////////////////////////////////////////////////////
// private

- (BOOL)isLoggedIn {
	return _isLoggedIn;
}

- (void)setIsLoggedIn:(BOOL)loggedin {
	if (loggedin != _isLoggedIn) {
		_isLoggedIn = loggedin;
		[self updateImage];
	}
}

/**
 * return the regular button image according to the login status
 */
- (UIImage*)buttonImage {
  if (_isLoggedIn) {
    return [UIImage imageNamed:@"FBConnect.bundle/images/LogoutNormal.png"];
  } else {
	  if (_style == FBLoginButtonStyleWide) {
		  return [UIImage imageNamed:@"FBConnect.bundle/images/LoginWithFacebookNormal.png"];
	  } else {
		  return [UIImage imageNamed:@"FBConnect.bundle/images/LoginNormal.png"];
	  }
  }
}

/**
 * return the highlighted button image according to the login status
 */
- (UIImage*)buttonHighlightedImage {
  if (_isLoggedIn) {
    return [UIImage imageNamed:@"FBConnect.bundle/images/LogoutPressed.png"];
  } else {
	if (_style == FBLoginButtonStyleWide) {
		return [UIImage imageNamed:@"FBConnect.bundle/images/LoginWithFacebookPressed.png"];
	} else {
		return [UIImage imageNamed:@"FBConnect.bundle/images/LoginPressed.png"];
	}
  }
}

- (void)touchUpInside {
	if (_delegate) {
		[_delegate fbButtonClicked:_isLoggedIn];
	}
}

- (void)initButton {
	_style = FBLoginButtonStyleNormal;
	
	_imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_imageView.contentMode = UIViewContentModeCenter;
	[self addSubview:_imageView];
	
	self.backgroundColor = [UIColor clearColor];
	[self addTarget:self action:@selector(touchUpInside)
		forControlEvents:UIControlEventTouchUpInside];

	[self updateImage];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (id)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame]) != nil) {
		[self initButton];
		if (CGRectIsEmpty(frame)) {
			[self sizeToFit];
		}
	}
	return self;
}

- (void)awakeFromNib {
	[self initButton];
}

- (void)dealloc {
	[_imageView release];
	[super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UIView

- (CGSize)sizeThatFits:(CGSize)size {
	return _imageView.image.size;
}

- (void)layoutSubviews {
	_imageView.frame = self.bounds;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UIControl

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	[self updateImage];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UIAccessibility informal protocol

- (BOOL)isAccessibilityElement {
	return YES;
}

- (UIAccessibilityTraits)accessibilityTraits {
	return [super accessibilityTraits]|UIAccessibilityTraitImage|UIAccessibilityTraitButton;
}

- (NSString *)accessibilityLabel {
	if (_isLoggedIn) {
		return NSLocalizedString(@"Logout from Facebook", @"Accessibility label");
	} else {
		return NSLocalizedString(@"Login with Facebook", @"Accessibility label");
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// FBSessionDelegate protocol

/**
 * Called when the user successfully logged in.
 */
- (void)fbDidLogin {
	_isLoggedIn = YES;
}

/**
 * Called when the user dismissed the dialog without logging in.
 */
- (void)fbDidNotLogin:(BOOL)cancelled {
	_isLoggedIn = NO;
}

/**
 * Called when the user logged out.
 */
- (void)fbDidLogout {
	_isLoggedIn = NO;
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// public

/**
 * To be called whenever the login status is changed
 */
- (void)updateImage {
	if (self.highlighted) {
		_imageView.image = [self buttonHighlightedImage];
	} else {
		_imageView.image = [self buttonImage];
	}
}

@end 
