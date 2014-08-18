//
//  NuModel_Tests.m
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/17/14.
//
//

#import "NuModel_Internal.h"
#import "CBLJSON.h"


#if DEBUG


@interface TestNuModel : NuModel
@property (getter=isBool,setter=setIsBool:) bool aBool;
@property char aChar;
@property short aShort;
@property int anInt;
@property int64_t aLong;
@property uint8_t aUChar;
@property uint16_t aUShort;
@property unsigned aUInt;
@property uint64_t aULong;
@property float aFloat;
@property double aDouble;
@property (copy) NSString* str;
@property (readonly) int readOnly;

@property int synthesized;
@property (readonly) id ignore;
@end

@implementation TestNuModel
CBLSynthesizeAs(aBool, bool);
CBLSynthesizeAs(aChar, char);
CBLSynthesizeAs(aShort, short);
CBLSynthesizeAs(anInt, int);
CBLSynthesizeAs(aLong, long);
CBLSynthesizeAs(aUChar, uchar);
CBLSynthesizeAs(aUShort, ushort);
CBLSynthesizeAs(aUInt, uint);
CBLSynthesizeAs(aULong, ulong);
CBLSynthesizeAs(str, string);
CBLSynthesizeAs(aFloat, float);
CBLSynthesizeAs(aDouble, double);
CBLSynthesize(readOnly);
@synthesize synthesized;

- (id) ignore {return nil;}
@end


static NSString* jsonString(id obj) {
    return [CBLJSON stringWithJSONObject: obj options: 0 error: NULL];
}

static NSDictionary* dirtyProperties(NuModel* m) {
    NSMutableDictionary* dirty = $mdict();
    return [m updatePersistentProperties: dirty] ? dirty : nil;
}


TestCase(NuModel) {
    NSArray* info = [TestNuModel persistentPropertyInfo];
    Log(@"Info = %@", info);

    Log(@"---- Initializing a model");
    TestNuModel* m = [[TestNuModel alloc] init];
    m.aBool = true;
    m.aChar = -123;
    m.aUChar = 234;
    m.aShort = 32767;
    m.aUShort = 65432;
    m.anInt = 1337;
    m.aUInt = 123456789;
    m.aLong = -123456789876543;
    m.aULong = 123456789876543;
    m.aFloat = 3.14159f;
    m.aDouble = M_PI;
    m.synthesized = 1;
    m.str = @"frood";

    Log(@"---- Testing properties");
    NSDictionary* persistentProperties = m.persistentProperties;
    Log(@"Properties = %@", jsonString(persistentProperties));
    AssertEqual(persistentProperties, (@{@"double":@3.141592653589793,@"int":@1337,@"ushort":@65432,@"string":@"frood",@"float":@3.14159,@"long":@-123456789876543,@"char":@-123,@"short":@32767,@"uint":@123456789,@"ulong":@123456789876543,@"uchar":@234,@"bool":@YES}));
    Log(@"Dirty = %llx", m.dirtyFlags);
    Assert(m.needsSave);
    AssertEq(m.dirtyFlags, 0x0FFFllu);

    [m setPersistentProperties: @{@"float": @1.414}];
    Log(@"m.aFloat = %g", m.aFloat);
    AssertEq(m.aDouble, 0.0);
    persistentProperties = m.persistentProperties;
    Log(@"Properties = %@", jsonString(persistentProperties));
    AssertEqual(persistentProperties, (@{@"float":@1.414}));

    Log(@"---- m.anInt = -2468");
    m.needsSave = NO;
    m.anInt = -2468;
    Log(@"Dirty = %llx", m.dirtyFlags);
    AssertEq(m.dirtyFlags, 8llu);
    Log(@"Dirty Properties = %@", jsonString(dirtyProperties(m)));
    Assert(m.needsSave);
    AssertEq(m.anInt, -2468);

    Log(@"---- Making a no-op change:");
    NSMutableDictionary* properties = [m.persistentProperties mutableCopy];
    m.needsSave = NO;
    m.anInt = -2468; // no-op change
    Log(@"Dirty = %llx", m.dirtyFlags);
    Assert(![m updatePersistentProperties: properties]);

    Log(@"---- Set double-valued property");
    m.needsSave = NO;
    m.aDouble = 25.25;
    Log(@"Dirty = %llx", m.dirtyFlags);
    Log(@"Dirty Properties = %@", jsonString(dirtyProperties(m)));
    Assert(m.needsSave);
    AssertEq(m.aDouble, 25.25);
}

#endif // DEBUG
