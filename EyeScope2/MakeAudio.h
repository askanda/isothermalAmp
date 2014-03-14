//
//  MakeAudio.h
//  EyeScope2
//
//  Created by Mike D'Ambrosio on 12/13/12.
//  Copyright (c) 2012 Mike D'Ambrosio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface MakeAudio : NSObject

void AudioEngineOutputBufferCallback (void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
-(void) generateTone: (AudioQueueBufferRef) buffer;

@end
