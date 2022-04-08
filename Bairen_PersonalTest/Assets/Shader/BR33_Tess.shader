Shader "BR/BR33_Tess" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
        _TessellationUniform ("Tessellation Uniform", range(1, 32)) = 4
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
            #pragma hull hs
            #pragma domain ds
            #pragma vertex tessvert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Tessellation.cginc"

            struct a2v
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent: TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            v2f vert(a2v v)                                 // Domain Shader中处理坐标
            {
                v2f o;
                o.pos = UnityObjectToClipPos( v.vertex );
                return o;
            }

            #ifdef UNITY_CAN_COMPILE_TESSELLATION
                struct TessVertex
                {
                    float4 vertex : INTERNALTESSPOS;
                    float3 normal : NORMAL;
                    float4 tangent : TANGENT;
                    float2 uv : TEXCOORD0;
                };

                struct OutputPatchConstant                  // Hull Shader参数，不同图元会有所不同
                {
                    float edge[3]   : SV_TESSFACTOR;
                    float inside    : SV_INSIDETESSFACTOR;
                };

                TessVertex tessvert(a2v v)                  // 正常的Vertex Shader
                {
                    TessVertex o;
                    o.vertex = v.vertex;
                    o.normal = v.normal;
                    o.tangent = v.tangent;
                    o.uv = v.uv;
                    return o;
                }

                float _TessellationUniform;
                OutputPatchConstant hsconst (InputPatch<TessVertex, 3> patch)
                {
                    OutputPatchConstant o;
                    o.edge[0] = _TessellationUniform;
                    o.edge[1] = _TessellationUniform;
                    o.edge[2] = _TessellationUniform;
                    o.inside = _TessellationUniform;
                    return o;
                }

                // Hull Shader
                [UNITY_domain("tri")]                       // 定义图元: quad,tri
                [UNITY_partitioning("fractional_odd")]      // 切分Edge的方式: equal_spacing, fractional_odd, fractional_even
                [UNITY_outputtopology("triangle_cw")]       // 输出三角形的顶点连接顺序: 顺时针or逆时针, 影响之后剔除功能
                [UNITY_patchconstantfunc("hsconst")]
                [UNITY_outputcontrolpoints(3)]
                TessVertex hs (InputPatch<TessVertex, 3> patch, uint id: SV_OutputControlPointID)
                {
                    return patch[id];
                }

                // Domain Shader
                [UNITY_domain("tri")]                       // 定义图元: quad,tri
                v2f ds (OutputPatchConstant tessFactors, const OutputPatch<TessVertex, 3>patch, float3 bary : SV_DomainLocation)
                {
                    a2v v;
                    v.vertex = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
                    v.tangent = patch[0].tangent * bary.x + patch[1].tangent * bary.y + patch[2].tangent * bary.z;
                    v.normal = patch[0].normal * bary.x + patch[1].normal * bary.y + patch[2].normal * bary.z;
                    v.uv = patch[0].uv * bary.x + patch[1].uv * bary.y + patch[2].uv * bary.z;
                    v2f o = vert(v);
                    return o;
                }
            #endif
            

            float4 frag(v2f i) : SV_Target
            {
                //向量准备
                //中间量准备
                //光照模型
                //返回值
                return fixed4(0.5, 0.5, 0.5, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}