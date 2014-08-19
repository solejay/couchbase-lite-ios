//
//  CBLObject_Internal.h
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/17/14.
//
//

#import "CBLObject.h"
#import <objc/runtime.h>


@interface CBLPropertyInfo : NSObject
{
@public
    Class definedInClass;       // Class that defines this property
    NSString* name;             // Property name
    NSString* docProperty;      // Document (JSON) property name
    objc_property_t property;   // Obj-C property metadata
    Ivar ivar;                  // Obj-C instance variable metadata
    const char* ivarType;       // Encoded ivar type string (a la @encode)
    uint8_t index;              // Order in which property was declared (starts at 0 in base class)
    BOOL readOnly;              // Read-only property?

@private
    Class _propertyClass;       // Property's class, if it's an object type
}

@property (readonly) Class propertyClass;

@end




@interface CBLObject ()

+ (NSArray*) persistentPropertyInfo;

+ (void) forEachProperty: (void (^)(CBLPropertyInfo*))block;

@property (readwrite) BOOL needsSave;

#if DEBUG
@property (readonly) uint64_t dirtyFlags;
#endif

- (id) internalizeValue: (id)rawValue forProperty: (CBLPropertyInfo*)info;
- (id) externalizeValue: (id)value;

@end




SEL selectorOfGetter(objc_property_t prop);
SEL selectorOfSetter(objc_property_t prop);
