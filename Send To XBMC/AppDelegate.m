//
//  AppDelegate.m
//  Send To XBMC
//
//  Created by Kyle Howells on 04/09/2014.
//  Copyright (c) 2014 Kyle Howells. All rights reserved.
//

#import "AppDelegate.h"
#import "AFNetworking.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *xbmcIPAddressTextField;
@property (weak) IBOutlet NSTextField *youtubeIDTextField;

-(IBAction)goPressed:(id)sender;
@end



@implementation AppDelegate

#pragma mark - URL Handling

-(void)applicationWillFinishLaunching:(NSNotification *)aNotification {
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
	[NSApp setServicesProvider:self];
}

-(void)openLink:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error{
	NSLog(@"openLink:%@ userData:%@ error:", pboard, userData);
	NSLog(@"PB Types: %@", [pboard types]);
	
	NSString *plainText = [pboard stringForType:NSStringPboardType];
	
	if (!plainText) {
		if ([[pboard types] containsObject:NSRTFPboardType]){
			NSAttributedString *attributed = [[NSAttributedString alloc] initWithRTF:[pboard dataForType:NSRTFPboardType] documentAttributes:nil];
			plainText = [attributed string];
		}
	}
	
	if (plainText) {
		[self.youtubeIDTextField setStringValue:plainText];
	}
}

-(void)handleURLEvent:(NSAppleEventDescriptor*)event withReplyEvent:(NSAppleEventDescriptor*)replyEvent {
	NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	NSLog(@"handleURLEvent: %@", urlString);
	
	[self.youtubeIDTextField setStringValue:urlString];
}


#pragma mark - File handling

-(BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename{
	NSLog(@"theApplication = %@  - - -  filename = %@", theApplication, filename);
	return YES;
}

-(BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication{
	NSLog(@"theApplication = %@", theApplication);
	return YES;
}



#pragma mark - Application Lifecycle

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self.youtubeIDTextField becomeFirstResponder];
	
	NSString *xbmcURLString = [[NSUserDefaults standardUserDefaults] objectForKey:@"XBMC_URL"];
	if (xbmcURLString) {
		[self.xbmcIPAddressTextField setStringValue:xbmcURLString];
	}
}


-(void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
	NSString *xbmcURLString = self.xbmcIPAddressTextField.stringValue;
	[[NSUserDefaults standardUserDefaults] setObject:xbmcURLString forKey:@"XBMC_URL"];
	NSLog(@"Saved XBMC URL: %@", xbmcURLString);
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application
{
	return YES;
}




#pragma mark - Buttons

-(IBAction)goPressed:(id)sender {
	NSString *videoIDString = [self currentYoutubeID];
	if (videoIDString.length < 1) {
		// TODO: play the playlist if nothing playing
		// TODO: check currently playing
		// TODO: if nothing playing then play the playlist
		return;
	}
	
	
	
	NSDictionary *clearParams = @{ @"playlistid": @1 };
	
	[self sendRequestMethod:@"Playlist.Clear" parameters:clearParams withCallback:^(BOOL successful) {
		NSString *youtubeURLString = [NSString stringWithFormat:@"plugin://plugin.video.youtube/?action=play_video&videoid=%@", videoIDString];
		
		NSDictionary *parameters = @{ @"item": @{ @"file" : youtubeURLString },
									  @"playlistid": @1
									};
		
		[self sendRequestMethod:@"Playlist.Add" parameters:parameters withCallback:^(BOOL success) {
			if (success) {
				
				NSDictionary *params = @{ @"item": @{ @"playlistid": [NSNumber numberWithInt:1], @"position": @0 } };
				[self sendRequestMethod:@"Player.Open" parameters:params withCallback:nil];
			}
		}];
	}];
	
	
	// muJ87aKQvXU = flash
	// yj4OtpHl8EE = arrow
}



-(IBAction)queuePressed:(id)sender {
	NSString *videoIDString = [self currentYoutubeID];
	if (videoIDString && videoIDString.length < 2) { return; }
	
	
	NSString *youtubeURLString = [NSString stringWithFormat:@"plugin://plugin.video.youtube/?action=play_video&videoid=%@", videoIDString];
	
	NSDictionary *parameters = @{ @"item": @{ @"file" : youtubeURLString },
								  @"playlistid": @1 };
	
	[self sendRequestMethod:@"Playlist.Add" parameters:parameters withCallback:nil];
}






#pragma mark - XBMC helper methods

-(void)sendRequestMethod:(NSString*)method parameters:(NSDictionary*)parameters withCallback:(void (^)(BOOL success))block{
	NSString *xbmcAddressString = self.xbmcIPAddressTextField.stringValue;
	if (xbmcAddressString.length < 2) {
		xbmcAddressString = @"192.168.1.100:8080";
	}
	NSString *xbmcAddress = [NSString stringWithFormat:@"http://%@/jsonrpc", xbmcAddressString];
	
//	__strong void(^blockCopy)(BOOL finished) = [block copy];
	
	NSDictionary *_parameters = @{@"jsonrpc": @"2.0",
								 @"method": method,
								 @"params": parameters,
								 @"id" : @"1"};
	
	NSURLRequest *request = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST" URLString:xbmcAddress parameters:_parameters error:nil];
	
	AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
	operation.responseSerializer = [AFJSONResponseSerializer serializer];
	[operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject)
	{
		NSLog(@"JSON: %@", responseObject);
		if (block) {
			block(YES);
		}
	}
	failure:^(AFHTTPRequestOperation *operation, NSError *error)
	{
		NSLog(@"Error: %@", error);
		if (block) {
			block(NO);
		}
	}];
	
	[[[AFHTTPRequestOperationManager manager] operationQueue] addOperation:operation];
	
	NSLog(@"_parameters = %@", _parameters);
}







