//
//  CBLNuModel.h
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/18/14.
//
//

#import "CBLObject.h"
@protocol CBLNuModelFactory;
@class CBL_Revision;


/** Abstract model object that represents a Couchbase Lite document in memory. */
@interface CBLNuModel : CBLObject

+ (instancetype) modelWithFactory: (id<CBLNuModelFactory>)factory
                       documentID: (NSString*)documentID;

- (instancetype) initNewModelWithFactory: (id<CBLNuModelFactory>)factory;

@property (readonly, nonatomic) id<CBLNuModelFactory> factory;

@property (readonly, nonatomic) NSString* documentID;
@property (readonly, nonatomic) NSString* revisionID;
@property (readonly, nonatomic) BOOL deleted;

@property (readonly, nonatomic) BOOL isNew;

@property (readonly, nonatomic) BOOL isFault;

/** Writes any changes to a new revision of the document.
    Returns YES without doing anything, if no changes have been made. */
- (BOOL) save: (NSError**)outError;

// SUBCLASSES ONLY:

- (instancetype) initWithFactory: (id<CBLNuModelFactory>)factory
                      documentID: (NSString*)documentID;

- (instancetype) initAsFaultWithFactory: (id<CBLNuModelFactory>)factory
                             documentID: (NSString*)documentID;

- (void) awakeFromFault;

- (void) readFromRevision: (CBL_Revision*)rev;

@end



/** A "fault" is a model whose properties haven't been loaded yet.
    As soon as any persistent property is accessed, the fault transforms itself into a true model
    object and loads its properties. */
@interface CBLFault : CBLNuModel
- (instancetype) initWithFactory: (id<CBLNuModelFactory>)factory
                      documentID: (NSString*)documentID
                       realClass: (Class)realClass;
@end
