//
//  CAEAGLLayer+TFEasyCoder.h
//  TFEasyCoder
//
//  Created by ztf on 16/10/26.
//  Copyright © 2016年 ztf. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "TFEasyCoderConst.h"

TF_EC_BLOCK(CAEAGLLayer,CAEAGLLayer *);

@interface CAEAGLLayer (TFEasyCoder)

TF_EC_MSTATIC_INT(CAEAGLLayer, CAEAGLLayer *);
TF_EC_MINSTANCE_INT(CAEAGLLayer,CAEAGLLayer *);



TF_EC_CHAIN_PROP_INT(CAEAGLLayer ,BOOL,presentsWithTransaction);
TF_EC_CHAIN_PROP_INT(CAEAGLLayer ,NSDictionary *,drawableProperties);

@end