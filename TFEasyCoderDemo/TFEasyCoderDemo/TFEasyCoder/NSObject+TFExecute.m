//
//  NSObject+TFExecute.m
//  两大框架继承
//
//  Created by 融数 on 16/10/26.
//  Copyright © 2016年 融数. All rights reserved.
//

#import "NSObject+TFExecute.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "TFEasyCoderConst.h"

@implementation NSObject (TFExecute)

+(id)tf_execute:(__unsafe_unretained Class)cls back:(ClassEasyCoderBlock)block
{
    return [self tf_execute:cls
                 initMethod:nil
                     params:nil
                       back:^(id ins) {
                           if (block) {
                               block(ins);
                           }
                       }];
}

+(id)tf_execute:(__unsafe_unretained Class)cls initMethod:(SEL)sel params:(NSArray *)param back:(ClassEasyCoderBlock)block
{
    id ins;
    if (sel)ins = [NSObject tf_executeSelector:sel
                                    withTarget:[cls alloc]
                               withParamsArray:param];
    else ins =[[cls alloc]init];    
    TF_WEAK_OBJ(ins, weakIns);
    if (block)
        block(weakIns);
    return weakIns;
}



+(void)tf_setValue:(id)_value forTarget:(id)_target forKey:(NSString *)_key
{
    NSCAssert(_target,@"tf_setTargetValue: _target can't be nil!");
    NSCAssert(_value,@"tf_setTargetValue: _value can't be nil!");
    NSCAssert(_key,@"tf_setTargetValue: _key can't be nil!");
    
    if (![_key hasPrefix:@"_"])
        _key = [@"_" stringByAppendingString:_key];
    
    Ivar ivar = class_getInstanceVariable([_target class], [_key UTF8String]);
    NSCAssert(ivar, @"%@ not contain attribute %@", [_target class], _key);

    [_target setValue:_value forKey:_key];
}


+(NSValue *)tf_executeSelector:(SEL)_sel withTarget:(id)_target  withParams:(id)params,...
{
    id arg;
    va_list _p_list;//定义一个指向个数可变的参数列表指针
    va_start(_p_list, params);//va_start 得到第一个可变参数地址
    
    NSMutableArray *_obj_params = arrayCapacity(5);
    if (params) {
        //将第一个参数添加到array
        id pre = params;
        [_obj_params addObject:pre];
        NSLog(@"参数<<<<<<<:%@",pre);
        @try {
            //va_arg 指向下一个参数地址
            while ((arg = va_arg(_p_list, id))) {
                if (arg) {
                    [_obj_params addObject:arg];
                    NSLog(@"参数<<<<<<<:%@",arg);
                }
            }
        } @catch (NSException *exception) {
            
            NSString *rea = [NSString stringWithFormat:@"%s 方法不接受基本类型参数!",__func__];
            TFAssert(NO,@"参数错误!",rea);
            
        } @finally {}
    }
    //置空
    va_end(_p_list);
    return  [self tf_executeSelector:_sel withTarget:_target withParamsArray:_obj_params];
}



