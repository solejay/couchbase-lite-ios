//
//  CBLQueryRowModel.h
//  CouchbaseLite
//
//  Created by Jens Alfke on 9/26/14.
//
//

#import "CBLObject.h"
@class CBLQueryRow;


/** An object representing a view-query row, with properties that map to the JSON key/value. */
@interface CBLQueryRowModel : CBLObject

- (instancetype) initWithQueryRow: (CBLQueryRow*)row;

@property (readonly, nonatomic) CBLQueryRow* row;

@end
