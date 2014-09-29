//
//  CBLNuModel.h
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/18/14.
//
//

#import "CBLObject.h"
@class CBLNuModelFactory, CBL_Revision;


/** Abstract model object that represents a Couchbase Lite document in memory. */
@interface CBLNuModel : CBLObject

+ (instancetype) modelWithFactory: (CBLNuModelFactory*)factory
                       documentID: (NSString*)documentID;

- (instancetype) initNewModelWithFactory: (CBLNuModelFactory*)factory;

@property (readonly, nonatomic) CBLNuModelFactory* factory;

@property (readonly, nonatomic) NSString* documentID;
@property (readonly, nonatomic) NSString* revisionID;
@property (readonly, nonatomic) BOOL deleted;

@property (readonly, nonatomic) BOOL isNew;

/** Writes any changes to a new revision of the document.
    Returns YES without doing anything, if no changes have been made. */
- (BOOL) save: (NSError**)outError;

// SUBCLASSES ONLY:

- (instancetype) initWithFactory: (CBLNuModelFactory*)factory
                      documentID: (NSString*)documentID;

- (void) readFromRevision: (CBL_Revision*)rev;

@end
