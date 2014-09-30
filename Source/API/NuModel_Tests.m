//
//  NuModel_Tests.m
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/17/14.
//
//

#import "CBLObject_Internal.h"
#import "CBLNuModel.h"
#import "CBLNuModelFactory.h"
#import "CBLQueryRowModel.h"
#import "CouchbaseLite.h"
#import "CBLInternal.h"
#import "CouchbaseLitePrivate.h"
#import "CBLJSON.h"
#import "CBJSONEncoder.h"


#if DEBUG


static CBLDatabase* createEmptyDB(void) {
    NSError* error;
    CBLDatabase* db = [[CBLManager sharedInstance] createEmptyDatabaseNamed: @"numodel_test_db"
                                                                      error: &error];
    CAssert(db, @"Couldn't create test_db: %@", error);
    AfterThisTest(^{
        [db _close];
    });
    return db;
}


static CBLDocument* createDocumentWithProperties(CBLDatabase* db,
                                                 NSDictionary* properties) {
    CBLDocument* doc = [db createDocument];
    NSError* error;
    CAssert([doc putProperties: properties error: &error], @"Couldn't save: %@", error);  // save it!
    return doc;
}


@interface CBLObjectTest : CBLObject
@property (getter=isBool,setter=setIsBool:) bool aBool;
@property BOOL aBOOL;
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

@implementation CBLObjectTest
CBLSynthesizeAs(aBool, bool);
CBLSynthesize(aBOOL);
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
    return [[CBJSONEncoder canonicalEncoding: obj error: NULL] my_UTF8ToString];
}

static NSDictionary* dirtyProperties(CBLObject* m) {
    NSMutableDictionary* dirty = $mdict();
    return [m getPersistentPropertiesInto: dirty] ? dirty : nil;
}


TestCase(CBLObject) {
    NSArray* info = [CBLObjectTest persistentPropertyInfo];
    Log(@"Info = %@", info);

    Log(@"---- Initializing a model");
    CBLObjectTest* m = [[CBLObjectTest alloc] init];
    m.aBool = true;
    m.aBOOL = YES;
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
    AssertEqual(persistentProperties, (@{@"double":@3.141592653589793, @"int":@1337, @"ushort":@65432, @"string":@"frood", @"float":@3.14159, @"long":@-123456789876543, @"char":@-123, @"short":@32767, @"uint":@123456789, @"ulong":@123456789876543, @"uchar":@234, @"bool":@YES, @"aBOOL": @YES}));
    AssertEqual(jsonString(persistentProperties), @"{\"aBOOL\":true,\"bool\":true,\"char\":-123,\"double\":3.141592653589793,\"float\":3.14159,\"int\":1337,\"long\":-123456789876543,\"short\":32767,\"string\":\"frood\",\"uchar\":234,\"uint\":123456789,\"ulong\":123456789876543,\"ushort\":65432}");
    Log(@"Dirty = %llx", m.dirtyFlags);
    Assert(m.needsSave);
    AssertEq(m.dirtyFlags, 0x01FFFllu);

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
    AssertEq(m.dirtyFlags, 0x10llu);
    Log(@"Dirty Properties = %@", jsonString(dirtyProperties(m)));
    Assert(m.needsSave);
    AssertEq(m.anInt, -2468);

    Log(@"---- Making a no-op change:");
    NSMutableDictionary* properties = [m.persistentProperties mutableCopy];
    m.needsSave = NO;
    m.anInt = -2468; // no-op change
    Log(@"Dirty = %llx", m.dirtyFlags);
    Assert(![m getPersistentPropertiesInto: properties]);

    Log(@"---- Set double-valued property");
    m.needsSave = NO;
    m.aDouble = 25.25;
    Log(@"Dirty = %llx", m.dirtyFlags);
    Log(@"Dirty Properties = %@", jsonString(dirtyProperties(m)));
    Assert(m.needsSave);
    AssertEq(m.aDouble, 25.25);
}


#pragma mark - MODEL



@interface TestNuModel : CBLNuModel
@property (copy) NSString* greeting;
@property float size;
@property TestNuModel* other;
@end

@implementation TestNuModel

CBLSynthesize(greeting);
CBLSynthesize(size);
CBLSynthesize(other);

@end



@interface TestModelSource : NSObject <CBLNuModelFactoryDelegate>
- (instancetype) initWithDictionary: (NSDictionary*)dict;
@end

@implementation TestModelSource
{
    NSMutableDictionary* _dict;
}

- (instancetype) initWithDictionary: (NSDictionary*)dict {
    self = [super init];
    if (self)
        _dict = [dict mutableCopy];
    return self;
}

- (BOOL) readPropertiesOfModel: (CBLNuModel*)model error:(NSError**)error {
    Log(@"READ %@", model);
    model.persistentProperties = _dict[model.documentID];
    return YES;
}

- (BOOL) savePropertiesOfModel: (CBLNuModel*)model error:(NSError**)error {
    Log(@"SAVE %@", model);
    _dict[model.documentID] = model.persistentProperties;
    return YES;
}

- (BOOL) savePropertiesOfModels: (NSSet*)models error:(NSError**)error {
    AssertAbstractMethod();
}

@end



TestCase(CBLNuModel) {
    RequireTestCase(CBLObject);

    CBLNuModelFactory* factory = [[CBLNuModelFactory alloc] init];
    factory.delegate = [[TestModelSource alloc] initWithDictionary: @{
        @"doc1": @{@"greeting": @"hello", @"size": @8.5, @"other": @"doc2"},
        @"doc2": @{@"greeting": @"bye", @"size": @14}
    }];

    NSError* error;
    TestNuModel* doc1 = (TestNuModel*) [factory modelWithDocumentID: @"doc1"
                                                            ofClass: [TestNuModel class]
                                                            asFault: NO
                                                              error: &error];
    Assert(doc1);
    Assert([doc1 isKindOfClass: [TestNuModel class]]);
    Assert(!doc1.isFault);
    AssertEqual(doc1.greeting, @"hello");
    AssertEq(doc1.size, 8.5);

    TestNuModel* doc2 = doc1.other;
    Assert(doc2);
    Assert(doc2.isFault);
    AssertEqual(doc2.greeting, @"bye");
    AssertEq(doc2.size, 14);
    Assert(!doc2.isFault);
}



@interface TestRow : CBLQueryRowModel
@property (readonly) int year;
@property (readonly) NSString* title;
@property (readonly) float rating;
@end

@implementation TestRow

CBLSynthesizeAs(year,   key0);
CBLSynthesizeAs(title,  key1);
CBLSynthesize(rating);

@end


TestCase(CBLQueryRowModel) {
    CBLDatabase* db = createEmptyDB();

    CBLView* view = [db viewNamed: @"vu"];
    [view setMapBlock: MAPBLOCK({
        emit(@[doc[@"year"], doc[@"title"]], @{@"rating": doc[@"rating"]});
    }) version: @"1"];

    createDocumentWithProperties(db, @{@"year": @1977, @"title": @"Star Wars", @"rating": @0.9});

    int rowCount = 0;
    CBLQuery* query = [view createQuery];
    for (CBLQueryRow* row in [query run: NULL]) {
        TestRow* testRow = [[TestRow alloc] initWithQueryRow: row];
        AssertEq(testRow.year, 1977);
        AssertEqual(testRow.title, @"Star Wars");
        AssertEq(testRow.rating, 0.9f);
        ++rowCount;
    }
    AssertEq(rowCount, 1);
}


#endif // DEBUG
