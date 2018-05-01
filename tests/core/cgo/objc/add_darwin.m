@import Foundation;

#include "add_darwin.h"

@interface Adder : NSObject

- (int)add:(int)num1 andNum2:(int)num2;

@end

@implementation Adder

- (int)add:(int)num1 andNum2:(int)num2{
    return num1 + num2;
}

@end

int add(int a, int b) {
    Adder* adder = [[Adder alloc] init];
    return [adder add:a andNum2:b];
}
