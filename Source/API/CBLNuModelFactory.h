//
//  CBLNuModelFactory.h
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/18/14.
//
//

#import "CBLNuModel.h"


/** The API that CBLNuModel expects of the model factory. */
@protocol CBLNuModelFactory <NSObject>

/** Returns a model object for the given document ID.
    If a model has already been instantiated with the given ID, it must be returned (even if it's
    a fault.)
    @param documentID  The ID of the model
    @param ofClass  The class the model should be, or Nil if it can be any subclass.
    @param asFault  If YES, the return value can be a CBLFault. */
- (CBLNuModel*) modelWithDocumentID: (NSString*)documentID
                            ofClass: (Class)ofClass
                            asFault: (BOOL)asFault
                              error: (NSError**)outError;

/** Returns the existing non-fault model object with the given ID, or nil if there's none. */
- (CBLNuModel*) existingModelWithDocumentID: (NSString*)documentID;

- (void) addNewModel: (CBLNuModel*)model;

- (BOOL) readPropertiesOfModel: (CBLNuModel*)model error: (NSError**)error;
- (BOOL) savePropertiesOfModel: (CBLNuModel*)model error: (NSError**)error;

/** All models whose needsSave is true. Models add/remove themselves from this set. */
@property (readonly) NSMutableSet* unsavedModels;

/** Saves changes to all models whose needsSave is true. */
- (BOOL) saveAllModels: (NSError**)outError;

/** Immediately runs any pending autosaves for all models. */
- (BOOL) autosaveAllModels: (NSError**)outError;

@end


@protocol CBLNuModelFactoryDelegate;


/** Abstract implementation that uses a CBLCache to hold model objects.
    Subclasses must still implement readPropertiesOfModel: and savePropertiesOfModel:. */
@interface CBLNuModelFactory : NSObject <CBLNuModelFactory>

@property (nonatomic) id<CBLNuModelFactoryDelegate> delegate;

/** Instantiates a new concrete (non-fault) model object of the given class,
    and reads its properties. Can be overridden by subclasses. */
- (CBLNuModel*) createModelWithDocumentID: (NSString*)documentID
                                  ofClass: (Class)ofClass
                                    error: (NSError**)outError;

@end


@protocol CBLNuModelFactoryDelegate <NSObject>

- (BOOL) readPropertiesOfModel: (CBLNuModel*)model error: (NSError**)error;
- (BOOL) savePropertiesOfModel: (CBLNuModel*)model error: (NSError**)error;

- (BOOL) savePropertiesOfModels: (NSSet*)models error: (NSError**)outError;

@end
