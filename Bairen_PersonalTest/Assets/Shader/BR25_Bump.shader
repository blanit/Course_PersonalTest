Shader "Bairen/BR25_Bump" {
    Properties {
        [Header(Texture)]
            _MainTex ("RGB：基础颜色 A：环境遮蔽", 2D) = "white" {}
            _NormTex ("RGB：法线贴图", 2D) = "bump" {}
            _DispTex ("R: 高度贴图", 2d) = "black" {}
        [Header(Diffuse)]
            _BaseCol ("漫反射基本色", COLOR) = (0.5, 0.5, 0.5, 1.0)
        [Header(Bump)]
            _HeightScale ("Bump强度", range(0, 0.5)) = 0.1
            _NumLayers ("采样层数", range(4, 64)) = 16
            _NumIter ("迭代次数", range(10, 100)) = 20
            [KeywordEnum(A, B, C, D)]
            _BumpMode ("Bump类型", float) = 0
        [Header(Specular)]
            _SpecPow ("高光次幂", Range(1, 90)) = 30
            _SpecInt ("高光强度", Range(0, 1)) = 0.5
        [Header(Ambient)]
            _EnvCol("环境漫反射颜色", Color) = (1.0, 1.0, 1.0, 1.0)
            _EnvInt("环境漫反射颜色", Color) = (1.0, 1.0, 1.0, 1.0)
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
            
            #pragma multi_compile_fwdbase_fullshadows
            #pragma target 3.0
            #pragma multi_compile _BUMPMODE_A _BUMPMODE_B _BUMPMODE_C _BUMPMODE_D
            
            sampler2D _MainTex;
            sampler2D _NormTex;
            sampler2D _DispTex;
            uniform fixed3 _BaseCol;
            half _HeightScale;
            half _NumLayers;
            half _NumIter;
            half _BumpMode;
            uniform half _SpecPow;
            uniform half _SpecInt;
            uniform fixed3 _EnvCol;
            uniform half _EnvInt;

            // ------------------ Functions ------------------
            // Parallax Mapping
            float2 ParallaxMapping(sampler2D dispTex, float2 originUV, float3 vDirTS, float heightScale)
            {
                float height = tex2D(dispTex, originUV);
                return height * vDirTS.xy / vDirTS.z * heightScale;
            }
            
            // Steep Parallax Mapping
            float4 SteepParallaxMapping(sampler2D dispTex, float2 originUV, float numLayers, float3 vDirTS, float heightScale)
            {
                float2 currentUV = originUV;
                float layerHeight = 1.0 / numLayers;
                float currentLayerHeight = 0.0;
                float heightMapValue = tex2D(dispTex, currentUV).r;
                
                [loop]
                while(currentLayerHeight < heightMapValue)
                {
                    currentUV += vDirTS.xy / vDirTS.z * layerHeight * heightScale;
                    currentLayerHeight += layerHeight;
                    heightMapValue = tex2D(dispTex, currentUV).r;
                }

                // return float4(uvBias, currentLayerHeight, heightMapValue)
                return float4(currentUV - originUV, currentLayerHeight, heightMapValue);        
            }

            // Relief Mapping
            float2 ReliefMapping(sampler2D dispTex, float2 originUV, float numLayers, float3 vDirTS, float heightScale, float numIter)
            {
                float2 uvBias = SteepParallaxMapping(dispTex, originUV, numLayers, vDirTS, heightScale).xy;

                float2 t0 = originUV;
                float2 t1 = originUV + uvBias;
                
                for (int it = 1; it < numIter; it++)
                {
                    float2 midT = (t0 + t1) / 2;
                    float midHeightMapValue = tex2D(dispTex, midT).r;
                    float midLayerHeight = length(midT - originUV) / length(vDirTS.xy / vDirTS.z * heightScale);
                    if (midHeightMapValue > midLayerHeight)
                    {
                        t0 = midT;
                    }
                    else
                    {
                        t1 = midT;
                    }
                }

                return (t0 + t1) / 2 - originUV;
            }

            // Parallax Occlusion Mapping
            float2 ParallaxOcclusionMapping(sampler2D dispTex, float2 originUV, float numLayers, float3 vDirTS, float heightScale)
            {
                float4 var_spm = SteepParallaxMapping(dispTex, originUV, numLayers, vDirTS, heightScale);
                float2 uvBias = var_spm.xy;
                float currentLayerHeight = var_spm.z;
                float heightMapValue = var_spm.w;
                float2 biasStep = vDirTS.xy / vDirTS.z / numLayers * heightScale;

                float2 prevBias = uvBias - biasStep;
                float2 postBias = uvBias;
                float2 prevH = tex2D(dispTex, originUV + prevBias).r - (currentLayerHeight - 1 / numLayers);
                float2 postH = heightMapValue - currentLayerHeight;

                float weight = postH / (postH - prevH);

                uvBias = prevBias * weight + postBias * (1.0 - weight);
                return uvBias;
            }
            
            // Transform_WorldToTangent
            float3 Transform_WorldToTangent(float3 DirWS, float3x3 TBN)
            {
                return normalize(mul(TBN, DirWS));
            }

            // ------------------ Functions ------------------

            struct VertexInput {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
            };
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 posWS : TEXCOORD1;
                float3 nDirWS : TEXCOORD2;
                float3 tDirWS : TEXCOORD3;
                float3 bDirWS : TEXCOORD4;
                LIGHTING_COORDS(5,6)
            };
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                o.pos = UnityObjectToClipPos( v.vertex );
                o.uv = v.uv;
                o.posWS = mul(unity_ObjectToWorld, v.vertex);
                o.nDirWS = UnityObjectToWorldNormal( v.normal );
                o.tDirWS = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.bDirWS = normalize(cross(o.nDirWS, o.tDirWS) * v.tangent.w);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                return o;
            }
            float4 frag(VertexOutput i) : SV_Target {

                half3x3 TBN = half3x3(i.tDirWS, i.bDirWS, i.nDirWS);
                half3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                half3 vDirTS = Transform_WorldToTangent(vDirWS, TBN);

                float2 uvBias1 = ParallaxMapping(_DispTex, i.uv, vDirTS, _HeightScale);
                float2 uvBias2 = SteepParallaxMapping(_DispTex, i.uv, _NumLayers, vDirTS, _HeightScale);
                float2 uvBias3 = ReliefMapping(_DispTex, i.uv, _NumLayers, vDirTS, _HeightScale, _NumIter);
                float2 uvBias4 = ParallaxOcclusionMapping(_DispTex, i.uv, _NumLayers, vDirTS, _HeightScale);

                float2 uvBias = float2(0.0, 0.0);
                #ifdef _BUMPMODE_A
                    uvBias = ParallaxMapping(_DispTex, i.uv, vDirTS, _HeightScale);
                #endif

                #ifdef _BUMPMODE_B
                    uvBias = SteepParallaxMapping(_DispTex, i.uv, _NumLayers, vDirTS, _HeightScale);
                #endif

                #ifdef _BUMPMODE_C
                    uvBias = ReliefMapping(_DispTex, i.uv, _NumLayers, vDirTS, _HeightScale, _NumIter);
                #endif

                #ifdef _BUMPMODE_D
                    uvBias = ParallaxOcclusionMapping(_DispTex, i.uv, _NumLayers, vDirTS, _HeightScale);
                #endif
                

                float bumpMode = _BumpMode;
                
                // 向量准备
                half3 nDirTS = UnpackNormal(tex2D(_NormTex, i.uv + uvBias)).rgb;   // after uvBias
                half3 nDirWS = normalize(mul(nDirTS, TBN));
                half3 lDirWS = _WorldSpaceLightPos0.xyz;
                half3 lrDirWS = reflect(-lDirWS, nDirWS);
                half3 vrDirWS = reflect(-vDirWS, nDirWS);
                // 中间量准备
                half ndotl = dot(nDirWS, lDirWS);
                half vdotr = dot(vDirWS, lrDirWS);
                half vdotn = dot(vDirWS, nDirWS);
                // 纹理采样
                half3 var_MainTex = tex2D(_MainTex, i.uv + uvBias).rgb;                        // after uvBias
                
                // 光照模型
                    // 直接光照
                    half3 DiffCol = var_MainTex * _BaseCol;
                    half Lambert = max(0.0, ndotl);
                    half3 phong = pow(max(0.0, vdotr), _SpecPow);
                    // 直接光照合成
                    half shadow = LIGHT_ATTENUATION(i);
                    half3 dirLighting = (DiffCol * Lambert + phong * _SpecInt) * shadow;
                    
                    // 间接光照
                    half3 envLighting = _EnvCol * _EnvInt;
                // 返回值
                half3 finalRGB = dirLighting + envLighting ;
                return fixed4(finalRGB, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}