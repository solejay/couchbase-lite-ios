//
//  NuModel_Internal.h
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/17/14.
//
//

#import "NuModel.h"
#import <objc/runtime.h>


@interface NuModelPropertyInfo : NSObject
{
@public
    Class definedInClass;       // Class that defines this property
    NSString* name;             // Property name
    NSString* docProperty;      // Document (JSON) property name
    Ivar ivar;                  // Obj-C instance variable
    const char* ivarType;       // Encoded ivar type string (a la @encode)
    uint8_t index;              // Order in which property was declared (starts at 0 in base class)
    BOOL readOnly;              // Read-only property?

@private
    Class _propertyClass;       // Property's class, if it's an object type
}

@property (readonly) Class propertyClass;

@end




@interface NuModel ()

+ (NSArray*) persistentPropertyInfo;

@property (readwrite) BOOL needsSave;

#if DEBUG
@property (readonly) uint64_t dirtyFlags;
#endif

@end

