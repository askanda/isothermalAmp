//
//  MakeAudio.m
//  EyeScope2
//
//  Created by Mike D'Ambrosio on 12/13/12.
//  Copyright (c) 2012 Mike D'Ambrosio. All rights reserved.
//

#import "MakeAudio.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation MakeAudio
static AudioQueueRef outputQueue;

- (void) SetupAudioQueue {
    UInt32 sampleRate=8000;
    //Size size = sizeof(sampleRate);
    OSStatus err=noErr;;
    //err = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &sampleRate);
    //if (err != noErr) NSLog(@"AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate) error: %ld", err);
    //NSLog (@"Current hardware sample rate: %1.0f", sampleRate);
    
    //BOOL isHighSampleRate = (sampleRate > 16000);
    int bufferByteSize;
    AudioQueueBufferRef buffer;
    
    // Set up stream format fields
    AudioStreamBasicDescription streamFormat;
    streamFormat.mSampleRate = sampleRate;
    streamFormat.mFormatID = kAudioFormatLinearPCM;
    streamFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    streamFormat.mBitsPerChannel = 16;
    streamFormat.mChannelsPerFrame = 1;
    streamFormat.mBytesPerPacket = 2 * streamFormat.mChannelsPerFrame;
    streamFormat.mBytesPerFrame = 2 * streamFormat.mChannelsPerFrame;
    streamFormat.mFramesPerPacket = 1;
    streamFormat.mReserved = 0;
    
    // New output queue ---- PLAYBACK ----
    //if (isPlaying == NO) {
        err = AudioQueueNewOutput (&streamFormat, AudioEngineOutputBufferCallback, NULL, nil, nil, 0, &outputQueue);

   

    
        if (err != noErr) NSLog(@"AudioQueueNewOutput() error: %ld", err);
        
        // Enqueue buffers
        //outputFrequency = 0.0;
        //int outputBuffersToRewrite = 3;
        bufferByteSize = (sampleRate > 16000)? 2176 : 512; // 40.5 Hz : 31.25 Hz
        for (int i=0; i<3; i++) {
            err = AudioQueueAllocateBuffer (outputQueue, bufferByteSize, &buffer);
            if (err == noErr) {
                [self generateTone: buffer];
                err = AudioQueueEnqueueBuffer (outputQueue, buffer, 0, nil);
                if (err != noErr) NSLog(@"AudioQueueEnqueueBuffer() error: %ld", err);
            } else {
                NSLog(@"AudioQueueAllocateBuffer() error: %ld", err);
                return;
            }
        }
        
        // Start playback
        //isPlaying = YES;
        err = AudioQueueStart(outputQueue, nil);
        if (err != noErr) { NSLog(@"AudioQueueStart() error: %ld", err); /*isPlaying= NO;*/ return; }
    //} else {
        NSLog (@"Error: audio is already playing back.");
   // }
}

// AudioQueue output queue callback.
void AudioEngineOutputBufferCallback (void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    AudioEngine *engine = (AudioEngine*) inUserData;
    [engine processOutputBuffer:inBuffer queue:inAQ];
}

- (void) processOutputBuffer: (AudioQueueBufferRef) buffer queue:(AudioQueueRef) queue {
    OSStatus err;
    if (isPlaying == YES) {
        [outputLock lock];
        if (outputBuffersToRewrite > 0) {
            outputBuffersToRewrite--;
            [self generateTone:buffer];
        }
        err = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
        if (err == 560030580) { // Queue is not active due to Music being started or other reasons
            isPlaying = NO;
        } else if (err != noErr) {
            NSLog(@"AudioQueueEnqueueBuffer() error %d", err);
        }
        [outputLock unlock];
    } else {
        err = AudioQueueStop (queue, NO);
        if (err != noErr) NSLog(@"AudioQueueStop() error: %d", err);
    }
}

-(void) generateTone: (AudioQueueBufferRef) buffer {
    if (outputFrequency == 0.0) {
        memset(buffer->mAudioData, 0, buffer->mAudioDataBytesCapacity);
        buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
    } else {
        // Make the buffer length a multiple of the wavelength for the output frequency.
        int sampleCount = buffer->mAudioDataBytesCapacity / sizeof (SInt16);
        double bufferLength = sampleCount;
        double wavelength = sampleRate / outputFrequency;
        double repetitions = floor (bufferLength / wavelength);
        if (repetitions > 0.0) {
            sampleCount = round (wavelength * repetitions);
        }
        
        double      x, y;
        double      sd = 1.0 / sampleRate;
        double      amp = 0.9;
        double      max16bit = SHRT_MAX;
        int i;
        SInt16 *p = buffer->mAudioData;
        
        for (i = 0; i < sampleCount; i++) {
            x = i * sd * outputFrequency;
            switch (outputWaveform) {
                case kSine:
                    y = sin (x * 2.0 * M_PI);
                    break;
                case kTriangle:
                    x = fmod (x, 1.0);
                    if (x < 0.25)
                        y = x * 4.0; // up 0.0 to 1.0
                    else if (x < 0.75)
                        y = (1.0 - x) * 4.0 - 2.0; // down 1.0 to -1.0
                    else
                        y = (x - 1.0) * 4.0; // up -1.0 to 0.0
                    break;
                case kSawtooth:
                    y  = 0.8 - fmod (x, 1.0) * 1.8;
                    break;
                case kSquare:
                    y = (fmod(x, 1.0) < 0.5)? 0.7: -0.7;
                    break;
                default: y = 0; break;
            }
            p[i] = y * max16bit * amp;
        }
        
        buffer->mAudioDataByteSize = sampleCount * sizeof (SInt16);
    }
}


@end

