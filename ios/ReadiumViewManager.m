#import "React/RCTViewManager.h"

@interface RCT_EXTERN_MODULE(ReadiumViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(file, NSDictionary *)
RCT_EXPORT_VIEW_PROPERTY(location, NSDictionary *)
RCT_EXPORT_VIEW_PROPERTY(settings, NSDictionary *)
RCT_EXPORT_VIEW_PROPERTY(highlights, NSArray *)
RCT_EXPORT_VIEW_PROPERTY(onLocationChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onTableOfContents, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onTranslate, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onShowHighlight, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDeleteHighlight, RCTDirectEventBlock)

@end
