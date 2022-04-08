Shader "BR/BR33_halfLambert_grass" {
    Properties {
        _MainTex ("MainTex", 2d) = "white" {}
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

            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            struct VertexInput {
                float4 vertex : POSITION;
                float4 normal : NORMAL;
                float4 uv : TEXCOORD0;
            };
            
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float3 nDirWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
            };
            
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.nDirWS = UnityObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                return o;
            }
            
            float4 frag(VertexOutput i) : COLOR {
                float3 nDir = normalize(i.nDirWS);
                float3 lDir = _WorldSpaceLightPos0.xyz;
                float nDotl = dot(i.nDirWS, lDir);
                float halflambert = nDotl * 0.5 + 0.5;
                halflambert = smoothstep(0.15, 0.7, halflambert);
                float3 ambient = float3(0.0, 0.005, 0.01) * 0.5 * (1.0 - halflambert);
                float3 finalRGB = halflambert * tex2D(_MainTex, i.uv).rgb * 0.6 + ambient;
                return float4(finalRGB, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}