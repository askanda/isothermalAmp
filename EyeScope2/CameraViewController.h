//
//  CameraViewController.h
//  EyeScope2
//
//  Created by Mike D'Ambrosio on 12/13/12.
//  Copyright (c) 2012 Mike D'Ambrosio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "BLE.h"
#import "ImageProcessor.h"


@interface CameraViewController : UIViewController  <BLEDelegate>
{
    NSTimer *timelapseTimer;

}
@property (strong, nonatomic) IBOutlet UILabel *sensorDisplayLabel;
@property (weak, nonatomic) IBOutlet UILabel *frameStatus;
@property (weak, nonatomic) IBOutlet UILabel *timerStatus;
//@property (weak, nonatomic) IBOutlet UIView *preview;
//@property (weak, nonatomic) IBOutlet UIImageView * preview;
@property (weak, nonatomic) IBOutlet UIView *preview;
//@property (strong, nonatomic) IBOutlet UILongPressGestureRecognizer *longPress;
@property (strong, nonatomic) IBOutlet UIRotationGestureRecognizer *handleRotate;
- (IBAction)handleLongPress:(UILongPressGestureRecognizer *) longPress;
//@property (weak, nonatomic) IBOutlet UIButton *snap;
- (IBAction)handlePinch:(UIPinchGestureRecognizer *)recognizer;
//@property (strong, nonatomic) IBOutlet UIPanGestureRecognizer *panGesture;
- (IBAction)handlePan:(UIPanGestureRecognizer *)panGesture;
@property (strong, nonatomic) IBOutlet UIRotationGestureRecognizer *handleRot;
@property (weak, nonatomic) IBOutlet UIButton *toggleLED;
@property (weak, nonatomic) IBOutlet UIButton *toggleBF;
@property (weak, nonatomic) IBOutlet UIButton *singleSnap;
@property (weak, nonatomic) IBOutlet UIButton *startTimelapse;
@property (strong, nonatomic) BLE *ble;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoPreviewOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoHDOutput;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillOutput;
@property NSData *imageData;
@property UIImage *image;
@property NSData *imageData2;
@property UIImage *image2;
@property NSData *imageData3;
@property UIImage *image3;
@property ImageProcessor* processor;
@property UIImage* flatImage;
@property UIImage* singleFlatImage;

@end
