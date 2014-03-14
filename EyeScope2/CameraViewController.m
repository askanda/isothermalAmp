//
//  CameraViewController.m
//  EyeScope2
//
//  Created by Mike D'Ambrosio on 12/13/12.
//  Copyright (c) 2012 Mike D'Ambrosio. All rights reserved.
//

#import "CameraViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>
#import "ToneGeneratorViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>
#import "ImageProcessor.h"
dispatch_queue_t backgroundQueue;
double totScale=1;
int doubleTapEnabled=1;
int speak=1;
int mirrored=0;
int volumeSnap=1;
int pwmSet=0;
int exposureMode=0;
int ledCompCount=0;
int passedExposureMode=0;


int numberOfFrames = 180;
double panRolloverX=0;
double panRolloverY=0;
double panXLast;
double panYLast;
double rotLast;
double rotRollover;
int justIn2Touch;
int lastDir=0;

int currentFrame = 0;
int secondsTillCapture = 0;
int captureInterval = 30;

@interface CameraViewController  ()

@end

@implementation CameraViewController
@synthesize preview;
@synthesize session;
@synthesize device;
@synthesize input;
@synthesize videoPreviewOutput, videoHDOutput, stillOutput;
@synthesize captureVideoPreviewLayer;
@synthesize ble;
@synthesize toggleLED;
@synthesize toggleBF;
@synthesize startTimelapse;
@synthesize singleSnap;
@synthesize processor;
@synthesize flatImage;
@synthesize singleFlatImage;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ([otherGestureRecognizer isMemberOfClass:[UIPinchGestureRecognizer class]]){
        if ([gestureRecognizer isMemberOfClass:[UIRotationGestureRecognizer class]]){
            return YES;
        }
    }
    else return NO;
}

- (void)viewDidLoad
{
    //load our image processor
    //processor = [[ImageProcessor alloc] init];
    //register for notifications
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(eventHandler:)
     name:@"eventType"
     object:nil ];
    
    
    //add gesture recognizers
    UIRotationGestureRecognizer *rotationRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotationDetected:)];
    [self.view addGestureRecognizer:rotationRecognizer];
    rotationRecognizer.delegate = self;
    
    
    //setup bluetooth
    [super viewDidLoad];
    ble = [[BLE alloc] init];
    [ble controlSetup];
    ble.delegate = self;
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(volumeChanged:)
     name:@"AVSystemController_SystemVolumeDidChangeNotification"
     object:nil];
    
    // On iOS 4.0+ only, listen for background notification
    if(&UIApplicationDidEnterBackgroundNotification != nil)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundSel:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    // On iOS 4.0+ only, listen for foreground notification
    if(&UIApplicationWillEnterForegroundNotification != nil)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foregroundSel:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    
    
    
    
    backgroundQueue = dispatch_queue_create("robbie.cellscope.playsound", NULL);
    
    
    // Setup the AV foundation capture session
    self.session = [[AVCaptureSession alloc] init];
    
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:&error];
    
    if (!input) {
		// Handle the error appropriately.
		NSLog(@"ERROR: trying to open camera: %@", error);
	}
    // Setup image preview layer
    //preview.transform = CGAffineTransformMakeRotation(.5*M_PI);
    
    CALayer *viewLayer = self.preview.layer;
    captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession: self.session];
    
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    captureVideoPreviewLayer.frame = viewLayer.bounds;
    NSMutableArray *layers = [NSMutableArray arrayWithArray:viewLayer.sublayers];
    [layers insertObject:captureVideoPreviewLayer atIndex:0];
    viewLayer.sublayers = [NSArray arrayWithArray:layers];
    
    // Setup still image output
    self.stillOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [self.stillOutput setOutputSettings:outputSettings];
    
    
    // Add session input and output
    [self.session addInput:self.input];
    [self.session addOutput:self.stillOutput];
    
    [self.session startRunning];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
	[singleTap setNumberOfTapsRequired:1];
    [self.view addGestureRecognizer:singleTap];
    if (doubleTapEnabled==1){
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        [self.view addGestureRecognizer:doubleTap];
        
        [singleTap requireGestureRecognizerToFail:doubleTap];
    }
	// Do any additional setup after loading the view.
    
    
}

