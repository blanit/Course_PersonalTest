// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Skybox/BRpre_Fog_Skybox" {
Properties {
    _Tint ("Tint Color", Color) = (.5, .5, .5, .5)
    [Gamma] _Exposure ("Exposure", Range(0, 8)) = 1.0
    _Rotation ("Rotation", Range(0, 360)) = 0
    [NoScaleOffset] _Tex ("Cubemap   (HDR)", Cube) = "grey" {}

//    [Header(Fog)]
//        _FogCol("雾气颜色", Color) = (0.7, 0.8, 0.9, 1.0)
//        _FogInt("雾气强度", Range(0, 1)) = 0.5
//        _HeightFalloff("高度衰减速度", Range(0, 1)) = 1.0
//        _HeightBias("高度偏移", Range(-5, 20)) = 0.0
//        _DistFalloff("距离衰减速度", Range(1, 10)) = 1.0
//        _DistBias("距离偏移", Range(0, 20)) = 0.0
//        _ScatterPow("散射次幂", Range(0, 30)) = 1.0
//        _ScatterLight("散射光源方向", vector) = (1.0, 1.0, 1.0, 1.0)
}

SubShader {
    Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
    Cull Front ZWrite Off

    Pass {

        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 2.0

        #include "UnityCG.cginc"
        #include "AutoLight.cginc"
        #include "Lighting.cginc"
        //FogInclude
        #include "../cginc/PersonalHeader.cginc"

        samplerCUBE _Tex;
        half4 _Tex_HDR;
        half4 _Tint;
        half _Exposure;
        float _Rotation;

        float3 RotateAroundYInDegrees (float3 vertex, float degrees)
        {
            float alpha = degrees * UNITY_PI / 180.0;
            float sina, cosa;
            sincos(alpha, sina, cosa);
            float2x2 m = float2x2(cosa, -sina, sina, cosa);
            return float3(mul(m, vertex.xz), vertex.y).xzy;
        }

        struct appdata_t {
            float4 vertex : POSITION;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct v2f {
            float4 vertex : SV_POSITION;
            float3 texcoord : TEXCOORD0;
            float4 posWS : TEXCOORD1;
            UNITY_VERTEX_OUTPUT_STEREO
        };

        v2f vert (appdata_t v)
        {
            v2f o;
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
            o.posWS = mul(unity_ObjectToWorld, v.vertex);
            float3 rotated = RotateAroundYInDegrees(v.vertex.xyz, _Rotation);
            o.vertex = UnityObjectToClipPos(rotated);
            o.texcoord = v.vertex.xyz;
            return o;
        }

        fixed4 frag (v2f i) : SV_Target
        {
            half4 tex = texCUBElod(_Tex, float4(normalize(i.texcoord), 0.0));

            half3 c = DecodeHDR (tex, _Tex_HDR);
            c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
            c *= _Exposure;
            c = ExponentFog(c, i.posWS.xyz);
            return half4(c, 1);
        }
        ENDCG
    }
}


Fallback Off

}
