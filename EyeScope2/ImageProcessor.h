//
//  ImageProcessor.h
//  EyeScope2
//
//  Created by Mike D'Ambrosio on 6/17/13.
//  Copyright (c) 2013 Mike D'Ambrosio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>


@interface ImageProcessor : NSObject
@property UIImage * outUIImage;
//@property double defect;
- (void)addImage:(UIImage*) image;
- (void)processImage;

@property (nonatomic, retain) NSMutableArray * images;
@property int exposureMode;

@end

