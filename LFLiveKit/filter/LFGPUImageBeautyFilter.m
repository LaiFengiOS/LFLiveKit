#import "LFGPUImageBeautyFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kLFGPUImageBeautyFragmentShaderString = SHADER_STRING
                                                        (
    varying highp vec2 textureCoordinate;

    uniform sampler2D inputImageTexture;

    uniform highp vec2 singleStepOffset;
    uniform highp vec4 params;
    uniform highp float brightness;

    const highp vec3 W = vec3(0.299, 0.587, 0.114);
    const highp mat3 saturateMatrix = mat3(
        1.1102, -0.0598, -0.061,
        -0.0774, 1.0826, -0.1186,
        -0.0228, -0.0228, 1.1772);
    highp vec2 blurCoordinates[24];

    highp float hardLight(highp float color) {
    if (color <= 0.5)
        color = color * color * 2.0;
    else
        color = 1.0 - ((1.0 - color)*(1.0 - color) * 2.0);
    return color;
}

    void main(){
    highp vec3 centralColor = texture2D(inputImageTexture, textureCoordinate).rgb;
    blurCoordinates[0] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -10.0);
    blurCoordinates[1] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 10.0);
    blurCoordinates[2] = textureCoordinate.xy + singleStepOffset * vec2(-10.0, 0.0);
    blurCoordinates[3] = textureCoordinate.xy + singleStepOffset * vec2(10.0, 0.0);
    blurCoordinates[4] = textureCoordinate.xy + singleStepOffset * vec2(5.0, -8.0);
    blurCoordinates[5] = textureCoordinate.xy + singleStepOffset * vec2(5.0, 8.0);
    blurCoordinates[6] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, 8.0);
    blurCoordinates[7] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, -8.0);
    blurCoordinates[8] = textureCoordinate.xy + singleStepOffset * vec2(8.0, -5.0);
    blurCoordinates[9] = textureCoordinate.xy + singleStepOffset * vec2(8.0, 5.0);
    blurCoordinates[10] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, 5.0);
    blurCoordinates[11] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, -5.0);
    blurCoordinates[12] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -6.0);
    blurCoordinates[13] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 6.0);
    blurCoordinates[14] = textureCoordinate.xy + singleStepOffset * vec2(6.0, 0.0);
    blurCoordinates[15] = textureCoordinate.xy + singleStepOffset * vec2(-6.0, 0.0);
    blurCoordinates[16] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, -4.0);
    blurCoordinates[17] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, 4.0);
    blurCoordinates[18] = textureCoordinate.xy + singleStepOffset * vec2(4.0, -4.0);
    blurCoordinates[19] = textureCoordinate.xy + singleStepOffset * vec2(4.0, 4.0);
    blurCoordinates[20] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, -2.0);
    blurCoordinates[21] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, 2.0);
    blurCoordinates[22] = textureCoordinate.xy + singleStepOffset * vec2(2.0, -2.0);
    blurCoordinates[23] = textureCoordinate.xy + singleStepOffset * vec2(2.0, 2.0);

    highp float sampleColor = centralColor.g * 22.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[0]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[1]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[2]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[3]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[4]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[5]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[6]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[7]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[8]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[9]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[10]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[11]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[12]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[13]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[14]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[15]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[16]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[17]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[18]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[19]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[20]).g * 3.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[21]).g * 3.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[22]).g * 3.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[23]).g * 3.0;

    sampleColor = sampleColor / 62.0;

    highp float highPass = centralColor.g - sampleColor + 0.5;

    for (int i = 0; i < 5; i++) {
        highPass = hardLight(highPass);
    }
    highp float lumance = dot(centralColor, W);

    highp float alpha = pow(lumance, params.r);

    highp vec3 smoothColor = centralColor + (centralColor-vec3(highPass))*alpha*0.1;

    smoothColor.r = clamp(pow(smoothColor.r, params.g), 0.0, 1.0);
    smoothColor.g = clamp(pow(smoothColor.g, params.g), 0.0, 1.0);
    smoothColor.b = clamp(pow(smoothColor.b, params.g), 0.0, 1.0);

    highp vec3 lvse = vec3(1.0)-(vec3(1.0)-smoothColor)*(vec3(1.0)-centralColor);
    highp vec3 bianliang = max(smoothColor, centralColor);
    highp vec3 rouguang = 2.0*centralColor*smoothColor + centralColor*centralColor - 2.0*centralColor*centralColor*smoothColor;

    gl_FragColor = vec4(mix(centralColor, lvse, alpha), 1.0);
    gl_FragColor.rgb = mix(gl_FragColor.rgb, bianliang, alpha);
    gl_FragColor.rgb = mix(gl_FragColor.rgb, rouguang, params.b);

    highp vec3 satcolor = gl_FragColor.rgb * saturateMatrix;
    gl_FragColor.rgb = mix(gl_FragColor.rgb, satcolor, params.a);
    gl_FragColor.rgb = vec3(gl_FragColor.rgb + vec3(brightness));
}

                                                        );
