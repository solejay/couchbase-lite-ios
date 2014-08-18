//
//  NuModel.h
//  CouchbaseLite
//
//  Created by Jens Alfke on 8/15/14.
//
//

#import <Foundation/Foundation.h>


#define CBLSynthesize(PROP)            @synthesize PROP= _doc_##PROP
#define CBLSynthesizeAs(PROP, DOCPROP) @synthesize PROP= _doc_##DOCPROP


@interface NuModel : NSObject

@property (readonly, nonatomic) NSString* documentID;

@property (readonly, nonatomic) BOOL needsSave;

@property (copy) NSDictionary* persistentProperties;

/** Copies all dirty persistent properties to the `properties` dictionary.
    Returns YES if `properties` was changed as a result. */
- (BOOL) updatePersistentProperties: (NSMutableDictionary*)properties;

@end
