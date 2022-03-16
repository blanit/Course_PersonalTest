// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Skybox/Custom_Skybox_Flowmap" {
Properties {
    _Tint                   ("Tint Color", Color) = (.5, .5, .5, .5)
    [Gamma] _Exposure       ("Exposure", Range(0, 8)) = 1.0
    _Rotation               ("Rotation", Range(0, 360)) = 0.0
    [NoScaleOffset] _Tex    ("Cubemap   (HDR)", Cube) = "grey" {}
    _FlowMap                ("FlowMap", Cube) = "black" {}
    [Toggle]_Inverse_FlowDir("反转流动方向", Range(0, 1)) = 0.0
}

SubShader {
    Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
    Cull Off ZWrite Off

    Pass {

        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 2.0
        #pragma shader_feature _INVERSE_FLOWDIR_ON

        #include "UnityCG.cginc"
        #include "AutoLight.cginc"
        #include "Lighting.cginc"
        //FogInclude
        #include "PersonalHeader.cginc"

        samplerCUBE _Tex;
        samplerCUBE _FlowMap;
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
            float3 uv : TEXCOORD0;
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
            o.uv = v.vertex.xyz;
            return o;
        }

        //ACESToneMapping
        float3 ACESToneMapping(float3 color, float adapted_lum){
            float A = 2.51f;
            float B = 0.03f;
            float C = 2.43f;
            float D = 0.59f;
            float E = 0.14f;

            color *= adapted_lum;
            return (color * (A * color + B)) / (color * (C * color + D) + E);
        }
        //FilmicToneMapping
        float3 Fx (float3 x){
            float A = 0.22f;
            float B = 0.30f;
            float C = 0.10f;
            float D = 0.20f;
            float E = 0.01f;
            float F = 0.30f;
            return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
        }

        fixed4 frag (v2f i) : SV_Target{
            //采样FlowMap
            half2 var_FlowMap = texCUBE(_FlowMap, i.uv).rg;
            half2 flowDir = var_FlowMap * 2.0 - 1.0;
            #ifdef _INVERSE_FLOWDIR_ON
                flowDir *= -1;
            #endif

            half2 phase1 = flowDir * 0.3 * frac(_Time.y * 0.5);
            half2 phase2 = flowDir * 0.3 * frac(_Time.y * 0.5 + 0.5);
            //half phase1_x = 
            
            half3 tex1 = texCUBE (_Tex, i.uv + (half3(phase1, 0.0)));
            half3 tex2 = texCUBE (_Tex, i.uv + (half3(phase2, 0.0)));


            float flowLerp = abs((0.5 - frac(_Time.y * 0.5)) / 0.5);
            half3 texMix = lerp(tex1, tex2, flowLerp);
            //half3 c = half3(var_FlowMap, 0.0);
            //half3 c = DecodeHDR (texMix, _Tex_HDR);
            //c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
            texMix *= _Exposure;
            texMix = ACESToneMapping(texMix, 0.4);

            return half4(texMix, 1);
        }
        ENDCG
    }
}


Fallback Off

}
