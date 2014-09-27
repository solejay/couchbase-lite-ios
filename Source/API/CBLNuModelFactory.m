//
//  CBLNuModelFactory.m
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/18/14.
//
//

#import "CBLNuModelFactory.h"
#import "CBLCache.h"


@interface CBLNuModel (Cacheable) <CBLCacheable>
@end

@implementation CBLNuModel (Cacheable)
- (NSString*) cacheKey {
    return self.documentID;
}
@end




@implementation CBLNuModelFactory
{
    CBLCache* _cache;
}


@synthesize delegate=_delegate, unsavedModels=_unsavedModels;


- (instancetype)init
{
    self = [super init];
    if (self) {
        _cache = [[CBLCache alloc] initWithRetainLimit: 20];
        _unsavedModels = [[NSMutableSet alloc] init];
    }
    return self;
}


- (CBLNuModel*) modelWithDocumentID: (NSString*)documentID
                            ofClass: (Class)ofClass
                            asFault: (BOOL)asFault
                              error: (NSError**)outError
{
    CBLNuModel* model = [_cache resourceWithCacheKey: documentID];
    if (!model) {
        if (asFault)
            model = [[ofClass alloc] initAsFaultWithFactory: self documentID: documentID];
        else
            model = [self createModelWithDocumentID: documentID ofClass: ofClass error: outError];
        if (!model)
            return nil;
        [_cache addResource: model];
    }
    Assert(!ofClass || model.isFault || [model isKindOfClass: ofClass],
           @"Asked for model of doc %@ as a %@, but it's already instantiated as a %@",
           documentID, ofClass, [model class]);
    return model;
}


- (CBLNuModel*) existingModelWithDocumentID: (NSString*)documentID {
    CBLNuModel* model = [_cache resourceWithCacheKey: documentID];
    if (model.isFault)
        return nil;
    return model;
}


- (CBLNuModel*) createModelWithDocumentID: (NSString*)documentID
                                  ofClass: (Class)ofClass
                                    error: (NSError**)outError
{
    CBLNuModel* model = [[ofClass alloc] initWithFactory: self documentID: documentID];
    if (![self readPropertiesOfModel: model error: outError])
        return nil;
    return model;
}


- (void) addNewModel: (CBLNuModel*)model {
    [_cache addResource: model];
}


- (BOOL) saveAllModels: (NSError**)outError {
    Assert(_delegate);
    return [_delegate savePropertiesOfModels: _unsavedModels error: outError];
}

- (BOOL) autosaveAllModels: (NSError**)outError {
    Assert(_delegate);
    return [_delegate savePropertiesOfModels: _unsavedModels error: outError];
    //FIX: This should filter by models that have autosave enabled
}

- (BOOL) readPropertiesOfModel: (CBLNuModel*)model error: (NSError**)error {
    Assert(_delegate);
    return [_delegate readPropertiesOfModel: model error: error];
}

- (BOOL) savePropertiesOfModel: (CBLNuModel*)model error: (NSError**)error {
    Assert(_delegate);
    return [_delegate savePropertiesOfModel: model error: error];
}


@end



#import "CBLDatabase+Internal.h"
#import "CBLDatabase+Insertion.h"


@interface CBLDatabase (ModelFactory) <CBLNuModelFactoryDelegate>

@end


@implementation CBLDatabase (ModelFactory)


- (BOOL) readPropertiesOfModel: (CBLNuModel*)model error: (NSError**)outError {
    CBLStatus status;
    CBL_Revision* rev = [self getDocumentWithID: model.documentID
                                     revisionID: nil
                                        options: 0
                                         status: &status];
    if (!rev && status != kCBLStatusNotFound) {
        if (outError)
            *outError = CBLStatusToNSError(status, nil);
        return NO;
    }
    [model readFromRevision: rev];
    return YES;
}


- (BOOL) savePropertiesOfModel: (CBLNuModel*)model error: (NSError**)outError {
    CBL_MutableRevision* rev = [[CBL_MutableRevision alloc] initWithDocID: model.documentID
                                                                    revID: model.revisionID
                                                                  deleted: NO];
    rev.properties = model.persistentProperties;
    CBLStatus status;
    CBL_Revision* nuRev = [self putRevision: rev
                             prevRevisionID: model.revisionID
                              allowConflict: NO
                                     status: &status];
    if (!nuRev) {
        if (outError)
            *outError = CBLStatusToNSError(status, nil);
        return NO;
    }
    return YES;
}


- (BOOL) savePropertiesOfModels: (NSSet*)models error: (NSError**)outError {
    return [self inTransaction: ^BOOL{
        for (CBLNuModel* model in models) {
            if (![self savePropertiesOfModel: model error: outError])
                return NO;
        }
        return YES;
    }];
}


@end