+(NSValue *)tf_executeSelector:(SEL)_sel withTarget:(id)_target  withParamsArray:(NSArray*)_params
{
    NSCAssert(_target,@"tf_executeSelector: target can't be nil!");
    NSCAssert(_sel,@"tf_executeSelector: selector can't be nil!");

    Class cls = [_target class];
    //const char *cls_name = class_getName(cls);
    //const char *sel_name = sel_getName(_sel);
    Method method = class_getInstanceMethod(cls, _sel);
    
    //param total count
    unsigned int param_count_total = method_getNumberOfArguments(method);
    //param user custem count
    unsigned int param_count_user  = param_count_total - 2;
    //check params count
    NSCAssert((param_count_user == _params.count), @"selector %@ for instance %@ params count must be same", selToString(_sel), _target);
    
    //get signature
    NSMethodSignature  *signature = [cls instanceMethodSignatureForSelector:_sel];
    //check sel exsit
    NSCAssert(signature, @"unrecognized selector %@ for instance %@", selToString(_sel), _target);

    //get NSInvocation
    //其实NSInvocation就是将一个方法变成一个对象
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = _target;
    invocation.selector = _sel;
    
    for (unsigned int i = 2; i < param_count_total; i++) {
        id param_sel = [_params objectAtIndex:i - 2];//get parameter
        
        //get parameter types
        const char *a_type = [signature getArgumentTypeAtIndex:i];
        NSString   *a_type_str = [NSString stringWithUTF8String:a_type];
        //NSLog(@"a_type_str:%@",a_type_str);
        if ([a_type_str rangeOfString:@"?"].location!=NSNotFound) {
            
            BOOL can_parse = [param_sel isKindOfClass:[NSValue class]];
            NSCAssert(can_parse,@"%@ execute selector %@ error! please Convert special types (block..) paramter to NSValue", clsToString(cls), selToString(_sel));
            id param_value;
            NSValue *value = param_sel;
            [value getValue:&param_value];
            [invocation setArgument:&param_value atIndex:i];
            continue;
        }
        
        const char  a_type_c = a_type[0] == 'r' ? a_type[1] : a_type[0];
        
        switch (a_type_c) {
                
#define TF_EXECUTE_PARAM_CASE(TYPE_STRING,TYPE,SELECTOR)\
case TYPE_STRING:{\
NSNumber *num_param;\
if ([param_sel isKindOfClass:[NSNumber class]]) {\
num_param = param_sel;\
}else if([param_sel isKindOfClass:[NSString class]]){\
num_param = numberFromString(param_sel);\
}\
BOOL can_parse = [num_param respondsToSelector:@selector(SELECTOR)];\
NSCAssert(can_parse,@"%@ execute selector %@ error! please Convert basic types paramter to NSNumber or NSString", clsToString(cls), selToString(_sel));\
TYPE value = [num_param SELECTOR];\
[invocation setArgument:&value atIndex:i];\
}break;
                
                TF_EXECUTE_PARAM_CASE('c', char,charValue)
                TF_EXECUTE_PARAM_CASE('C', unsigned char, unsignedCharValue)
                TF_EXECUTE_PARAM_CASE('s', short, shortValue)
                TF_EXECUTE_PARAM_CASE('S', unsigned short, unsignedShortValue)
                TF_EXECUTE_PARAM_CASE('i', int, intValue)
                TF_EXECUTE_PARAM_CASE('I', unsigned int, unsignedIntValue)
                TF_EXECUTE_PARAM_CASE('l', long, longValue)
                TF_EXECUTE_PARAM_CASE('L', unsigned long, unsignedLongValue)
                TF_EXECUTE_PARAM_CASE('q', long long, longLongValue)
                TF_EXECUTE_PARAM_CASE('Q', unsigned long long, unsignedLongLongValue)
                TF_EXECUTE_PARAM_CASE('f', float, floatValue)
                TF_EXECUTE_PARAM_CASE('d', double, doubleValue)
                TF_EXECUTE_PARAM_CASE('B', BOOL, boolValue)
              
            case ':':{
                
                BOOL can_parse = [param_sel isKindOfClass:[NSString class]];
                NSCAssert(can_parse,@"%@ execute selector %@ error! please Convert SEL paramter to NSString", clsToString(cls), selToString(_sel));
                SEL value = NSSelectorFromString(param_sel);
                [invocation setArgument:&value atIndex:i];
                
            }break;
                
            case '{': {
                
                BOOL can_parse = [param_sel isKindOfClass:[NSString class]];
                NSCAssert(can_parse,@"%@ execute selector %@ error! please Convert struct paramter to NSString", clsToString(cls), selToString(_sel));
                NSString *typeString = parseStructName([NSString stringWithUTF8String:a_type]);
                typeString = [typeString stringByReplacingOccurrencesOfString:@"_" withString:@""];
                
#define TF_EXECUTE_PARAM_STRUCT(STRUCT_NAME)\
STRUCT_NAME value = STRUCT_NAME##FromString(param_sel);\
[invocation setArgument:&value atIndex:i];
                
            }break;
            case '*':
            case '^': {
                void * value = (__bridge void *)(param_sel);
                [invocation setArgument:&value atIndex:i];
            }
            case '#': {
                BOOL can_parse = [param_sel isKindOfClass:[NSString class]];
                NSCAssert(can_parse,@"%@ execute selector %@ error! please Convert Class paramter to NSString", clsToString(cls), selToString(_sel));
                Class value = NSClassFromString(param_sel);
                [invocation setArgument:&value atIndex:i];
            }
            case '@': {
                [invocation setArgument:&param_sel atIndex:i];
            }
            default: {
                if (param_sel == NULL) {
                    NSNull *value = [NSNull null];
                    [invocation setArgument:&value atIndex:i];
                    break;
                }
                if (([param_sel isKindOfClass:[NSNumber class]] &&
                     strcmp([param_sel objCType], "c") == 0 &&
                     ![param_sel boolValue])) {
                    id value = nil;
                    [invocation setArgument:&value atIndex:i];
                    break;
                }
            }
        }
    }
    //execute
    [invocation invoke];
    //get returntype
    const char *r_type = signature.methodReturnType;
    if (strcmp(r_type, @encode(void))==0) {return nil;}
    
    id r_value;
    if (strcmp(r_type, @encode(id)) == 0) {
        void *result;
        [invocation getReturnValue:&result];
        NSString *sel_str = NSStringFromSelector(_sel);
        if ([sel_str isEqualToString:@"alloc"] || [sel_str isEqualToString:@"new"] ||
            [sel_str isEqualToString:@"copy"] || [sel_str isEqualToString:@"mutableCopy"]) {
            r_value = (__bridge_transfer id)result;
        } else {
            r_value = (__bridge id)result;
        }
        return r_value;
    }else{
        //get return value length
        NSUInteger r_length = [signature methodReturnLength];
        //apply memory
        void *_r_buffer = (void *)malloc(r_length);
        //get return value
        [invocation getReturnValue:_r_buffer];
        //get return value value
        r_value = [NSValue valueWithBytes:_r_buffer objCType:r_type];
        //NSLog(@"r_type:%@",[NSString stringWithUTF8String:r_type]);
        return r_value;
    }
    return nil;
}


