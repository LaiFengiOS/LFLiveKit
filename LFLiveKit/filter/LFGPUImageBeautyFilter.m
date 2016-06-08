#import "LFGPUImageBeautyFilter.h"
#import "GPUImageGaussianBlurFilter.h"
#import "GPUImageTwoInputFilter.h"
#import "GPUImageBilateralFilter.h"


#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const KLFGPUImageBeautyFragmentShaderString = SHADER_STRING
( 
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; 
 
 uniform lowp float excludeCircleRadius;
 uniform lowp vec2 excludeCirclePoint;
 uniform lowp float excludeBlurSize;
 uniform highp float aspectRatio;
 //247  217  211

 void main()
 {
     lowp vec4 tmpColor = texture2D(inputImageTexture, textureCoordinate);
//     gl_FragColor = tmpColor;
//     return;
     lowp vec4 sharpImageColor = texture2D(inputImageTexture, textureCoordinate);
     lowp vec4 blurredImageColor = texture2D(inputImageTexture2, textureCoordinate2);
     if((sharpImageColor.r > 0.372549 && sharpImageColor.g > 0.156863 && sharpImageColor.b > 0.078431 &&
         sharpImageColor.r - sharpImageColor.g > 0.058823 && sharpImageColor.r - sharpImageColor.b > 0.058823) ||
        (sharpImageColor.r > 0.784314 && sharpImageColor.g > 0.823530 && sharpImageColor.b > 0.666667 &&
         abs(sharpImageColor.r - sharpImageColor.b) <= 0.058823 && sharpImageColor.r > sharpImageColor.b && sharpImageColor.g > sharpImageColor.b)) {

            mediump float rpass;
            mediump float gpass;
            mediump float bpass;
            mediump float hpass;
            hpass = 0.5 / excludeBlurSize;
            hpass = 1.0;

            mediump float dis = distance(sharpImageColor, blurredImageColor);
            bpass = min((0.4+1.0*(1.0*dis)), 1.0);
            gl_FragColor = mix(sharpImageColor, blurredImageColor, 1.0-bpass);

     } else {
         mediump float rpass;
         mediump float gpass;
         mediump float bpass;
         mediump float hpass;
         hpass = 0.5 / excludeBlurSize;
         hpass = 1.0;
         mediump float dis = distance(sharpImageColor, blurredImageColor);
         bpass = min((0.45+1.0*(1.0*dis)), 1.0);
         gl_FragColor = mix(sharpImageColor, blurredImageColor, 1.0-bpass);

     }

     mediump float r;
     mediump float g;
     mediump float b;
     mediump float status = 0.81;
//     r = min((gl_FragColor.r+sharpImageColor.r - sharpImageColor.r*gl_FragColor.r), 1.0);
//     g = min((gl_FragColor.g+sharpImageColor.g - sharpImageColor.g*gl_FragColor.g), 1.0);
//     b = min((gl_FragColor.b+sharpImageColor.b - sharpImageColor.b*gl_FragColor.b), 1.0);
     r = min((gl_FragColor.r*2.0 - gl_FragColor.r*gl_FragColor.r), 1.0);
     g = min((gl_FragColor.g*2.0 - gl_FragColor.g*gl_FragColor.g), 1.0);
     b = min((gl_FragColor.b*2.0 - gl_FragColor.b*gl_FragColor.b), 1.0);
     r = min(status*gl_FragColor.r+1.05*(1.0-status)*r, 1.0);
     g = min(status*gl_FragColor.g+1.15*(1.0-status)*g, 1.0);
     b = min(status*gl_FragColor.b+1.25*(1.0-status)*b, 1.0);
     gl_FragColor = vec4(r, g, b, 1.0);
     //gl_FragColor = vec4(r, g, b, 1.0);

 }
);
#else
NSString *const KLFGPUImageBeautyFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 uniform float excludeCircleRadius;
 uniform vec2 excludeCirclePoint;
 uniform float excludeBlurSize;
 uniform float aspectRatio;
 
 void main()
 {
//     vec4 sharpImageColor = texture2D(inputImageTexture, textureCoordinate);
//     vec4 blurredImageColor = texture2D(inputImageTexture2, textureCoordinate2);
//     
//     vec2 textureCoordinateToUse = vec2(textureCoordinate2.x, (textureCoordinate2.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
//     float distanceFromCenter = distance(excludeCirclePoint, textureCoordinateToUse);
//     
//     gl_FragColor = mix(sharpImageColor, blurredImageColor, smoothstep(excludeCircleRadius - excludeBlurSize, excludeCircleRadius, distanceFromCenter));
     
     vec4 sharpImageColor = texture2D(inputImageTexture, textureCoordinate);
     vec4 blurredImageColor = texture2D(inputImageTexture2, textureCoordinate2);
     if(sharpImageColor.r > 0.372549/*0.372549*/) {
         mediump float bpass;
         bpass = min((sharpImageColor.r - blurredImageColor.r)*(sharpImageColor.r - blurredImageColor.r)*0.045455, 1.0);
         //bpass = min((sharpImageColor.r - blurredImageColor.r)*(sharpImageColor.r - blurredImageColor.r)*0.038462, 1.0);
         bpass = min((0.5+255.0*bpass), 1.0);
         gl_FragColor = mix(sharpImageColor, blurredImageColor, 1.0-bpass);
     } else {
         gl_FragColor = vec4(sharpImageColor.r, sharpImageColor.g, sharpImageColor.b,1.0);
     }
     mediump float r;
     mediump float g;
     mediump float b;
     r = min((gl_FragColor.r*2.0 - gl_FragColor.r*gl_FragColor.r), 1.0);
     g = min((gl_FragColor.g*2.0 - gl_FragColor.g*gl_FragColor.g), 1.0);
     b = min((gl_FragColor.b*2.0 - gl_FragColor.b*gl_FragColor.b), 1.0);
     
     r = min(0.62*gl_FragColor.r+0.38*r, 1.0);
     g = min(0.62*gl_FragColor.g+0.38*g, 1.0);
     b = min(0.62*gl_FragColor.b+0.38*b, 1.0);
     
     gl_FragColor = vec4(r, g, b, 1.0);
     
 }
);
#endif