- (void)backgroundSel:(NSNotification *)notification
{
    
    NSLog(@"background!!!");
    NSLog(@"reset bluetooth");
    
    
    //connect to bluetooth
    if (ble.activePeripheral)
        if(ble.activePeripheral.isConnected)
        {
            [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];
            //[btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
            return;
            
        }
    
    if (ble.peripherals)
        ble.peripherals = nil;
    
}
- (void)foregroundSel:(NSNotification *)notification
{
    
    NSLog(@"foreground!!!");
    
    [ble findBLEPeripherals:2];
    [NSTimer scheduledTimerWithTimeInterval:(float)2.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
}



-(void) viewDidDisappear:(BOOL)animated{
    
    
}
-(void) viewDidAppear:(BOOL)animated {
    
    //connect to bluetooth
    if (ble.activePeripheral)
        if(ble.activePeripheral.isConnected)
        {
            [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];
            //[btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
            return;
        }
    
    if (ble.peripherals)
        ble.peripherals = nil;
    
    //[btnConnect setEnabled:false];
    [ble findBLEPeripherals:2];
    [NSTimer scheduledTimerWithTimeInterval:(float)2.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
    
}

#pragma mark - BLE delegate

- (void)bleDidDisconnect
{
    NSLog(@"->Disconnected");
}

// When RSSI is changed, this will be called
-(void) bleDidUpdateRSSI:(NSNumber *) rssi
{
    //lblRSSI.text = rssi.stringValue;
}

// When disconnected, this will be called
-(void) bleDidConnect
{
    NSLog(@"->Connected");
    
}

// When data is comming, this will be called
-(void) bleDidReceiveData:(unsigned char *)data length:(int)length
{
    NSLog(@"Length: %d", length);
    
    // parse data, all commands are in 3-byte
    for (int i = 0; i < length; i+=3)
    {
        NSLog(@"0x%02X, 0x%02X, 0x%02X", data[i], data[i+1], data[i+2]);
        float tempSensorValue = (data[i]+ 255 - 382) * .357 + 23.0;
        [_sensorDisplayLabel setText:[NSString stringWithFormat:@"Temp: %.01f C",tempSensorValue]];
        if (data[i] == 0x0A)
        {
        }
        else if (data[i] == 0x0B)
        {
            UInt16 Value;
            
            Value = data[i+2] | data[i+1] << 8;
            //lblAnalogIn.text = [NSString stringWithFormat:@"%d", Value];
        }
    }
}



- (IBAction)handleRot:(UIRotationGestureRecognizer *) rotateGesture {
}
- (void) handleDoubleTap:(UIGestureRecognizer *) doubleGesture {
    NSLog(@"in double ibaction");
    
    AudioSessionInitialize(NULL, NULL, NULL, NULL);
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    OSStatus err = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                                           sizeof(sessionCategory),
                                           &sessionCategory);
    AudioSessionSetActive(TRUE);
    if (err) {
        NSLog(@"AudioSessionSetProperty kAudioSessionProperty_AudioCategory failed: %ld", err);
    }
    NSString *soundFilePath;
    if (speak==0){
        soundFilePath = [[NSBundle mainBundle] pathForResource: @"computerbeep_62" ofType: @"wav"];
    }
    else {
        soundFilePath = [[NSBundle mainBundle] pathForResource: @"exposure_locked" ofType: @"mp3"];
    }
    NSLog(@"%@", soundFilePath);
    NSURL *fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
    NSError *error3;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL: fileURL error: &error3];
    NSLog(@"%@", error3);
    [player setVolume: 1];    // available range is 0.0 through 1.0
    dispatch_async(backgroundQueue, ^(void) {
        @autoreleasepool {
            NSLog(@"playing sound");
            [player play];
            //@TODO- this shouldn't be here
            sleep(2);
        }
    });
    CGPoint tapPoint = [doubleGesture locationInView:doubleGesture.view];
    int tapX = (int) tapPoint.x;
    int tapY = (int) tapPoint.y;
    NSLog(@"TAPPED X:%d Y:%d", tapX, tapY);
    CGPoint  tapPoint2=[self convertToPointOfInterestFromViewCoordinates:(tapPoint)];
    double tapX2 = (double) tapPoint2.x;
    double tapY2 = (double) tapPoint2.y;
    NSLog(@"2!!!TAPPED X:%f Y:%f", tapX2, tapY2);
    CGPoint p; p.x = 1-tapPoint2.x; p.y = 1-tapPoint2.y;
    double px = (double) p.x;
    double py = (double) p.y;
    NSLog(@"3!!!TAPPED X:%f Y:%f", px, py);
    NSError * error;
    if ([self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] &&
        [self.device isExposurePointOfInterestSupported] && doubleTapEnabled==1)
    {
        if ([self.device lockForConfiguration:&error]) {
            NSLog(@"exposing on point...");
            //[self.device setExposurePointOfInterest:p];
            //[self.device setExposureMode:AVCaptureFocusModeAutoFocus];
            
            [device addObserver:self
                     forKeyPath:@"adjustingExposure"
                        options:NSKeyValueObservingOptionNew
                        context:nil];
            [device setExposurePointOfInterest:p];
            [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            //[device setExposureMode:AVCaptureExposureModeLocked];
            [self.device unlockForConfiguration];
        } else {
            NSLog(@"Error: %@", error);
        }
    }
    
    

    
}
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
{
    NSLog(@"screen height %f", [[UIScreen mainScreen] bounds].size.height);
    NSLog(@"screen width %f", [[UIScreen mainScreen] bounds].size.width);
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = [[self preview] frame].size;
    AVCaptureVideoPreviewLayer *videoPreviewLayer = [self captureVideoPreviewLayer];
    if ([[self captureVideoPreviewLayer] isMirrored]) {
        NSLog(@"in isMirrored");
        
        viewCoordinates.x = frameSize.width - viewCoordinates.x;
    }
    
    if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize] ) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in [[[[self session] inputs] lastObject] ports]) {
            if ([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if (viewRatio > apertureRatio) {
                        NSLog(@"calculating coords2");
                        NSLog(@"%f", apertureSize.height);
                        NSLog(@"%f", apertureSize.width);
                        NSLog(@"%f", frameSize.height);
                        NSLog(@"%f", frameSize.width);
                        NSLog(@"%f", point.x);
                        NSLog(@"%f", point.y);
                        
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                        xc=point.x/[[UIScreen mainScreen] bounds].size.width;
                        yc=1-point.y/[[UIScreen mainScreen] bounds].size.height;
                    } else {
                        NSLog(@"calculating coords");
                        NSLog(@"%f", apertureSize.height);
                        NSLog(@"%f", apertureSize.width);
                        NSLog(@"%f", frameSize.height);
                        NSLog(@"%f", frameSize.width);
                        NSLog(@"%f", point.x);
                        NSLog(@"%f", point.y);
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                        //@TODO works only on 4/4s, easy fix
                        xc=point.x/[[UIScreen mainScreen] bounds].size.width;
                        yc=1-point.y/[[UIScreen mainScreen] bounds].size.height;
                    }
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    return pointOfInterest;
}


-(void) connectionTimer:(NSTimer *)timer
{
    //[btnConnect setEnabled:true];
    //[btnConnect setTitle:@"Disconnect" forState:UIControlStateNormal];
    
    if (ble.peripherals.count > 0)
    {
        for (CBPeripheral* p in ble.peripherals)
        {
            NSLog(p.identifier.UUIDString);
            if ([p.identifier.UUIDString isEqualToString:@"B68E877E-1AD3-1532-F340-42BEF02C34D5"])
            {
                [ble connectPeripheral:p];
            }
        }
        //[ble connectPeripheral:[ble.peripherals objectAtIndex:0]];
        AudioSessionInitialize(NULL, NULL, NULL, NULL);
        UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
        OSStatus err = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                                               sizeof(sessionCategory),
                                               &sessionCategory);
        AudioSessionSetActive(TRUE);
        if (err) {
            NSLog(@"AudioSessionSetProperty kAudioSessionProperty_AudioCategory failed: %ld", err);
        }
        NSString *soundFilePath;
        if (speak==0){
            soundFilePath = [[NSBundle mainBundle] pathForResource: @"computerbeep_62" ofType: @"wav"];
        }
        else {
            soundFilePath = [[NSBundle mainBundle] pathForResource: @"bluetooth_connected" ofType: @"mp3"];
            
            
        }
        
        NSLog(@"%@", soundFilePath);
        NSURL *fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
        NSError *error3;
        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL: fileURL error: &error3];
        NSLog(@"%@", error3);
        
        [player setVolume: 1];    // available range is 0.0 through 1.0
        
        dispatch_async(backgroundQueue, ^(void) {
            @autoreleasepool {
                NSLog(@"playing sound");
                [player play];
                sleep(2);
            }
        });
    }
    else
    {
        //try connecting again
        //connect to bluetooth
        if (ble.activePeripheral)
            if(ble.activePeripheral.isConnected)
            {
                [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];
                //[btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
                return;
            }
        
        if (ble.peripherals)
            ble.peripherals = nil;
        
        //[btnConnect setEnabled:false];
        [ble findBLEPeripherals:2];
        [NSTimer scheduledTimerWithTimeInterval:(float)2.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
        
        //[btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
        //[indConnecting stopAnimating];
    }
}


- (void)handleSingleTap:(UIGestureRecognizer *)gestureRecognizer {
    
    //[self snap];
    
    
}

//- (IBAction)snap:(id)sender {
- (IBAction)snap {
    NSLog(@"about to request a capture from: %@", stillOutput);
    
    processor = [[ImageProcessor alloc] init];
    processor.exposureMode=exposureMode;
    
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in stillOutput.connections)
    {
        for (AVCaptureInputPort *port in [connection inputPorts])
        {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    
    [stillOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         //CFDictionaryRef exifAttachments = CMGetAttachment(imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
         UIImage *image = [[UIImage alloc] initWithData:imageData];
         //NSDictionary *metadata = (__bridge NSDictionary *)exifAttachments;
         //NSLog(@"%@",metadata);
         //see snapTimer for commented out possibly useful stuff
         [processor addImage:image];
         // Request to save the image to camera roll
         ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
         
         [library writeImageToSavedPhotosAlbum:image.CGImage orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:^(NSURL *assetURL, NSError *error){
              NSLog(@"In the 'error' area");
             
             if (error) {
                 NSLog(@"Error writing image to photo album");
             }
             else {
             }
         }];
         // Set the picture properties
     }];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
   
    // Handle error saving image to camera roll
    if (error != NULL) {
        NSLog(@"Error saving picture to camera rolll");
    }
}

- (IBAction)handlePinch:(UIPinchGestureRecognizer *) recognizer  {
    NSLog(@"in pinch ibaction, %f ", recognizer.scale);
}
- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)longPress  {
    if (longPress.state == UIGestureRecognizerStateBegan){
        NSLog(@"in longpress ibaction");
        AudioSessionInitialize(NULL, NULL, NULL, NULL);
        UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
        OSStatus err = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                                               sizeof(sessionCategory),
                                               &sessionCategory);
        AudioSessionSetActive(TRUE);
        if (err) {
            NSLog(@"AudioSessionSetProperty kAudioSessionProperty_AudioCategory failed: %ld", err);
        }
        NSString *soundFilePath;
        if (speak==0){
            soundFilePath = [[NSBundle mainBundle] pathForResource: @"computerbeep_62" ofType: @"wav"];
        }
        else {
            soundFilePath = [[NSBundle mainBundle] pathForResource: @"focus_locked" ofType: @"mp3"];
            
        }
        NSLog(@"%@", soundFilePath);
        NSURL *fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
        NSError *error;
        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL: fileURL error: &error];
        NSLog(@"%@", error);
        [player setVolume: 1];    // available range is 0.0 through 1.0
        dispatch_async(backgroundQueue, ^(void) {
            @autoreleasepool {
                NSLog(@"playing sound");
                [player play];
                sleep(2);
            }
        });
        CGPoint tapPoint = [longPress locationInView:longPress.view];
        int tapX = (int) tapPoint.x;
        int tapY = (int) tapPoint.y;
        NSLog(@"TAPPED X:%d Y:%d", tapX, tapY);
        CGPoint  tapPoint2=[self convertToPointOfInterestFromViewCoordinates:(tapPoint)];
        double tapX2 = (double) tapPoint2.x;
        double tapY2 = (double) tapPoint2.y;
        NSLog(@"2!!!TAPPED X:%f Y:%f", tapX2, tapY2);
        CGPoint p; p.x = 1-tapPoint2.x; p.y = 1-tapPoint2.y;
        double px = (double) p.x;
        double py = (double) p.y;
        NSLog(@"3!!!TAPPED X:%f Y:%f", px, py);
        //CGContextRef ctx = UIGraphicsGetCurrentContext();
        //CGContextSetRGBFillColor(ctx, 1.0, 0.0, 0.0, 1.0);
        //CGContextFillRect(ctx, CGRectMake(100.0, 100.0, 100.0, 100.0));
        //[self drawRect:(CGRectMake(100.0, 100.0, 100.0, 100.0))];
        NSError *error2;
        if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus] &&
            [self.device isFocusPointOfInterestSupported])
        {
            if ([self.device lockForConfiguration:&error2]) {
                NSLog(@"focussing on point...");
                [self.device setFocusPointOfInterest:p];
                [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
                
                [self.device unlockForConfiguration];
            } else {
                NSLog(@"Error: %@", error2);
            }
        }
        if ([self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] &&
            [self.device isExposurePointOfInterestSupported] && doubleTapEnabled==0)
        {
            if ([self.device lockForConfiguration:&error]) {
                NSLog(@"exposing on point...");
                //[self.device setExposurePointOfInterest:p];
                //[self.device setExposureMode:AVCaptureFocusModeAutoFocus];
                [device     addObserver:self
                             forKeyPath:@"adjustingExposure"
                                options:NSKeyValueObservingOptionNew
                                context:nil];
                [device setExposurePointOfInterest:p];
                [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
                //[device setExposureMode:AVCaptureExposureModeLocked];
                
                [self.device unlockForConfiguration];
            } else {
                NSLog(@"Error: %@", error);
            }
        }
    }

    
}

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*) change context:(void*)context{
        NSLog(@"%@", [change objectForKey:NSKeyValueChangeNewKey]);
    //if ([keyPath isEqual:@"adjustingExposure"]) {
    //NSLog(@"passed first if in adjusting exposure");
    if ([[change objectForKey:NSKeyValueChangeNewKey] intValue]==0 && device.exposureMode!=AVCaptureExposureModeLocked) {
        NSLog(@"locking exposure");
        
        NSError * error;
        [self.device lockForConfiguration:&error];
        [device setExposureMode:AVCaptureExposureModeLocked];
        [self.device unlockForConfiguration];
    }
    //}
}
- (IBAction)startTimelapse:(id)sender {
    secondsTillCapture = captureInterval;
    currentFrame = 1;
    [_frameStatus setText:[NSString stringWithFormat:@"Frame: %d/%d",currentFrame,numberOfFrames]];
    [_timerStatus setText:[NSString stringWithFormat:@"Seconds until frame: %d",secondsTillCapture]];
    timelapseTimer = [ NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTime) userInfo:nil repeats:YES];
    
   
}
- (void) updateTime{
    secondsTillCapture-=1;
    [_timerStatus setText:[NSString stringWithFormat:@"Seconds until frame: %d",secondsTillCapture]];
    if(secondsTillCapture ==0)
    {
        UInt8 buf[3] = {0x00, 0x01, 0x01};
        NSData *data = [[NSData alloc] initWithBytes:buf length:3];
        [ble write:data];
        
        [self performSelector:@selector(snap) withObject:nil afterDelay:.5];
        currentFrame+=1;
        if(currentFrame <=numberOfFrames)
        {
            secondsTillCapture = captureInterval;
            
            [_frameStatus setText:[NSString stringWithFormat:@"Frame: %d/%d",currentFrame,numberOfFrames]];
            [_timerStatus setText:[NSString stringWithFormat:@"Seconds until frame: %d",secondsTillCapture]];
        }
        else{
            [timelapseTimer invalidate];
            [_frameStatus setText:[NSString stringWithFormat:@"Frame: 0/0"]];
            [_timerStatus setText:[NSString stringWithFormat:@"Seconds until frame: N/A"]];
        }
    }
}
- (IBAction)toggleLED:(id)sender {
    NSLog(@"In the toggle LED action");
    UInt8 buf[3] = {0x01, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
}
- (IBAction)toggleBF:(id)sender{
    NSLog(@"In the toggle BF action");
    UInt8 buf[3] = {0x02, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
}

- (IBAction)singleSnap:(id)sender {
    UInt8 buf[3] = {0x00, 0x01, 0x01};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
    
    [self performSelector:@selector(snap) withObject:nil afterDelay:.5];
    
}

- (IBAction)handlePan:(UIPanGestureRecognizer *)panGesture  {
    
    if ([panGesture state] == UIGestureRecognizerStateBegan) {
        NSLog(@"pan gesture began");
        
    }
    
    if ([panGesture state] == UIGestureRecognizerStateEnded) {
        NSLog(@"pan gesture ended");
        // and now handle it ;)
    }
    
}


- (void)eventHandler: (NSNotification *)notification
{
    NSLog(@"notification from analysis");
    if (processor.exposureMode==4) {
        flatImage=processor.outUIImage;
    }
}

#pragma mark - Timer-Related Methods

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setPreview:nil];
    //[self setLongPress:nil];
    //[self setPanGesture:nil];
    [super viewDidUnload];
}


@end


