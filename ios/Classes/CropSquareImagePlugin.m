#import "CropSquareImagePlugin.h"
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "UIImage+Resize.h"

@implementation CropSquareImagePlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"crop_square_image"
            binaryMessenger:[registrar messenger]];
  CropSquareImagePlugin* instance = [[CropSquareImagePlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSDictionary *_arguments;

  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    
  } else if ([@"getCurrentTemperature" isEqualToString:call.method]) {
      result(@"23.4 degrees");
    
  } else if ([@"cropImage" isEqualToString:call.method]) {
      NSString* path = (NSString*)call.arguments[@"path"];
      NSNumber* left = (NSNumber*)call.arguments[@"left"];
      NSNumber* top = (NSNumber*)call.arguments[@"top"];
      NSNumber* right = (NSNumber*)call.arguments[@"right"];
      NSNumber* bottom = (NSNumber*)call.arguments[@"bottom"];
      NSNumber* scale = (NSNumber*)call.arguments[@"scale"];
      CGRect area = CGRectMake(left.floatValue, top.floatValue,
                               right.floatValue - left.floatValue,
                               bottom.floatValue - top.floatValue);
      [self cropImage:path area:area scale:scale result:result];
    
  } else if ([@"cropImage2" isEqualToString:call.method]) {
    _arguments = call.arguments;
    NSString *file = [_arguments objectForKey:@"file"];
    int originX = [[_arguments objectForKey:@"originX"] intValue];
    int originY = [[_arguments objectForKey:@"originY"] intValue];
    int width = [[_arguments objectForKey:@"width"] intValue];
    int height = [[_arguments objectForKey:@"height"] intValue];
    [self cropImage2:file
             originX:originX
             originY:originY
               width:width
              height:height
              result:result];
    
  } else if ([@"scaleImage2" isEqualToString:call.method]) {
    _arguments = call.arguments;
    NSString *fileArgument = [_arguments objectForKey:@"file"];
    int qualityArgument = [[_arguments objectForKey:@"quality"] intValue];
    int percentageArgument = [[_arguments objectForKey:@"percentage"] intValue];
    int widthArgument = [[_arguments objectForKey:@"targetWidth"] intValue];
    int heightArgument = [[_arguments objectForKey:@"targetHeight"] intValue];
    [self scaleImage2:fileArgument
              quality:qualityArgument
           percentage:percentageArgument
                width:widthArgument
               height:heightArgument
               result:result];

  } else if ([@"getImageProperties" isEqualToString:call.method]) {
    NSString* file = (NSString*)call.arguments[@"file"];
    [self getImageProperties:file result:result];
    
  } else if ([@"getImageDimensions" isEqualToString:call.method]) {
      NSString* path = (NSString*)call.arguments[@"path"];
      [self getImageDimensions:path result:result];
    
  } else if ([@"requestPermissions" isEqualToString:call.method]){
      [self requestPermissionsWithResult:result];
    
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (UIImage *)imageRotatedByDegrees:(UIImage*)oldImage deg:(CGFloat)degrees{
  // calculate the size of the rotated view's containing box for our drawing space
  UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,oldImage.size.width, oldImage.size.height)];
  CGAffineTransform t = CGAffineTransformMakeRotation(degrees * M_PI / 180);
  rotatedViewBox.transform = t;
  CGSize rotatedSize = rotatedViewBox.frame.size;
  // Create the bitmap context
  UIGraphicsBeginImageContext(rotatedSize);
  CGContextRef bitmap = UIGraphicsGetCurrentContext();

  // Move the origin to the middle of the image so we will rotate and scale around the center.
  CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);

  //   // Rotate the image context
  CGContextRotateCTM(bitmap, (degrees * M_PI / 180));

  // Now, draw the rotated/scaled image into the context
  CGContextScaleCTM(bitmap, 1.0, -1.0);
  CGContextDrawImage(bitmap, CGRectMake(-oldImage.size.width / 2, -oldImage.size.height / 2, oldImage.size.width, oldImage.size.height), [oldImage CGImage]);

  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return newImage;
}

- (UIImage *)normalizedImage:(UIImage *)image {
  if (image.imageOrientation == UIImageOrientationUp) return image;
  
  UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
  [image drawInRect:(CGRect){0, 0, image.size}];
  UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return normalizedImage;
}