@implementation LFGPUImageBeautyFilter

@synthesize excludeCirclePoint = _excludeCirclePoint, excludeCircleRadius = _excludeCircleRadius, excludeBlurSize = _excludeBlurSize;
@synthesize blurRadiusInPixels = _blurRadiusInPixels;
@synthesize aspectRatio = _aspectRatio;

- (id)init;
{
    if (!(self = [super init]))
    {
		return nil;
    }
    
    hasOverriddenAspectRatio = NO;
    
    // First pass: apply a variable Gaussian blur
    blurFilter = [[GPUImageGaussianBlurFilter alloc] init];
    //blurFilter = [[GPUImageBilateralFilter alloc] init];
    blurFilter.texelSpacingMultiplier = 0.55;
    blurFilter.blurRadiusInPixels = 23.0;
    [self addFilter:blurFilter];
    
    // Second pass: combine the blurred image with the original sharp one
    selectiveFocusFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:KLFGPUImageBeautyFragmentShaderString];
    [self addFilter:selectiveFocusFilter];
    
    // Texture location 0 needs to be the sharp image for both the blur and the second stage processing
    [blurFilter addTarget:selectiveFocusFilter atTextureLocation:1];
    
    // To prevent double updating of this filter, disable updates from the sharp image side    
    self.initialFilters = [NSArray arrayWithObjects:blurFilter, selectiveFocusFilter, nil];
    self.terminalFilter = selectiveFocusFilter;
    
    //self.blurRadiusInPixels = 5.0;
    //960*540
    self.blurRadiusInPixels = 13.0;
    //1280*720
    //self.blurRadiusInPixels = 11.0;
    
    self.excludeCircleRadius = 13.0;
    self.excludeCirclePoint = CGPointMake(0.5f, 0.5f);
    self.excludeBlurSize = 13.0;
    
    

    
    return self;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
    CGSize oldInputSize = inputTextureSize;
    [super setInputSize:newSize atIndex:textureIndex];
    inputTextureSize = newSize;
    
    if ( (!CGSizeEqualToSize(oldInputSize, inputTextureSize)) && (!hasOverriddenAspectRatio) && (!CGSizeEqualToSize(newSize, CGSizeZero)) )
    {
        _aspectRatio = (inputTextureSize.width / inputTextureSize.height);
        [selectiveFocusFilter setFloat:_aspectRatio forUniformName:@"aspectRatio"];
    }
}

