//
//  CBLQueryRowModel.h
//  CouchbaseLite
//
//  Created by Jens Alfke on 9/26/14.
//
//

#import "CBLObject.h"
@class CBLQueryRow;


@interface CBLQueryRowModel : CBLObject

- (instancetype) initWithQueryRow: (CBLQueryRow*)row;

@property (readonly, nonatomic) CBLQueryRow* row;

@end
