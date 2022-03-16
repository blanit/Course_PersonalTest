Shader "Bairen/Default_BlinnPhong" {
    Properties {
        [Header(Texture)]
            _MainTex ("RGB：基础颜色 A：环境遮蔽", 2D) = "white" {}
            _NormTex ("RGB：法线贴图", 2D) = "bump" {}
            _SpecTex ("RGB：高光颜色 A：高光次幂", 2D) = "gray" {}//高光次幂同时控制光滑度
            _EmitTex ("RGB：自发光贴图", 2D) = "black" {}
            _CubeMap ("RBG：环境贴图CubeMap", cube) = "_skybox" {}
        [Header(Diffuse)]
            _BaseCol ("漫反射基本色", COLOR) = (0.5, 0.5, 0.5, 1.0)
        [Header(Specular)]
            _SpecPow ("高光次幂", Range(1, 90)) = 30
            _SpecInt ("高光强度", Range(0, 5)) = 1
        [Header(Ambient)]
            _EnvUpCol ("环境天顶颜色", Color) = (1.0, 1.0, 1.0, 1.0)
            _EnvSideCol ("环境水平颜色", Color) = (0.5, 0.5, 0.5, 1.0)
            _EnvDownCol ("环境地表颜色", Color) = (0.0, 0.0, 0.0, 0.0)
            _EnvDiffInt ("环境漫反射强度", Range(0, 5)) = 0.2
            _EnvSpecInt ("环境镜面反射强度", Range(0, 5)) = 0.2
            _FresnelPow ("菲涅尔次幂", Range(0, 5)) = 1
            _CubeMapMip ("环境球Mip", Range(0, 7)) = 0
        [Header(Emission)]
            _Emission ("自发光强度", Range(1, 10)) = 1
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
            //shadow include 
            #pragma multi_compile_fwdbase_fullshadows
            #pragma target 3.0
            
            //Texture
            uniform sampler2D _MainTex;
            uniform sampler2D _NormTex;
            uniform sampler2D _SpecTex;
            uniform sampler2D _EmitTex;
            uniform samplerCUBE _CubeMap;
            //Diffuse
            uniform float3 _BaseCol;
            //Specular
            uniform float _SpecPow;
            uniform float _SpecInt;
            //Ambient
            uniform float3 _EnvUpCol;
            uniform float3 _EnvSideCol;
            uniform float3 _EnvDownCol;
            uniform float _EnvDiffInt;
            uniform float _FresnelPow;
            uniform float _CubeMapMip;
            uniform float _EnvSpecInt;
            //Emission
            uniform float _Emission;

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
                float3 nDirTS = UnpackNormal(tex2D(_NormTex, i.uv0)).rgb;
                float3x3 TBN = float3x3(i.tDirWS, i.bDirWS, i.nDirWS);
                float3 nDirWS = normalize(mul(nDirTS, TBN));
                float3 lDirWS = _WorldSpaceLightPos0.xyz;
                float3 lrDirWS = reflect(-lDirWS, nDirWS);
                float3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                float3 vrDirWS = reflect(-vDirWS, nDirWS);
                // 中间量准备
                float ndotl = dot(nDirWS, lDirWS);
                float vdotr = dot(vDirWS, lrDirWS);
                float vdotn = dot(vDirWS, nDirWS);
                // 纹理采样
                float4 var_MainTex = tex2D(_MainTex, i.uv0);
                float4 var_SpecTex = tex2D(_SpecTex, i.uv0);
                float3 var_EmitTex = tex2D(_EmitTex, i.uv0);
                float3 var_CubeMap = texCUBElod(_CubeMap, float4(vrDirWS, lerp(_CubeMapMip, 0.0, var_SpecTex.a))).rgb;
                // 光照模型
                    // 直接光照_Diffuse_Lambert
                    float3 DiffCol = var_MainTex.rgb * _BaseCol;
                    float Lambert = max(0.0, ndotl);
                    // 直接光照_Specular_Phong
                    float3 SpecCol = var_SpecTex.rgb;
                    float SpecPow = lerp(1.0, _SpecPow, var_SpecTex.a);
                    float3 phong = pow(max(0.0, vdotr), _SpecPow);
                    // 直接光照合成
                    float shadow = LIGHT_ATTENUATION(i);
                    float3 dirLighting = (DiffCol * Lambert + SpecCol * phong * _SpecInt) * _LightColor0 * shadow;
                    
                    // 间接光照
                    float upMask = max(0.0, nDirWS.g);          // 获取朝上部分遮罩
                    float downMask = max(0.0, -nDirWS.g);       // 获取朝下部分遮罩
                    float sideMask = 1.0 - upMask - downMask;   // 获取侧面部分遮罩
                    float3 envCol = _EnvUpCol * upMask +
                                    _EnvSideCol * sideMask +
                                    _EnvDownCol * downMask;     // 混合环境色
                    float fresnel = pow(max(0.0, 1.0 - vdotn), _FresnelPow);
                    // 间接光照合成
                    float occlusion = var_MainTex.a;
                    float3 envLighting = (envCol * DiffCol * _EnvDiffInt + fresnel * var_CubeMap * _EnvSpecInt * var_SpecTex.a) * occlusion;
                    // 自发光
                    float3 emission = var_EmitTex * _Emission;
                // 返回值
                float3 finalRGB = dirLighting + envLighting + emission;
                return float4(finalRGB, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}