- (void)scaleImage2:(NSString *) file
            quality:(int) quality
         percentage:(int) percentage
              width:(int) width
             height:(int) height
             result:(FlutterResult) result {
  // do work on a different thread
  [self execute:^{
    NSString *fileExtension = @"_compressed.jpg";
    
    NSURL *uncompressedFileUrl = [NSURL URLWithString:file];
    
    NSString *fileName = [[file lastPathComponent] stringByDeletingPathExtension];
    NSString *tempFileName =  [fileName stringByAppendingString:fileExtension];
    NSString *finalFileName = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
    
    NSString *path = [uncompressedFileUrl path];
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
    
    UIImage *img = [[UIImage alloc] initWithData:data];
    
    CGFloat newWidth = (width == 0 ? (img.size.width / 100 * percentage) : width);
    CGFloat newHeight = (height == 0 ? (img.size.height / 100 * percentage) : height);
    
    CGSize newSize = CGSizeMake(newWidth, newHeight);
    
    UIImage *resizedImage = [img resizedImage:newSize interpolationQuality:kCGInterpolationHigh];
    resizedImage = [self normalizedImage:resizedImage];
    NSData *imageData = UIImageJPEGRepresentation(resizedImage, quality / 100);
    
    if ([[NSFileManager defaultManager] createFileAtPath:finalFileName contents:imageData attributes:nil]) {
      result(finalFileName);
    } else {
      result([FlutterError errorWithCode:@"create_error"
                                 message:@"Temporary file could not be created"
                                 details:nil]);
    }
  }];
}

- (void)cropImage2:(NSString *) file
           originX:(int) originX
           originY:(int) originY
             width:(int) width
            height:(int) height
            result:(FlutterResult) result {
  // do work on a different thread
  [self execute:^{
    NSString *fileExtension = @"_cropped.jpg";
    NSURL *uncompressedFileUrl = [NSURL URLWithString:file];
    NSString *fileName = [[file lastPathComponent] stringByDeletingPathExtension];
    NSString *tempFileName =  [fileName stringByAppendingString:fileExtension];
    NSString *finalFileName = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
    
    NSString *path = [uncompressedFileUrl path];
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
    
    UIImage *img = [[UIImage alloc] initWithData:data];
    img = [self normalizedImage:img];
    
    if(originX<0 || originY<0
       || originX>img.size.width || originY>img.size.height
       || originX+width>img.size.width || originY+height>img.size.height) {
      result([FlutterError errorWithCode:@"bounds_error"
                                 message:@"Bounds are outside of the dimensions of the source image"
                                 details:nil]);
    }
    
    CGRect cropRect = CGRectMake(originX, originY, width, height);
    CGImageRef imageRef = CGImageCreateWithImageInRect([img CGImage], cropRect);
    UIImage *croppedImg = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    NSData *imageData = UIImageJPEGRepresentation(croppedImg, 1.0);
    
    if ([[NSFileManager defaultManager] createFileAtPath:finalFileName contents:imageData attributes:nil]) {
      result(finalFileName);
    } else {
      result([FlutterError errorWithCode:@"create_error"
                                 message:@"Temporary file could not be created"
                                 details:nil]);
    }
    
    result(finalFileName);
  }];
}

- (void)cropImage:(NSString*)path
             area:(CGRect)area
            scale:(NSNumber*)scale
           result:(FlutterResult)result {
    [self execute:^{
        NSURL* url = [NSURL fileURLWithPath:path];
        CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef) url, NULL);
        
        if (imageSource == NULL) {
            result([FlutterError errorWithCode:@"INVALID"
                                       message:@"Image source cannot be opened"
                                       details:nil]);
            return;
        }
        
        CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
        
        if (image == NULL) {
            result([FlutterError errorWithCode:@"INVALID"
                                       message:@"Image cannot be opened"
                                       details:nil]);
            CFRelease(imageSource);
            return;
        }
        
        size_t width = CGImageGetWidth(image);
        size_t height = CGImageGetHeight(image);
        size_t scaledWidth = (size_t) (width * area.size.width * scale.floatValue);
        size_t scaledHeight = (size_t) (height * area.size.height * scale.floatValue);
        size_t bitsPerComponent = CGImageGetBitsPerComponent(image);
        size_t bytesPerRow = CGImageGetBytesPerRow(image) / width * scaledWidth;
        CGImageAlphaInfo bitmapInfo = CGImageGetAlphaInfo(image);
        CGColorSpaceRef colorspace = CGImageGetColorSpace(image);
        
        CGImageRef croppedImage = CGImageCreateWithImageInRect(image,
                                                               CGRectMake(width * area.origin.x,
                                                                          height * area.origin.y,
                                                                          width * area.size.width,
                                                                          height * area.size.height));
        
        CFRelease(image);
        CFRelease(imageSource);
        
        if (scale.floatValue != 1.0) {
            CGContextRef context = CGBitmapContextCreate(NULL,
                                                         scaledWidth,
                                                         scaledHeight,
                                                         bitsPerComponent,
                                                         bytesPerRow,
                                                         colorspace,
                                                         bitmapInfo);
            
            if (context == NULL) {
                result([FlutterError errorWithCode:@"INVALID"
                                           message:@"Image cannot be scaled"
                                           details:nil]);
                CFRelease(croppedImage);
                return;
            }
            
            CGRect rect = CGContextGetClipBoundingBox(context);
            CGContextDrawImage(context, rect, croppedImage);
            
            CGImageRef scaledImage = CGBitmapContextCreateImage(context);
            
            CGContextRelease(context);
            CFRelease(croppedImage);
            
            croppedImage = scaledImage;
        }
        // Rotate image 90 degrees clockwise
        UIImage *tempImage = [[UIImage alloc]initWithCGImage:croppedImage];
        UIImage *rotatedImage = [self imageRotatedByDegrees:tempImage deg:90];
        
        // Generate a unique file name in a temporary location
        NSURL* croppedUrl = [self createTemporaryImageUrl];
        
        // Compress file to a size less than 0.2MB
        NSData *data = [self compressImage:rotatedImage maxLength:200000];
        
        // Save file
        bool saved = [data writeToURL:croppedUrl atomically:NO];
        //bool saved = [self saveImage:rotatedImage.CGImage url:croppedUrl];
        CFRelease(croppedImage);
        // Release memory used by UIImages. Maybe not necessary with ARC?
        tempImage = nil;
        rotatedImage = nil;
        
        if (saved) {
            result(croppedUrl.path);
        } else {
            result([FlutterError errorWithCode:@"INVALID"
                                       message:@"Cropped image cannot be saved"
                                       details:nil]);
        }
    }];
}

