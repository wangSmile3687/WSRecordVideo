//
//  NSString+Utils.m
//  WeChatContacts-demo
//
//  Created by shen_gh on 16/3/12.
//  Copyright © 2016年 com.joinup(Beijing). All rights reserved.
//

#import "NSString+Utils.h"

#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>

static inline BOOL isEmpty(id thing) {
    return thing == nil
    || ([thing respondsToSelector:@selector(length)]
        && [(NSData *)thing length] == 0)
    || ([thing respondsToSelector:@selector(count)]
        && [(NSArray *)thing count] == 0)
    || [thing isKindOfClass:[NSNull class]];
}

@implementation NSString (Utils)

//汉字的拼音
- (NSString *)pinyin{
    NSMutableString *str = [self mutableCopy];
    CFStringTransform(( CFMutableStringRef)str, NULL, kCFStringTransformMandarinLatin, NO);
    CFStringTransform((CFMutableStringRef)str, NULL, kCFStringTransformStripDiacritics, NO);
    
    return [str stringByReplacingOccurrencesOfString:@" " withString:@""];
}

+(NSString *)trim:(NSString *)str{
    
    if ([NSString isNull:str]) {
        return nil;
    }
    
    NSString *trimmedString = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([NSString isNull:trimmedString]) {
        return nil;
    }else {
        return trimmedString;
    }
    
}

//去掉首尾空格
-(NSString *)trim{
    
    if ([NSString isNull:self]) {
        return Nil;
    }
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

//以。。。开始
-(BOOL)startWith:(NSString*)string{
    
    NSRange range = [self rangeOfString:string];
    if (range.length >0 && range.location == 0) {
        return YES;
    }
    else {
        return NO;
    }
}

//以。。。结束
-(BOOL)endWith:(NSString*)string{
    
    NSRange range = [self rangeOfString:string options:NSBackwardsSearch];
    if (range.length >0 && ((range.length+range.location) ==self.length) ) {
        return YES;
    }
    else {
        return NO;
    }
    
}

//是否是中文
-(BOOL)isChinese{
    return ![self canBeConvertedToEncoding: NSASCIIStringEncoding];
}

//转成小写
-(NSString *)toLowercaseString{
    if ([NSString isNotNull:self]) {
        return [self lowercaseString];
    }else{
        return Nil;
    }
}

//转成大写
-(NSString *)toUppercaseString{
    if ([NSString isNotNull:self]) {
        return [self uppercaseString];
    }else{
        return Nil;
    }
}

-(NSString *)toCapitalizedString{
    if ([NSString isNotNull:self]) {
        return [self capitalizedString];
    }else{
        return Nil;
    }
}


+(BOOL)isNull:(NSString *)str_{
    return isEmpty(str_);
}

+(BOOL)isNotNull:(NSString *)string{
    return ![NSString isNull:string];
}

-(NSString*)md5{
    
    const char * cStr = [self UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, strlen(cStr), result);
    // This is the md5 call
    return[NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",        result[0], result[1], result[2], result[3],         result[4], result[5], result[6], result[7],        result[8], result[9], result[10], result[11],        result[12], result[13], result[14], result[15]];
}

+ (BOOL)isEmptyStrings:(NSString *)string
{
    if ([string isEqual:[NSNull null]]) {
        return YES;
    }
    
    if (string == nil) {
        return YES;
    } else if ([string length] == 0) {
        return YES;
    } else  {
        
        if ([string isEqualToString:@"(null)"]) {
            return YES;
        }
        
        string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if ([string length] == 0) {
            return YES;
        }
    }
    return NO;
    
}

+ (BOOL)isRealString:(NSString *)string
{
    return ![self isEmptyStrings:string];
}

- (NSInteger)fileSize
{
    // 文件管理者
    NSFileManager *mgr = [NSFileManager defaultManager];
    // 是否为文件夹
    BOOL isDirectory = NO;
    // 这个路径是否存在
    BOOL exists = [mgr fileExistsAtPath:self isDirectory:&isDirectory];
    // 路径不存在
    if (exists == NO) return 0;
    
    if (isDirectory) { // 文件夹
        // 总大小
        NSInteger size = 0;
        // 获得文件夹中的所有内容
        NSDirectoryEnumerator *enumerator = [mgr enumeratorAtPath:self];
        for (NSString *subpath in enumerator) {
            // 获得全路径
            NSString *fullSubpath = [self stringByAppendingPathComponent:subpath];
            // 获得文件属性
            size += [mgr attributesOfItemAtPath:fullSubpath error:nil].fileSize;
        }
        return size;
    } else { // 文件
        return [mgr attributesOfItemAtPath:self error:nil].fileSize;
    }
}

+ (NSString*)getMD5WithData:(NSData *)data{
    
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5( data.bytes, (CC_LONG)data.length, digest );
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for( int i = 0; i < CC_MD5_DIGEST_LENGTH; i++ )
        
    {
        
        [output appendFormat:@"%02x", digest[i]];
        
    }
    
    return output;
    
}
+ (NSString *)getTimeNow
{
    NSString* date;
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc ] init];
    //[formatter setDateFormat:@"YYYY.MM.dd.hh.mm.ss"];
    [formatter setDateFormat:@"mm:ss:SSS"];
    date = [formatter stringFromDate:[NSDate date]];
    NSString * timeNow = [[NSString alloc] initWithFormat:@"%@", date];
    return timeNow;
}
@end
