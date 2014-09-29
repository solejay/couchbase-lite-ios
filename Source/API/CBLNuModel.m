//
//  CBLNuModel.m
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/18/14.
//
//

#import "CBLNuModel.h"
#import "CBLNuModelFactory.h"
#import "CBLObject_Internal.h"
#import "CBLMisc.h"
#import "CouchbaseLitePrivate.h"


@interface CBLNuModel ()
@property (readwrite) NSString* revisionID;
@property (readwrite) BOOL deleted;
@end




@implementation CBLNuModel
{
    BOOL _saving;
}


@synthesize factory=_factory, documentID=_documentID, revisionID=_revisionID, deleted=_deleted,
            isNew=_isNew;


+ (instancetype) modelWithFactory: (CBLNuModelFactory*)factory
                       documentID: (NSString*)documentID
{
    return [factory modelWithDocumentID: documentID ofClass: self asFault: NO error: nil];
}


- (instancetype) initWithFactory: (CBLNuModelFactory*)factory
                      documentID: (NSString*)documentID
{
    self = [super init];
    if (self) {
        _factory = factory;
        _documentID = documentID;
    }
    return self;
}


- (instancetype) initNewModelWithFactory: (CBLNuModelFactory*)factory {
    self = [super init];
    if (self) {
        _factory = factory;
        _documentID = CBLCreateUUID();
        _isNew = YES;
        [_factory addNewModel: self];
    }
    return self;
}


- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@]", self.class, _documentID];
}


// Convert a value from raw JSON-parsed form into the type of the given property
- (id) internalizeValue: (id)rawValue forProperty: (CBLPropertyInfo*)info {
    id value = [super internalizeValue: rawValue forProperty: info];
    if (!value) {
        Class propertyClass = info.propertyClass;
        if ([propertyClass isSubclassOfClass: [CBLNuModel class]]) {
            // Model-valued property:
            if (![rawValue isKindOfClass: [NSString class]])
                return nil;
            return [_factory modelWithDocumentID: rawValue
                                         ofClass: propertyClass
                                         asFault: YES
                                           error: nil];
        }
    }
    return value;
}


- (void) readFromRevision: (CBL_Revision*)rev {
    if (!_saving) {
        // Update ivars from revision, unless this is an echo of my saving myself:
        self.persistentProperties = rev.properties;
    }
    self.revisionID = rev.revID;
    self.deleted = rev.deleted;
}


#pragma mark - SAVING:


- (void) setNeedsSave: (BOOL)needsSave {
    if (needsSave != super.needsSave) {
        [super setNeedsSave: needsSave];
        NSMutableSet* unsaved = _factory.unsavedModels;
        if (needsSave)
            [unsaved addObject: self];
        else
            [unsaved removeObject: self];
    }
}


// Internal version of -save: that doesn't invoke -didSave
- (BOOL) justSave: (NSError**)outError {
    if (!self.needsSave)
        return YES; // no-op
    BOOL ok;
    _saving = true;
    @try {
        ok = [_factory savePropertiesOfModel: self error: outError];
    } @finally {
        _saving = false;
    }
    return ok;
}


- (void) didSave {
    _isNew = NO;
    self.needsSave = NO;
}


- (BOOL) save: (NSError**)outError {
    BOOL ok = [self justSave: outError];
    if (ok)
        [self didSave];
    return ok;
}


#pragma mark - FAULTS:


- (void) awokeFromFault {
    [super awokeFromFault];
    NSError* error;
    if (![_factory readPropertiesOfModel: self error: nil])
        Warn(@"Error reading %@ from fault: %@", self, error);
}


@end
