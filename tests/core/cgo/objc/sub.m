@import Foundation;

@interface Subber : NSObject

- (int)sub:(int)num1 andNum2:(int)num2;

@end

@implementation Subber

- (int)sub:(int)num1 andNum2:(int)num2{
    return num1 - num2;
}

@end

int sub(int a, int b) {
    Subber* subber = [[Subber alloc] init];
    return [subber sub:a andNum2:b];
}
