#import "CropSquareImagePlugin.h"

@implementation CropSquareImagePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"crop_square_image"
            binaryMessenger:[registrar messenger]];
  CropSquareImagePlugin* instance = [[CropSquareImagePlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"getCurrentTemperature" isEqualToString:call.method]) {
      result(@"23.4 degrees");
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
