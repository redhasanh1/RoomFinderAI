#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(NativeAlertModule, NSObject)

RCT_EXTERN_METHOD(showNativeAlert:(NSString *)title
                  message:(NSString *)message
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(showActionSheet:(NSString *)title
                  message:(NSString *)message
                  options:(NSArray<NSString *> *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(showConfirmDialog:(NSString *)title
                  message:(NSString *)message
                  confirmText:(NSString *)confirmText
                  cancelText:(NSString *)cancelText
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getDeviceInfo:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(hapticFeedback:(NSString *)type
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end