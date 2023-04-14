#import "React/RCTBridgeModule.h"

@interface RCT_EXTERN_MODULE(CoverImageModule, NSObject)

RCT_EXTERN_METHOD(
  getCoverImage: (NSString *)filePath
  guideWidth: (nonnull NSNumber *)guideWidth
  guideHeight: (nonnull NSNumber *)guideHeight
  resolve: (RCTPromiseResolveBlock)resolve
  rejector: (RCTPromiseRejectBlock)reject
)

@end