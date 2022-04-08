Shader "BR/BR33_Skybox" {
Properties {
    _Tint                   ("Tint Color", Color) = (.5, .5, .5, .5)
    [Gamma] _Exposure       ("Exposure", Range(0, 8)) = 1.0
    _Rotation               ("Rotation", Range(0, 360)) = 0.0
    [NoScaleOffset] _Tex    ("Cubemap   (HDR)", Cube) = "grey" {}
    
    [Header(Sun)]
        _SunRadius          ("Sun Radius", range(0, 1)) = 0.05
        _MoonRadius         ("Sun Radius", range(0, 1)) = 0.05
        [HDR]_DayCol        ("Day Color", color) = (1.0, 1.0, 1.0, 1.0)
        [HDR]_DawnCol       ("Dawn Color", color) = (1.0, 1.0, 1.0, 1.0)
        [HDR]_MoonCol       ("Moon Color", color) = (1.0, 1.0, 1.0, 1.0)
    
    [Header(Stars)]
        _StarTex            ("Star Texture", Cube) = "black" {}
    
    [Header(Sky)]
        _DayTopColor        ("Day Top Color", color) = (0.8, 0.8, 0.8, 1.0) 
        _DayBottomColor     ("Day Bottom Color", color) = (0.2, 0.2, 0.2, 1.0)
        _DawnTopColor        ("Dawn Top Color", color) = (0.5, 0.5, 0.5, 1.0) 
        _DawnBottomColor     ("Dawn Bottom Color", color) = (0.1, 0.1, 0.1, 1.0)
        _NightTopColor      ("Night Top Color", color) = (0.3, 0.3, 0.3, 1.0)
        _NightBottomColor   ("Night Bottom Color", color) = (0.1, 0.1, 0.1, 1.0)
        _SkyGradientPower   ("Sky Gradient Power", range(0.1, 3.0)) = 0.5
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

        samplerCUBE _Tex;
        samplerCUBE _StarTex;
        half4 _Tex_HDR;
        half4 _Tint;
        half _Exposure;
        float _Rotation;

        half _SunRadius;
        half _MoonRadius;
        half3 _DayCol;
        half3 _DawnCol;
        half3 _MoonCol;
        half3 _DawnTopColor;
        half3 _DawnBottomColor;
        half3 _DayTopColor;
        half3 _DayBottomColor;
        
        half3 _NightTopColor;
        half3 _NightBottomColor;
        half _SkyGradientPower;

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

        fixed4 frag (v2f i) : SV_Target{
            
            half4 var_Tex = texCUBElod(_Tex, float4(i.uv, 0.0));


            // Time Control -> [-1, 1]
            half timeCtrl = lerp(-0.999, 0.999,_WorldSpaceLightPos0.y / 2.0 + 0.5);
            half timeCtrl_SmoothStep = smoothstep(0.2, 0.8, timeCtrl/2 + 0.5) * 2 - 1;
            
            // sun
            float sun = distance(i.uv.xyz, _WorldSpaceLightPos0);
            float sunDist = 1 - (sun / _SunRadius);
            sunDist = saturate(sunDist * 50);
            float3 sunCol = lerp(_DawnCol, _DayCol, timeCtrl);
            float3 sunLight = sunDist * sunCol;

            // moon
            float moon = distance(- i.uv.xyz, _WorldSpaceLightPos0);
            float moonDist = 1 - (moon / _MoonRadius);
            moonDist = saturate(moonDist * 50);
            float3 moonLight = moonDist * _MoonCol;

            // stars
            float stars = pow(texCUBElod(_StarTex, float4(i.uv, 0.0)), 2.0) * saturate(-timeCtrl);
            float starNoise = 1.0 - pow(texCUBElod(_StarTex, float4(normalize(i.uv + float3(frac(_Time.y * 0.04), 0.0, 0.0)), 0.0)) * saturate(-timeCtrl), 0.1);

            // gradient day sky
            float3 gradientSkyColor[4];
                // Day Sky
                gradientSkyColor[3] = lerp(_DayBottomColor, _DayTopColor, pow(saturate(i.uv.y), _SkyGradientPower));
                // Night Sky
                half3 nightGradientCol = lerp(_NightBottomColor, _NightTopColor, pow(saturate(i.uv.y), _SkyGradientPower));
                gradientSkyColor[1] = nightGradientCol;
                // Dawn/Sunrise Sky
                half3 dawnGradientCol = lerp(_DawnBottomColor, _DawnTopColor, saturate(i.uv.y));
                gradientSkyColor[0] = lerp(nightGradientCol, dawnGradientCol, (i.uv.z / 2.0 + 0.5) * 
                (_WorldSpaceLightPos0.z)/abs(_WorldSpaceLightPos0.z) +
                ((1.0 - (_WorldSpaceLightPos0.z)/abs(_WorldSpaceLightPos0.z))/2.0));
                
                gradientSkyColor[2] = lerp(nightGradientCol, dawnGradientCol, (i.uv.z / 2.0 + 0.5) * 
                (_WorldSpaceLightPos0.z)/abs(_WorldSpaceLightPos0.z) +
                ((1.0 - (_WorldSpaceLightPos0.z)/abs(_WorldSpaceLightPos0.z))/2.0));
                
            // float3 gradientDay = lerp(_DayBottomColor, _DayTopColor, pow(saturate(i.uv.y), _SkyGradientPower));
            // float3 gradientNight = lerp(_NightBottomColor, _NightTopColor, pow(saturate(i.uv.y), _SkyGradientPower));
            // float3 skyGradients = lerp(gradientSkyColor[0], gradientSkyColor[1],saturate(timeCtrl));
            float3 skyCol = lerp(gradientSkyColor[floor(timeCtrl) + 1 + ceil(saturate(timeCtrl))], 
            gradientSkyColor[ceil(timeCtrl) + 1 + ceil(saturate(timeCtrl))], 
            abs(timeCtrl_SmoothStep));
            
            
            half3 c = DecodeHDR (var_Tex, _Tex_HDR);
            c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb * _Exposure;
            c = ACESToneMapping(c, 0.5);

            half3 finalRBG = skyCol + sunLight + moonLight + stars * starNoise;
            
            return half4(finalRBG, 1);
            //return starNoise;
        }
        ENDCG
    }
}


Fallback Off

}