#pragma mark -
#pragma mark Accessors

- (void)setBlurRadiusInPixels:(CGFloat)newValue;
{
    //newValue = 25;
    blurFilter.blurRadiusInPixels = newValue;
    _excludeCircleRadius = newValue;
    [selectiveFocusFilter setFloat:newValue forUniformName:@"excludeCircleRadius"];
    _excludeBlurSize = newValue;
    [selectiveFocusFilter setFloat:newValue forUniformName:@"excludeBlurSize"];
}

- (CGFloat)blurRadiusInPixels;
{
    return blurFilter.blurRadiusInPixels;
}

- (void)setExcludeCirclePoint:(CGPoint)newValue;
{
    _excludeCirclePoint = newValue;
    [selectiveFocusFilter setPoint:newValue forUniformName:@"excludeCirclePoint"];
}

- (void)setExcludeCircleRadius:(CGFloat)newValue;
{
    _excludeCircleRadius = newValue;
    [selectiveFocusFilter setFloat:newValue forUniformName:@"excludeCircleRadius"];
}

- (void)setExcludeBlurSize:(CGFloat)newValue;
{
    _excludeBlurSize = newValue;
    [selectiveFocusFilter setFloat:newValue forUniformName:@"excludeBlurSize"];
}

- (void)setAspectRatio:(CGFloat)newValue;
{
    hasOverriddenAspectRatio = YES;
    _aspectRatio = newValue;    
    [selectiveFocusFilter setFloat:_aspectRatio forUniformName:@"aspectRatio"];
}

@end














