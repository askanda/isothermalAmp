//
//  ImageProcessor.m
//  EyeScope2
//
//  Created by Mike D'Ambrosio on 6/17/13.
//  Copyright (c) 2013 Mike D'Ambrosio. All rights reserved.
//

#import "ImageProcessor.h"
#import "UIImage+OpenCV.h"


@implementation ImageProcessor
@synthesize outUIImage;
@synthesize images;
@synthesize exposureMode;


-(id)init
{
    self=[super init];
    if (self!=nil){
        images = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) addImage: (UIImage *) image{
    [images addObject:image];
    NSUInteger numObjects = [images count];
    if (numObjects==1){
        [self processImage];
    }
    
    
}

- (void)processImage
{
    //image processing code
    
}


- (void)thisImage:(UIImage *)image hasBeenSavedInPhotoAlbumWithError:(NSError *)error usingContextInfo:(void*)ctxInfo {
    if (error) {
        NSLog(@"error saving image");
        
        // Do anything needed to handle the error or display it to the user
    } else {
        NSLog(@"image saved in photo album");
        
        // .... do anything you want here to handle
        // .... when the image has been saved in the photo album
    }
}


@end