#else
NSString *const kLFGPUImageBeautyFragmentShaderString = SHADER_STRING
                                                        (
    varying vec2 textureCoordinate;

    uniform sampler2D inputImageTexture;

    uniform mediump vec2 singleStepOffset;
    uniform mediump vec4 params;
    uniform mediump float brightness;
    const mediump mat3 saturateMatrix = mat3(
        1.1102, -0.0598, -0.061,
        -0.0774, 1.0826, -0.1186,
        -0.0228, -0.0228, 1.1772);
    const mediump vec3 W = vec3(0.299, 0.587, 0.114);
    mediump vec2 blurCoordinates[24];

    mediump float hardLight(mediump float color){
    if (color <= 0.5)
        color = color * color * 2.0;
    else
        color = 1.0 - ((1.0 - color)*(1.0 - color) * 2.0);
    return color;
}

    void main(){
    mediump vec3 centralColor = texture2D(inputImageTexture, textureCoordinate).rgb;
    blurCoordinates[0] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -10.0);
    blurCoordinates[1] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 10.0);
    blurCoordinates[2] = textureCoordinate.xy + singleStepOffset * vec2(-10.0, 0.0);
    blurCoordinates[3] = textureCoordinate.xy + singleStepOffset * vec2(10.0, 0.0);
    blurCoordinates[4] = textureCoordinate.xy + singleStepOffset * vec2(5.0, -8.0);
    blurCoordinates[5] = textureCoordinate.xy + singleStepOffset * vec2(5.0, 8.0);
    blurCoordinates[6] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, 8.0);
    blurCoordinates[7] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, -8.0);
    blurCoordinates[8] = textureCoordinate.xy + singleStepOffset * vec2(8.0, -5.0);
    blurCoordinates[9] = textureCoordinate.xy + singleStepOffset * vec2(8.0, 5.0);
    blurCoordinates[10] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, 5.0);
    blurCoordinates[11] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, -5.0);
    blurCoordinates[12] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -6.0);
    blurCoordinates[13] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 6.0);
    blurCoordinates[14] = textureCoordinate.xy + singleStepOffset * vec2(6.0, 0.0);
    blurCoordinates[15] = textureCoordinate.xy + singleStepOffset * vec2(-6.0, 0.0);
    blurCoordinates[16] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, -4.0);
    blurCoordinates[17] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, 4.0);
    blurCoordinates[18] = textureCoordinate.xy + singleStepOffset * vec2(4.0, -4.0);
    blurCoordinates[19] = textureCoordinate.xy + singleStepOffset * vec2(4.0, 4.0);
    blurCoordinates[20] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, -2.0);
    blurCoordinates[21] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, 2.0);
    blurCoordinates[22] = textureCoordinate.xy + singleStepOffset * vec2(2.0, -2.0);
    blurCoordinates[23] = textureCoordinate.xy + singleStepOffset * vec2(2.0, 2.0);

    mediump float sampleColor = centralColor.g * 22.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[0]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[1]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[2]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[3]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[4]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[5]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[6]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[7]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[8]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[9]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[10]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[11]).g;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[12]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[13]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[14]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[15]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[16]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[17]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[18]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[19]).g * 2.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[20]).g * 3.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[21]).g * 3.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[22]).g * 3.0;
    sampleColor += texture2D(inputImageTexture, blurCoordinates[23]).g * 3.0;

    sampleColor = sampleColor / 62.0;

    mediump float highPass = centralColor.g - sampleColor + 0.5;

    for (int i = 0; i < 5; i++) {
        highPass = hardLight(highPass);
    }
    mediump float luminance = dot(centralColor, W);

    mediump float alpha = pow(luminance, params);

    mediump vec3 smoothColor = centralColor + (centralColor-vec3(highPass))*alpha*0.1;

    smoothColor.r = clamp(pow(smoothColor.r, params.g), 0.0, 1.0);
    smoothColor.g = clamp(pow(smoothColor.g, params.g), 0.0, 1.0);
    smoothColor.b = clamp(pow(smoothColor.b, params.g), 0.0, 1.0);

    mediump vec3 lvse = vec3(1.0)-(vec3(1.0)-smoothColor)*(vec3(1.0)-centralColor);
    mediump vec3 bianliang = max(smoothColor, centralColor);
    mediump vec3 rouguang = 2.0*centralColor*smoothColor + centralColor*centralColor - 2.0*centralColor*centralColor*smoothColor;

    gl_FragColor = vec4(mix(centralColor, lvse, alpha), 1.0);
    gl_FragColor.rgb = mix(gl_FragColor.rgb, bianliang, alpha);
    gl_FragColor.rgb = mix(gl_FragColor.rgb, rouguang, params.b);

    mediump vec3 satcolor = gl_FragColor.rgb * saturateMatrix;
    gl_FragColor.rgb = mix(gl_FragColor.rgb, satcolor, params.a);
    gl_FragColor.rgb = vec3(gl_FragColor.rgb + vec3(brightness));
}

                                                        );
#endif

@implementation LFGPUImageBeautyFilter

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kLFGPUImageBeautyFragmentShaderString])) {
        return nil;
    }

    _toneLevel = 0.5;
    _beautyLevel = 0.5;
    _brightLevel = 0.5;
    [self setParams:_beautyLevel tone:_toneLevel];
    [self setBrightLevel:_brightLevel];
    return self;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex {
    [super setInputSize:newSize atIndex:textureIndex];
    inputTextureSize = newSize;

    CGPoint offset = CGPointMake(2.0f / inputTextureSize.width, 2.0 / inputTextureSize.height);
    [self setPoint:offset forUniformName:@"singleStepOffset"];
}

- (void)setBeautyLevel:(CGFloat)beautyLevel {
    _beautyLevel = beautyLevel;
    [self setParams:_beautyLevel tone:_toneLevel];
}

- (void)setBrightLevel:(CGFloat)brightLevel {
    _brightLevel = brightLevel;
    [self setFloat:0.6 * (-0.5 + brightLevel) forUniformName:@"brightness"];
}

- (void)setParams:(CGFloat)beauty tone:(CGFloat)tone {
    GPUVector4 fBeautyParam;
    fBeautyParam.one = 1.0 - 0.6 * beauty;
    fBeautyParam.two = 1.0 - 0.3 * beauty;
    fBeautyParam.three = 0.1 + 0.3 * tone;
    fBeautyParam.four = 0.1 + 0.3 * tone;
    [self setFloatVec4:fBeautyParam forUniform:@"params"];
}

@end

