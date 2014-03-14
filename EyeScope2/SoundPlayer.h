//
//  SoundPlayer.h
//  musiculesdev
//
//  Created by Dylan on 1/17/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define NUM_BUFFERS 3

@class Sound;

typedef struct AQDataType {
	AudioStreamBasicDescription dataFormat;
	AudioQueueRef queue;
	AudioQueueBufferRef buffers[NUM_BUFFERS];
	AudioFileID audioFile;
	UInt32 bufferByteSize;
	SInt64 currentPacket;
	UInt32 numPacketsToRead;
	AudioStreamPacketDescription *packetDescription;
	bool isRunning;
	UInt32 frameCount;
	
} AQDataType;



@interface SoundPlayer : NSObject {
	
	NSMutableArray *sounds;
	AQDataType aqData;
	
}

@property (nonatomic, retain) NSMutableArray *sounds;
@property (nonatomic, assign) AQDataType aqData;

-(void)start;
-(void)stop;

@end