- (void)getImageProperties:(NSString *) file
                    result:(FlutterResult) result {
  [self execute:^{
    NSURL* url = [NSURL fileURLWithPath:file];
    CGImageSourceRef image = CGImageSourceCreateWithURL((CFURLRef) url, NULL);
    
    if (image == NULL) {
      result([FlutterError errorWithCode:@"INVALID"
                                 message:@"Image source cannot be opened"
                                 details:nil]);
      return;
    }
    
    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil);
    CFRelease(image);
    
    if (properties == NULL) {
      result([FlutterError errorWithCode:@"INVALID"
                                 message:@"Image source properties cannot be copied"
                                 details:nil]);
      return;
    }
    
    NSNumber* width = (NSNumber*) CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
    NSNumber* height = (NSNumber*) CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
    CFRelease(properties);
    
    result(@{ @"width": @(lroundf([width floatValue])),  @"height": @(lroundf([height floatValue])) });
  }];
}

- (void)getImageDimensions:(NSString*)path result:(FlutterResult)result {
    [self execute:^{
        NSURL* url = [NSURL fileURLWithPath:path];
        CGImageSourceRef image = CGImageSourceCreateWithURL((CFURLRef) url, NULL);
        
        if (image == NULL) {
            result([FlutterError errorWithCode:@"INVALID"
                                       message:@"Image source cannot be opened"
                                       details:nil]);
            return;
        }
        
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil);
        CFRelease(image);
        
        if (properties == NULL) {
            result([FlutterError errorWithCode:@"INVALID"
                                       message:@"Image source properties cannot be copied"
                                       details:nil]);
            return;
        }
        
        NSNumber* width = (NSNumber*) CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
        NSNumber* height = (NSNumber*) CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
        CFRelease(properties);
        
        result(@{ @"width": width,  @"height": height });
    }];
}

- (void)requestPermissionsWithResult:(FlutterResult)result {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            result(@YES);
        } else {
            result(@NO);
        }
    }];
}

- (NSData *)compressImage:(UIImage *)image maxLength:(NSUInteger)maxLength {
    
    NSArray *compressionFactorArray = @[@0.01, @0.1, @0.25, @0.5, @0.75, @1.0];
    NSData *data = nil;
    NSData *previousData = nil;
    for (NSNumber *factor in compressionFactorArray) {
        data = UIImageJPEGRepresentation(image, [factor doubleValue]);
        NSLog(@"Size of photo data:%lu with compression factor:%f",(unsigned long)data.length, [factor doubleValue]);
        if (data.length > maxLength) {
            if (previousData) {
                data = previousData;
            }
            break;
        }
        previousData = data;
    }
    return data;
}

- (bool)saveImage:(CGImageRef)image url:(NSURL*)url {
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((CFURLRef) url, kUTTypeJPEG, 1, NULL);
    CGImageDestinationAddImage(destination, image, NULL);
    
    bool finilized = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    
    return finilized;
}

- (NSURL*)createTemporaryImageUrl {
    NSString* temproraryDirectory = NSTemporaryDirectory();
    NSString* guid = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString* sampleName = [[@"crop_square_image_" stringByAppendingString:guid] stringByAppendingString:@".jpg"];
    NSString* samplePath = [temproraryDirectory stringByAppendingPathComponent:sampleName];
    return [NSURL fileURLWithPath:samplePath];
}

- (void)execute:(void (^)(void))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}


@end