#pragma mark - YouTube ID Methods


-(NSString*)currentYoutubeID{
	return [self youtubeIDForString:self.youtubeIDTextField.stringValue];
}

/*
 --- Method Test Strings ---
 
 1. http://www.youtube.com/watch?v=wCQSIub_g7M&feature=youtu.be
 2. http://youtu.be/yj4OtpHl8EE
 3. http://www.youtube.com/watch?v=ZvmMzI0X7fE
 4. https://www.youtube.com/watch?v=mHeo62B0d0E&index=13&list=FLJ6Kj3NntkXiV-u2TTBO9w
 5. https://www.youtube.com/watch?index=13&list=FLJ6Kj3NntkXiV-ux2TTBO9w&v=XYPxJtra1ws
 6. yj4OtpHl8EE
 7. muJ87aKQvXU
 
 |
 | The below method should successfully parse all the above strings.
 |
*/
-(NSString*)youtubeIDForString:(NSString*)inputString{
	NSString *videoIDString = inputString;
	
	BOOL httpFound = [videoIDString rangeOfString:@"http"].location != NSNotFound;
	BOOL wwwFound = [videoIDString rangeOfString:@"www"].location != NSNotFound;
	BOOL comFound = [videoIDString rangeOfString:@"com"].location != NSNotFound;
	BOOL slashFound = [videoIDString rangeOfString:@"/"].location != NSNotFound;
	
	if (slashFound || comFound || wwwFound || httpFound) {
		// It is likely a URL
		
		BOOL vFound = [videoIDString rangeOfString:@"v="].location != NSNotFound;
		if (vFound) {
			// We found the v=, now parse the URL
			NSRange vRange = [videoIDString rangeOfString:@"v="];
			NSMutableString *string = videoIDString.mutableCopy;
			[string replaceCharactersInRange:NSMakeRange(0, vRange.location) withString:@""];
			
			NSMutableDictionary *keyValues = [NSMutableDictionary dictionary];
			
			NSArray *stringParts = [string componentsSeparatedByString:@"&"];
			if (stringParts.count > 0) {
				for (NSString *subString in stringParts) {
					NSArray *keyValue = [subString componentsSeparatedByString:@"="];
					if (keyValue.count == 2) {
						[keyValues setValue:[keyValue objectAtIndex:1] forKey:[keyValue objectAtIndex:0]];
					}
				}
			}
			
//			NSLog(@"keyValues = %@", keyValues);
//			NSLog(@"\nVideo ID = %@", keyValues[@"v"]);
			return keyValues[@"v"];
		}
		else {
			NSArray *stringParts = [videoIDString componentsSeparatedByString:@"/"];
//			NSLog(@"stringParts = %@", stringParts);
			return stringParts.lastObject;
		}
	}
	else if (videoIDString.length > 0) {
		return videoIDString;
	}
	
	return nil;
}






#pragma mark - Tests

-(void)testYoutubeStrings{
	NSArray *testStrings = @[@"http://www.youtube.com/watch?v=wCQSIub_g7M&feature=youtu.be",
							 @"http://youtu.be/yj4OtpHl8EE",
							 @"http://www.youtube.com/watch?v=ZvmMzI0X7fE",
							 @"https://www.youtube.com/watch?v=mHeo62B0d0E&index=13&list=FLJ6Kj3NntkXiV-u2TTBO9w",
							 @"https://www.youtube.com/watch?index=13&list=FLJ6Kj3NntkXiV-ux2TTBO9w&v=XYPxJtra1ws",
							 @"yj4OtpHl8EE",
							 @"muJ87aKQvXU"];
	
	
	for (NSString *string in testStrings) {
		NSString *returnString = [self youtubeIDForString:string];
		NSLog(@"\nInput String: %@\nVideo ID: %@", string, returnString);
	}
}

@end



