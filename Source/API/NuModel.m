//
//  NuModel.m
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/15/14.
//
//

#import "NuModel.h"
#import "NuModel_Internal.h"
#import "CBLModelArray.h"
#import "CBLJSON.h"
#import "CBLBase64.h"


// Prefix appended to synthesized property ivars by CBLSynthesize.
#define kIvarPrefixStr "_doc_"


// Returns the selector of the setter method for the given property.
static SEL selectorOfSetter(objc_property_t prop) {
    char* customSetter = property_copyAttributeValue(prop, "S");
    if (customSetter) {
        SEL result = sel_registerName(customSetter);
        free(customSetter);
        return result;
    } else {
        const char* name = property_getName(prop);
        char setterName[strlen(name)+1+3+1];
        strcpy(setterName, "set");
        strcat(setterName, name);
        strcat(setterName, ":");
        setterName[3] = (char)toupper(setterName[3]);
        return sel_registerName(setterName);
    }
}

// Returns the address of an instance variable.
static inline void* ivarAddress(id object, Ivar ivar) {
    return ((char*)(__bridge CFTypeRef)object + ivar_getOffset(ivar));
}



@implementation NuModelPropertyInfo

- (NSString*) description {
    return [NSString stringWithFormat: @"[%@.%@ <- doc.%@ ('%s')]",
            definedInClass, name, docProperty, ivarType];
}

- (Class) propertyClass {
    if (!_propertyClass && ivarType[0] == '@') {
        NSString* className = [[NSString alloc] initWithBytes: ivarType+2
                                                       length: strlen(ivarType)-3
                                                     encoding: NSUTF8StringEncoding];
        _propertyClass = NSClassFromString(className);
        Assert(_propertyClass);
    }
    return _propertyClass;
}

@end




@implementation NuModel
{
    uint64_t _dirtyFlags;    // Bit-field that marks which properties (by index) have been changed
}


@synthesize documentID=_documentID, needsSave=_needsSave;
#if DEBUG
@synthesize dirtyFlags=_dirtyFlags;
#endif


// Maps Class object -> NSArray of NuModelPropertyInfo
static NSMutableDictionary* sClassInfo;


#define SETTER_BLOCK(OLD_IMP, FLAG, TYPE) \
    ^void(__unsafe_unretained NuModel* receiver, TYPE value) { \
        if (!receiver->_dirtyFlags) [receiver setNeedsSave: YES]; \
        receiver->_dirtyFlags |= (FLAG); \
        void (*_oldSetter)(NuModel* rcvr, SEL cmd, TYPE value) = (void*)(OLD_IMP); \
        _oldSetter(receiver, setterSelector, value); \
    }


+ (void) initialize {
    if (self == [NuModel class]) {
        sClassInfo = [[NSMutableDictionary alloc] init];
        return;
    }

    NuModelPropertyInfo* prevProperty = [[[self superclass] persistentPropertyInfo] lastObject];
    uint8_t propertyIndex = prevProperty ? prevProperty->index+1 : 0;

    NSMutableArray* infos = $marray();
    objc_property_t* props = class_copyPropertyList(self, NULL);
    if (props) {
        for (objc_property_t* prop = props; *prop; ++prop) {
            Log(@"    %s -> %s", property_getName(*prop), property_getAttributes(*prop));
            const char* ivarName = property_copyAttributeValue(*prop, "V");
            if (ivarName) {
                if (strncmp(ivarName, kIvarPrefixStr, strlen(kIvarPrefixStr)) == 0) {
                    // Record info for this persistent property:
                    const char* docPropName = ivarName + strlen(kIvarPrefixStr);
                    NuModelPropertyInfo* info = [[NuModelPropertyInfo alloc] init];
                    info->index = propertyIndex;
                    info->definedInClass = self;
                    info->name = [[NSString alloc] initWithUTF8String: property_getName(*prop)];
                    info->docProperty = [[NSString alloc] initWithUTF8String: docPropName];
                    info->ivar = class_getInstanceVariable(self, ivarName);
                    info->ivarType = ivar_getTypeEncoding(info->ivar);
                    [infos addObject: info];

                    // Splice in a new setter method that records which property changed:
                    char* ro = property_copyAttributeValue(*prop, "R");
                    if (ro) {
                        info->readOnly = YES;
                        free(ro);
                    } else {
                        uint64_t dirtyMask = 1llu << MIN(propertyIndex, 63u);
                        SEL setterSelector = selectorOfSetter(*prop);
                        Method method = class_getInstanceMethod(self, setterSelector);
                        Assert(method);
                        IMP oldSetter = method_getImplementation(method);
                        id setter;
                        switch (info->ivarType[0]) {
                            case 'f':   setter = SETTER_BLOCK(oldSetter, dirtyMask, float); break;
                            case 'd':   setter = SETTER_BLOCK(oldSetter, dirtyMask, double); break;
                            default:    setter = SETTER_BLOCK(oldSetter, dirtyMask, void*); break;
                        }
                        method_setImplementation(method, imp_implementationWithBlock(setter));
                    }
                    propertyIndex++;
                }
                free((void*)ivarName);
            }
        }
        free(props);
    }

    @synchronized(self) {
        sClassInfo[(id)self] = infos;
    }
}


