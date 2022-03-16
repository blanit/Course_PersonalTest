Shader "Bairen/BR26_Gamma_Phong"{
    Properties {
        _MainCol ("颜色", color) = (1.0, 1.0, 1.0, 1.0)
        _SpecularPow ("高光次幂", range(1, 90)) = 30
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
            
            uniform float3 _MainCol;
            uniform float _SpecularPow;
            
            struct VertexInput {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            struct VertexOutput {
                float4 posCS : SV_POSITION;
                float4 posWS : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
            };
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                    o.posCS = UnityObjectToClipPos(v.vertex);
                    o.posWS = mul(unity_ObjectToWorld, v.vertex);
                    o.nDirWS = UnityObjectToWorldNormal(v.normal);
                return o;
            }
            
            float4 frag(VertexOutput i) : SV_Target {

                float3 nDir = normalize(i.nDirWS);
                float3 lDir = _WorldSpaceLightPos0.xyz;
                float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 rDir = reflect(-lDir, nDir);
                
                float nDotl = dot(nDir, lDir);
                float rDotv = dot(rDir, vDir);

                float Lambert = max(0.0, nDotl);
                float Phong = pow(max(0.0, rDotv), _SpecularPow);
                float3 finalRGB = _MainCol * Lambert + Phong;
                finalRGB = pow(finalRGB, 2.2);

                return float4(finalRGB, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}