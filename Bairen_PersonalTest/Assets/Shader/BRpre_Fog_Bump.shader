Shader "Bairen/BRpre_Fog_Bump" {
    Properties {
        [Header(Texture)]
            _MainTex ("RGB：基础颜色 A：环境遮蔽", 2D) = "white" {}
            _NormTex ("RGB：法线贴图", 2D) = "bump" {}
        [Header(Diffuse)]
            [HDR] _BaseCol ("漫反射基本色", COLOR) = (0.5, 0.5, 0.5, 1.0)
        [Header(Specular)]
            _SpecPow ("高光次幂", Range(1, 90)) = 30
            _SpecInt ("高光强度", Range(0, 1)) = 0.5
        [Header(Ambient)]
            _EnvCol("环境漫反射颜色", Color) = (1.0, 1.0, 1.0, 1.0)
            _EnvInt("环境漫反射强度", range(0, 10)) = 1.0
//        [Header(Fog)]
//            [Toggle] _CUSTOM_FOG("开启/关闭雾气", float) = 1
//            _FogCol("雾气颜色", Color) = (0.7, 0.8, 0.9, 1.0)
//            _FogInt("雾气强度", Range(0, 1)) = 0.5
//            _HeightFalloff("高度衰减速度", Range(0, 1)) = 1.0
//            _HeightBias("高度偏移", Range(-5, 20)) = 0.0
//            _DistFalloff("距离衰减速度", Range(1, 10)) = 1.0
//            _DistBias("距离偏移", Range(0, 20)) = 0.0
//            _ScatterPow("散射次幂", Range(0, 30)) = 1.0
//            _ScatterLight("散射光源方向", vector) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader {
        Tags {
            "RenderType"="Opaque"
        }
        Pass {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            //FogInclude
            #include "../cginc/PersonalHeader.cginc"

            #pragma multi_compile_fwdbase_fullshadows
            #pragma target 3.0
            #pragma shader_feature _CUSTOM_FOG_ON
            
            //Texture
            uniform sampler2D _MainTex;
            uniform sampler2D _NormTex;
            //Diffuse
            uniform fixed3 _BaseCol;
            //Specular
            uniform half _SpecPow;
            uniform half _SpecInt;
            //Ambient
            uniform fixed3 _EnvCol;
            uniform half _EnvInt;
            
            struct VertexInput {
                float4 vertex : POSITION;
                float2 uv0 : TEXCOORD0;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
            };
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float4 posWS : TEXCOORD1;
                float3 nDirWS : TEXCOORD2;
                float3 tDirWS : TEXCOORD3;
                float3 bDirWS : TEXCOORD4;
                LIGHTING_COORDS(5,6)
            };
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                o.pos = UnityObjectToClipPos( v.vertex );
                o.uv0 = v.uv0; 
                o.posWS = mul(unity_ObjectToWorld, v.vertex);
                o.nDirWS = UnityObjectToWorldNormal( v.normal );
                o.tDirWS = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.bDirWS = normalize(cross(o.nDirWS, o.tDirWS) * v.tangent.w);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                return o;
            }
            
            
            float4 frag(VertexOutput i) : COLOR {
                // 向量准备
                half3 nDirTS = UnpackNormal(tex2D(_NormTex, i.uv0)).rgb;
                half3x3 TBN = float3x3(i.tDirWS, i.bDirWS, i.nDirWS);
                half3 nDirWS = normalize(mul(nDirTS, TBN));
                half3 lDirWS = _WorldSpaceLightPos0.xyz;
                half3 lrDirWS = reflect(-lDirWS, nDirWS);
                half3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                half3 vrDirWS = reflect(-vDirWS, nDirWS);
                // 中间量准备
                half ndotl = dot(nDirWS, lDirWS);
                half vdotr = dot(vDirWS, lrDirWS);
                half vdotn = dot(vDirWS, nDirWS);
                // 纹理采样
                half3 var_MainTex = tex2D(_MainTex, i.uv0).rgb;
                // 光照模型
                    // 直接光照
                    half3 DiffCol = var_MainTex * _BaseCol;
                    half halfLambert = ndotl * 0.5 + 0.5;
                    half3 phong = pow(max(0.0, vdotr), _SpecPow);
                    // 直接光照合成
                    half shadow = LIGHT_ATTENUATION(i);
                    half3 dirLighting = (DiffCol * halfLambert + phong * _SpecInt) * min(shadow + 0.15, 1.0);
                    
                    // 间接光照
                    half3 envLighting = _EnvCol * _EnvInt;
                // 返回值
                half3 finalRGB = dirLighting + envLighting ;
                #ifdef _CUSTOM_FOG_ON
                    finalRGB = ExponentFog(finalRGB, i.posWS.xyz);
                #endif
                return fixed4(finalRGB, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}