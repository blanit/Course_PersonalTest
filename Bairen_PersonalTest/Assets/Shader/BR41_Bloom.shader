Shader "Bairen/BR41_Bloom" {
    Properties {
        _MainTex ("RGB", 2d) = "white" {}
        _Bloom ("Bloom纹理", 2d) = "black" {}             // 模糊后纹理
        _LuminanceThreshold ("Threshold", float) = 0.5
        _BlurSize ("Blur Size", float) = 1.0
        _Intensity ("Intensity", float) = 1.0
    }
    SubShader {
        
        CGINCLUDE
        #include "UnityCG.cginc"
        
        sampler2D _MainTex;
        half4 _MainTex_TexelSize;
        sampler2D _Bloom;
        float _LuminanceThreshold;
        float _BlurSize;
        float _Intensity;
        
        // Pass0 提取亮部区域 shader
        struct v2fExtractBright
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        v2fExtractBright vertExtractBright(appdata_img v)
        {
            v2fExtractBright o;
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv = v.texcoord;

            return o;
        }

        fixed ComputeLuminance(fixed4 color)
        {
            return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
        }

        fixed4 fragExtractBright(v2fExtractBright i) : SV_TARGET
        {
            fixed4 c = tex2D(_MainTex, i.uv);
            fixed val = clamp(ComputeLuminance(c) - _LuminanceThreshold, 0.0, 1.0);

            return c * val;
        }

        // Pass1 & Pass2 高斯模糊 shader
        struct v2fBlur
        {
            float4 pos : SV_POSITION;
            float2 uv[5] : TEXCOORD0;
        };

        v2fBlur vertBlurVertical(appdata_img v)
        {
            v2fBlur o;
            o.pos = UnityObjectToClipPos(v.vertex);
            float2 uv = v.texcoord;
            o.uv[0] = uv;
            o.uv[1] = uv + float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[2] = uv - float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[3] = uv + float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
            o.uv[4] = uv - float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
            
            return o;
        }

        v2fBlur vertBlurHorizontal(appdata_img v)
        {
            v2fBlur o;
            o.pos = UnityObjectToClipPos(v.vertex);
            float2 uv = v.texcoord;
            o.uv[0] = uv;
            o.uv[1] = uv + float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[2] = uv - float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[3] = uv + float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            o.uv[4] = uv - float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            
            return o;
        }

        fixed4 fragBlur(v2fBlur i) : SV_TARGET
        {
            float weight[3] = {0.4026, 0.2442, 0.0545};
            fixed3 sum = tex2D(_MainTex, i.uv[0]).rgb * weight[0];

            for (int it = 1; it <3; it++)
            {
                sum += tex2D(_MainTex, i.uv[2*it]).rgb * weight[it];
                sum += tex2D(_MainTex, i.uv[2*it-1]).rgb * weight[it];
            }

            return fixed4(sum, 1.0);
        }
        
        // Pass3 混合原图与模糊后的图像 shader
        struct v2fBloom
        {
            float4 pos : SV_POSITION;
            float4 uv : TEXCOORD0;
        };

        v2fBloom vertBloom(appdata_img v)
        {
            v2fBloom o;
            o.pos = UnityObjectToClipPos(v.vertex);

            o.uv.xy = v.texcoord;
            o.uv.zw = v.texcoord;

            // 平台差异处理
            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0.0)
                o.uv.w = 1.0 - o.uv.w;
            #endif

            return o;
        }

        fixed4 fragBloom(v2fBloom i) : SV_Target
        {
            return tex2D(_MainTex, i.uv.xy) + tex2D(_Bloom, i.uv.zw) * _Intensity;
        }
        
        ENDCG

        
        ZTest Always Cull Off ZWrite Off

        // Pass0 提取亮部区域
        Pass {
            CGPROGRAM
            #pragma vertex vertExtractBright
            #pragma fragment fragExtractBright
            ENDCG
        }
        
        // Pass1 高斯模糊_垂直
        Pass {
            CGPROGRAM
            #pragma vertex vertBlurVertical
            #pragma fragment fragBlur
            ENDCG
        }
        
        // Pass2 高斯模糊_水平
        Pass {
            CGPROGRAM
            #pragma vertex vertBlurHorizontal
            #pragma fragment fragBlur
            ENDCG
        }
        
        // Pass3 混合原图与模糊后的图像
        Pass {
            CGPROGRAM
            #pragma vertex vertBloom
            #pragma fragment fragBloom
            ENDCG
        }
    }
    FallBack "Diffuse"
}