//#import "LFGPUImageBeautyFilter.h"
//
//// Internal CombinationFilter(It should not be used outside)
//@interface GPUImageCombinationFilter : GPUImageThreeInputFilter
//{
//    GLint smoothDegreeUniform;
//}
//
//@property (nonatomic, assign) CGFloat intensity;
//
//@end
//
//NSString *const kGPUImageBeautifyFragmentShaderString = SHADER_STRING
//(
// varying highp vec2 textureCoordinate;
// varying highp vec2 textureCoordinate2;
// varying highp vec2 textureCoordinate3;
// 
// uniform sampler2D inputImageTexture;
// uniform sampler2D inputImageTexture2;
// uniform sampler2D inputImageTexture3;
// uniform mediump float smoothDegree;
// 
// void main()
// {
////     highp vec4 bilateral = texture2D(inputImageTexture, textureCoordinate);
////     highp vec4 canny = texture2D(inputImageTexture2, textureCoordinate2);
////     highp vec4 origin = texture2D(inputImageTexture3,textureCoordinate3);
////     highp vec4 smooth;
////     lowp float r = origin.r;
////     lowp float g = origin.g;
////     lowp float b = origin.b;
////     if (canny.r < 0.2 && r > 0.3725 && g > 0.1568 && b > 0.0784 && r > b && (max(max(r, g), b) - min(min(r, g), b)) > 0.0588 && abs(r-g) > 0.0588) {
////         smooth = (1.0 - smoothDegree) * (origin - bilateral) + bilateral;
////     }
////     else {
////         smooth = origin;
////     }
////     smooth.r = log(1.0 + 0.2 * smooth.r)/log(1.2);
////     smooth.g = log(1.0 + 0.2 * smooth.g)/log(1.2);
////     smooth.b = log(1.0 + 0.2 * smooth.b)/log(1.2);
////     gl_FragColor = smooth;
//     
//     
//     highp vec4 blurredImageColor = texture2D(inputImageTexture, textureCoordinate);
//     highp vec4 canny = texture2D(inputImageTexture2, textureCoordinate2);
//     highp vec4 sharpImageColor = texture2D(inputImageTexture3,textureCoordinate3);
//
//     //gl_FragColor = canny;
//     
//     
//     
//     
//          if((sharpImageColor.r > 0.372549 && sharpImageColor.g > 0.156863 && sharpImageColor.b > 0.078431 &&
//              sharpImageColor.r - sharpImageColor.g > 0.058823 && sharpImageColor.r - sharpImageColor.b > 0.058823) ||
//             (sharpImageColor.r > 0.784314 && sharpImageColor.g > 0.823530 && sharpImageColor.b > 0.666667 &&
//              abs(sharpImageColor.r - sharpImageColor.b) <= 0.058823 && sharpImageColor.r > sharpImageColor.b && sharpImageColor.g > sharpImageColor.b)) {
//                 mediump float rpass;
//                 mediump float gpass;
//                 mediump float bpass;
//                 mediump float hpass;
//                 //hpass = 0.5 / excludeBlurSize;
//                 hpass = 1.0;
//                 //1280*720
//                 //bpass = min((sharpImageColor.r - blurredImageColor.r)*(sharpImageColor.r - blurredImageColor.r)*0.045455, 1.0);
//                 //960*540
//                 rpass = min(((sharpImageColor.r - blurredImageColor.r)*hpass), 1.0);
//                 gpass = min(((sharpImageColor.g - blurredImageColor.g)*hpass), 1.0);
//                 bpass = min(((sharpImageColor.b - blurredImageColor.b)*hpass), 1.0);
//                 bpass = min((0.0+1.0*(1.0*bpass)), 1.0);
//                 gpass = min((0.0+1.0*(1.0*gpass)), 1.0);
//                 rpass = min((0.0+1.0*(1.0*rpass)), 1.0);
//                 mediump float dis = distance(sharpImageColor, blurredImageColor);
//                 bpass = min((0.35+1.0*(1.0*dis)), 1.0);
//                 if(canny.r > 0.2) {
//                     bpass = min((0.45+1.0*(1.0*dis)), 1.0);
//                 }
//                 gl_FragColor = mix(sharpImageColor, blurredImageColor, 1.0-bpass);
//
//     
//          } else {
//              mediump float rpass;
//              mediump float gpass;
//              mediump float bpass;
//              mediump float hpass;
//              //hpass = 0.5 / excludeBlurSize;
//              hpass = 1.0;
//              //1280*720
//              //bpass = min((sharpImageColor.r - blurredImageColor.r)*(sharpImageColor.r - blurredImageColor.r)*0.045455, 1.0);
//              //960*540
//              rpass = min(((sharpImageColor.r - blurredImageColor.r)*hpass), 1.0);
//              gpass = min(((sharpImageColor.g - blurredImageColor.g)*hpass), 1.0);
//              bpass = min(((sharpImageColor.b - blurredImageColor.b)*hpass), 1.0);
//              bpass = min((0.5+1.0*(1.0*bpass)), 1.0);
//              gpass = min((0.5+1.0*(1.0*gpass)), 1.0);
//              rpass = min((0.5+1.0*(1.0*rpass)), 1.0);
//     
//     //         gpass = max(rpass, gpass);
//     //         bpass = max(gpass, bpass);
//     //         bpass = min((0.5+1.0*(1.0*bpass)), 1.0);
//              //gl_FragColor = vec4(1, 1, 1, 1.0);
//              mediump float dis = distance(sharpImageColor, blurredImageColor);
//              bpass = min((0.45+1.0*(1.0*dis)), 1.0);
//              if(canny.r > 0.2) {
//                  bpass = min((0.45+1.0*(1.0*dis)), 1.0);
//              }
//              gl_FragColor = mix(sharpImageColor, blurredImageColor, 1.0-bpass);
////
//          }
//
//     
//     //gl_FragColor = canny;
//     
//     
//          mediump float r;
//          mediump float g;
//          mediump float b;
//     mediump float status = 0.8;
//          r = min((gl_FragColor.r*2.0 - gl_FragColor.r*gl_FragColor.r), 1.0);
//          g = min((gl_FragColor.g*2.0 - gl_FragColor.g*gl_FragColor.g), 1.0);
//          b = min((gl_FragColor.b*2.0 - gl_FragColor.b*gl_FragColor.b), 1.0);
//          r = min(status*gl_FragColor.r+(1.0-status)*r, 1.0);
//          g = min(status*gl_FragColor.g+1.2*(1.0-status)*g, 1.0);
//          b = min(status*gl_FragColor.b+1.3*(1.0-status)*b, 1.0);
//          gl_FragColor = vec4(r, g, b, 1.0);
//     
//     //gl_FragColor = blurredImageColor;
//     
//     
//     
//     
// }
// );
//
//@implementation GPUImageCombinationFilter
//
//- (id)init {
//    if (self = [super initWithFragmentShaderFromString:kGPUImageBeautifyFragmentShaderString]) {
//        smoothDegreeUniform = [filterProgram uniformIndex:@"smoothDegree"];
//    }
//    self.intensity = 0.5;
//    return self;
//}
//
//- (void)setIntensity:(CGFloat)intensity {
//    _intensity = intensity;
//    [self setFloat:intensity forUniform:smoothDegreeUniform program:filterProgram];
//}
//
//@end
//
//@implementation LFGPUImageBeautyFilter
//
//- (id)init;
//{
//    if (!(self = [super init]))
//    {
//        return nil;
//    }
//    
//    // First pass: face smoothing filter
////    bilateralFilter = [[GPUImageBilateralFilter alloc] init];
////    bilateralFilter.distanceNormalizationFactor = 1.0;
////    bilateralFilter.texelSpacingMultiplier = 0.75;
////    bilateralFilter.blurRadiusInPixels = 11.0;
////    [self addFilter:bilateralFilter];
//    
//    bilateralFilter = [[GPUImageGaussianBlurFilter alloc] init];
//    bilateralFilter.texelSpacingMultiplier = 0.55;
//    bilateralFilter.blurRadiusInPixels = 13.0;
//    [self addFilter:bilateralFilter];
//    
//    // Second pass: edge detection
//    cannyEdgeFilter = [[GPUImageCannyEdgeDetectionFilter alloc] init];
//    [self addFilter:cannyEdgeFilter];
//    
//    // Third pass: combination bilateral, edge detection and origin
//    combinationFilter = [[GPUImageCombinationFilter alloc] init];
//    [self addFilter:combinationFilter];
//    
//    // Adjust HSB
//    hsbFilter = [[GPUImageHSBFilter alloc] init];
//    [hsbFilter adjustBrightness:1.0];
//    [hsbFilter adjustSaturation:1.0];
//    
//    [bilateralFilter addTarget:combinationFilter];
//    [cannyEdgeFilter addTarget:combinationFilter];
//    
//    [combinationFilter addTarget:hsbFilter];
//    
//    self.initialFilters = [NSArray arrayWithObjects:bilateralFilter,cannyEdgeFilter,combinationFilter,nil];
//    self.terminalFilter = hsbFilter;
//    
//    return self;
//}
//
//#pragma mark -
//#pragma mark GPUImageInput protocol
//
//- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
//{
//    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters)
//    {
//        if (currentFilter != self.inputFilterToIgnoreForUpdates)
//        {
//            if (currentFilter == combinationFilter) {
//                textureIndex = 2;
//            }
//            [currentFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
//        }
//    }
//}
//
//- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
//{
//    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters)
//    {
//        if (currentFilter == combinationFilter) {
//            textureIndex = 2;
//        }
//        [currentFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
//    }
//}
//
//@end