+ (NSArray*) persistentPropertyInfo {
    @synchronized(self) {
        return sClassInfo[(id)self];
    }
}


// Called from spliced-in property setter the first time a persistent property is changed.
- (void) setNeedsSave:(BOOL)needsSave {
    _needsSave = needsSave;
    if (needsSave)
        Log(@"*** %@ is now dirty", self);
    else
        _dirtyFlags = 0;
}


// Calls the block once for each persistent property, including inherited ones
+ (void) forEachProperty: (void (^)(NuModelPropertyInfo*))block {
    if (self != [NuModel class]) {
        [[self superclass] forEachProperty: block];
        for (NuModelPropertyInfo* info in [self persistentPropertyInfo])
            block(info);
    }
}


// Convert a value from raw JSON-parsed form into the type of the given property
- (id) internalizeValue: (id)rawValue forProperty: (NuModelPropertyInfo*)info {
    Class propertyClass = info.propertyClass;
    if (!propertyClass) {
        // Scalar property. It must have an NSNumber value:
        return $castIf(NSNumber, rawValue);
    } else if (propertyClass == [NSData class])
        return [CBLBase64 decode: rawValue];
    else if (propertyClass == [NSDate class])
        return [CBLJSON dateWithJSONObject: rawValue];
    else if (propertyClass == [NSDecimalNumber class]) {
        if (![rawValue isKindOfClass: [NSString class]])
            return nil;
        return [NSDecimalNumber decimalNumberWithString: rawValue];
    } else if ([rawValue isKindOfClass: propertyClass]) {
        return rawValue;
    } else {
        return nil;
    }
}


// Convert a value to JSON-compatible form
- (id) externalizeValue: (id)value {
    if ([value isKindOfClass: [NSData class]])
        value = [CBLBase64 encode: value];
    else if ([value isKindOfClass: [NSDate class]])
        value = [CBLJSON JSONObjectWithDate: value];
    else if ([value isKindOfClass: [NSDecimalNumber class]])
        value = [value stringValue];
    else if ([value isKindOfClass: [NuModel class]])
        value = ((NuModel*)value).documentID;
    else if ([value isKindOfClass: [NSArray class]]) {
        if ([value isKindOfClass: [CBLModelArray class]])
            value = [value docIDs];
        else
            value = [value my_map:^id(id obj) { return [self externalizeValue: obj]; }];
    } else if ([value conformsToProtocol: @protocol(CBLJSONEncoding)]) {
        value = [(id<CBLJSONEncoding>)value encodeAsJSON];
    }
    return value;
}


- (id) persistentValueOfProperty: (NuModelPropertyInfo*)info {
    id value = _box(ivarAddress(self, info->ivar), info->ivarType);
    if (info->ivarType[0] == '@')
        value = [self externalizeValue: value];
    else if ([value doubleValue] == 0.0)
        value = nil;
    return value;
}


#define SETTER(TYPE, METHOD) \
    { TYPE v = (TYPE)[value METHOD]; \
      memcpy(dst, &v, sizeof(v)); }

- (void) setPersistentProperties: (NSDictionary*)properties {
    [[self class] forEachProperty:^(NuModelPropertyInfo *info) {
        id value = properties[info->docProperty];
        value = [self internalizeValue: value forProperty: info];
        if (info->ivarType[0] == '@') {
            object_setIvar(self, info->ivar, value);
        } else {
            void* dst = ivarAddress(self, info->ivar);
            switch (info->ivarType[0]) {
                case 'B':   SETTER(bool,    boolValue); break;
                case 'c':
                case 'C':   SETTER(char,    charValue); break;
                case 's':
                case 'S':   SETTER(short,   shortValue); break;
                case 'i':
                case 'I':   SETTER(int,     intValue); break;
                case 'l':
                case 'L':   SETTER(int32_t, intValue); break;
                case 'q':
                case 'Q':   SETTER(int64_t, longLongValue); break;
                case 'f':   SETTER(float,   floatValue); break;
                case 'd':   SETTER(double,  doubleValue); break;
                default:
                    Assert(NO, @"Can't set ivar of type '%s' in %@", info->ivarType, info);
                    break;
            }
        }
    }];
}


- (NSDictionary*) persistentProperties {
    NSMutableDictionary* properties = $mdict();
    [[self class] forEachProperty:^(NuModelPropertyInfo *info) {
        id value = [self persistentValueOfProperty: info];
        if (value)
            properties[info->docProperty] = value;
    }];
    return properties;
}


- (BOOL) updatePersistentProperties: (NSMutableDictionary*)properties {
    __block BOOL changed = NO;
    [[self class] forEachProperty:^(NuModelPropertyInfo *info) {
        uint64_t dirtyMask = 1llu << MIN(info->index, 63u);
        if (_dirtyFlags & dirtyMask) {
            id value = [self persistentValueOfProperty: info];
            if (!$equal(value, properties[info->docProperty])) {
                [properties setValue: value forKey: info->docProperty];
                changed = YES;
            }
        }
    }];
    return changed;
}


@end
