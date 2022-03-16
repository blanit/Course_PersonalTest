Shader "Bairen/HDR_CE" {
    Properties {
        _Cubemap    ("环境球", Cube) = "_Skybox" {}
        _NormalMap  ("法线贴图", 2D) = "bump" {}
        _CubemapMip ("环境球Mip", Range(0, 7)) = 0
        _FresnelPow ("菲涅尔次幂", Range(0, 5)) = 0
        _EnvSpecInt ("环境镜面反射强度", Range(0, 5)) = 1
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
            #pragma multi_compile_fwdbase_fullshadows
            #pragma target 3.0
            // 输入参数
            uniform samplerCUBE _Cubemap;
            uniform sampler2D _NormalMap;
            uniform float _CubemapMip;
            uniform float _FresnelPow;
            uniform float _EnvSpecInt;
            // 输入结构
            struct VertexInput {
                float4 vertex : POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };
            // 输出结构
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float4 posWS : TEXCOORD1;
                float3 nDirWS : TEXCOORD2;
                float3 tDirWS : TEXCOORD3;
                float3 bDirWS : TEXCOORD4;
            };
            // 顶点Shader
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                    o.pos = UnityObjectToClipPos( v.vertex );
                    o.uv0 = v.uv0;
                    o.posWS = mul(unity_ObjectToWorld, v.vertex);
                    o.nDirWS = UnityObjectToWorldNormal(v.normal);
                    o.tDirWS = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                    o.bDirWS = normalize(cross(o.nDirWS, o.tDirWS) * v.tangent.w);
                return o;
            }
            // 像素Shader
            float4 frag(VertexOutput i) : COLOR {
                // 准备向量
                float3 nDirTS = UnpackNormal(tex2D(_NormalMap, i.uv0)).rgb;
                float3x3 TBN = float3x3(i.tDirWS, i.bDirWS, i.nDirWS);
                float3 nDirWS = normalize(mul(nDirTS, TBN));   // 计算Fresnel 计算vrDirWS
                float3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);  // 计算Fresnel
                float3 vrDirWS = reflect(-vDirWS, nDirWS);     // 采样Cubemap

                // 准备中间变量
                float vdotn = dot(vDirWS, nDirWS);

                // 光照模型
                float3 var_Cubemap = texCUBElod(_Cubemap, float4(vrDirWS, _CubemapMip)).rgb;
                //CE
                var_Cubemap = 1 - exp(-var_Cubemap);
                float3 envSpecLighting = var_Cubemap * _EnvSpecInt;

                // 返回值
                return float4(envSpecLighting, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}