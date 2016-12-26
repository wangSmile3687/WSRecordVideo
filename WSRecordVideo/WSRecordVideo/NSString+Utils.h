//
//  NSString+Utils.h
//  WeChatContacts-demo
//
//  Created by shen_gh on 16/3/12.
//  Copyright © 2016年 com.joinup(Beijing). All rights reserved.
//

#import <Foundation/Foundation.h>

@class UILabel;
@class UIFont;

@interface NSString (Utils)

/**
 *  汉字的拼音
 *
 *  @return 拼音
 */
-(NSString *)pinyin;
-(NSString*)trim;
+(NSString *)trim:(NSString *)str;

/**
 Start with specific string
 */
-(BOOL)startWith:(NSString*)string;
/**
 End with specific string
 */
-(BOOL)endWith:(NSString*)string;

-(BOOL)isChinese;

//大小写转换
-(NSString *)toLowercaseString;
-(NSString *)toUppercaseString;
-(NSString *)toCapitalizedString;

//md5加密
-(NSString*)md5;

+ (BOOL)isEmptyStrings:(NSString *)string;
+ (BOOL)isRealString:(NSString *)string;
- (NSInteger)fileSize;
//文件生成MD5摘要
+ (NSString*)getMD5WithData:(NSData *)data;

+ (NSString *)getTimeNow;

@end
