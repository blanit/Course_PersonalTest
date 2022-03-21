#ifndef EXPONENT_FOG_INCLUDE
#define EXPONENT_FOG_INCLUDE

uniform half _HeightFalloff;
uniform half _HeightBias;
uniform half3 _FogCol;
uniform half _DistFalloff;
uniform half _DistBias;
uniform half _ScatterPow;
uniform half3 _ScatterLight;

//ExponentFog
half3 ExponentFog(half3 Col, half3 posWS){
    //高度雾(指数衰减)
    half fogDen = pow(lerp(1.0, 2.0, _HeightFalloff), (_WorldSpaceCameraPos.y - posWS.y - _HeightBias));
    //深度雾(线性衰减)
    half fogInt = (distance(posWS.xyz, _WorldSpaceCameraPos.xyz) - _DistBias) / _DistFalloff;
    //太阳光散射
    half vdotl = dot(normalize(_WorldSpaceCameraPos.xyz - posWS.xyz), normalize(_ScatterLight.xyz));
    vdotl = max(vdotl, 0);
    half scatterInt = pow(vdotl, _ScatterPow) * fogDen * fogInt;
    scatterInt = saturate(scatterInt) * 0.7;

    half finalfogInt = saturate(fogDen * fogInt);
    half3 fogCol = lerp(_FogCol, _LightColor0, scatterInt);
    half3 finalFogCol = lerp(Col, fogCol, finalfogInt);
    return finalFogCol;
}

#endif