static inline NSString *clsToString(Class cls){
    return NSStringFromClass(cls);
}
//static inline Class stringToCls(NSString *str){
//    return NSClassFromString(str);
//}
static inline NSString *selToString(SEL sel){
    return NSStringFromSelector(sel);
}
//static inline SEL stringToSel(NSString *str){
//    return NSSelectorFromString(str);
//}
//in {CGRect={CGPoint=dd}{CGSize=dd}} out CGRect
static inline NSString *parseStructName(NSString *typeEncodeString)
{
    NSArray *array = [typeEncodeString componentsSeparatedByString:@"="];
    NSString *typeString = array[0];
    int firstValidIndex = 0;
    for (int i = 0; i< typeString.length; i++) {
        char c = [typeString characterAtIndex:i];
        if (c == '{' || c=='_') {
            firstValidIndex++;
        }else {
            break;
        }
    }
    return [typeString substringFromIndex:firstValidIndex];
}
static inline NSMutableArray *arrayCapacity(NSUInteger cap){
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:cap];
    return array;
}

//static inline NSString *stringFromNumber(NSNumber *number){
//    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
//    NSString *string =[numberFormatter stringFromNumber:number];
//    return string;
//}
static inline NSNumber *numberFromString(NSString *string){
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *number = [numberFormatter numberFromString:string];
    return number;
}

@end