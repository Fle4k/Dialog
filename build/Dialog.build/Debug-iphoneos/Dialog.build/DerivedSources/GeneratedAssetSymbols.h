#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "PersonIcon_Light_rounded" asset catalog image resource.
static NSString * const ACImageNamePersonIconLightRounded AC_SWIFT_PRIVATE = @"PersonIcon_Light_rounded";

/// The "metame_Logo" asset catalog image resource.
static NSString * const ACImageNameMetameLogo AC_SWIFT_PRIVATE = @"metame_Logo";

#undef AC_SWIFT_PRIVATE
