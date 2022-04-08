Shader "BR/BR33_cloudAB" {
    Properties {
        _MainTex ("RGB：颜色 A：透贴", 2d) = "gray"{}
        _Opacity ("透明度", range(0, 1)) = 0.5
        
        [Header(Cloud)]
            _Noise ("Noise", 2d) = "black" {}
            _CloudRotation ("Cloud Rotation", range(0, 0.1)) = 0.03
        
        _NightRCol ("Night R", color) = (0.5, 0.5, 0.5, 1.0)
        _NightGCol ("Night G", color) = (0.5, 0.5, 0.5, 1.0)
        _NightBCol ("Night B", color) = (0.5, 0.5, 0.5, 1.0)
        _DayRCol ("Day R", color) = (0.5, 0.5, 0.5, 1.0)
        _DayGCol ("Day G", color) = (0.5, 0.5, 0.5, 1.0)
        _DayBCol ("Day B", color) = (0.5, 0.5, 0.5, 1.0)
    }
    SubShader {
        Tags {
            "Queue"="Transparent"               // 调整渲染顺序
            "RenderType"="Transparent"          // 对应改为Cutout
            "ForceNoShadowCasting"="True"       // 关闭阴影投射
            "IgnoreProjector"="True"            // 不响应投射器
        }
        Pass {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
            Cull Front
            ZWrite Off
            Blend One One
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #pragma multi_compile_fwdbase_fullshadows
            #pragma target 3.0
            
            // 输入参数
            sampler2D _MainTex; uniform float4 _MainTex_ST;
            half _Opacity;
            sampler2D _Noise;
            float4 _Noise_ST;

            half _CloudRotation;
            
            half3 _NightRCol;
            half3 _NightGCol;
            half3 _NightBCol;
            half3 _DayRCol;
            half3 _DayGCol;
            half3 _DayBCol;

            #define TWO_PI 6.283185
            // 顶点动画方法
            void Rotation (inout float3 vertex) {
                float radZ = frac(_Time.x * _CloudRotation) * UNITY_TWO_PI;
                float sinZ, cosZ = 0;
                sincos(radZ, sinZ, cosZ);
                vertex.xy = float2(
                    vertex.x * cosZ - vertex.y * sinZ,
                    vertex.x * sinZ + vertex.y * cosZ
                );
            }
            
            struct VertexInput {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 posWS : TEXCOORD1;
            };
            
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                    Rotation(v.vertex.xyz);
                    o.pos = UnityObjectToClipPos(v.vertex);    // 顶点位置 OS>CS
                    o.uv = TRANSFORM_TEX(v.uv, _MainTex);       // UV信息 支持TilingOffset
                    o.posWS = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }
            
            half4 frag(VertexOutput i) : COLOR {
                half timeCtrl = _WorldSpaceLightPos0.y;
                
                float2 biasUV1 = i.uv + frac(_Time.y * 0.3) * tex2D(_Noise, float4(i.uv, 0.0, 0.0) * _Noise_ST.xy) * 0.005;
                float2 biasUV2 = i.uv + frac(_Time.y * 0.3 + 0.5) * tex2D(_Noise, float4(i.uv, 0.0, 0.0) * _Noise_ST.xy) * 0.005;
                
                half4 var_MainTex1 = tex2D(_MainTex, biasUV1);      // 采样贴图 RGB颜色 A透贴
                half4 var_MainTex2 = tex2D(_MainTex, biasUV2);      // 采样贴图 RGB颜色 A透贴
                half4 var_MainTex = lerp(var_MainTex1, var_MainTex2, abs((0.5 - frac(_Time.y * 0.3)) / 0.5));
                
                half3 gradientCloudRCol = lerp(_NightRCol, _DayRCol, saturate(timeCtrl));
                half3 gradientCloudGCol = lerp(_NightGCol, _DayGCol, saturate(timeCtrl));
                half3 gradientCloudBCol = lerp(_NightBCol, _DayBCol, saturate(timeCtrl));
                half3 finalRGB = var_MainTex.r * gradientCloudRCol + var_MainTex.g * gradientCloudGCol + var_MainTex.b * gradientCloudBCol;
                
                half opacity = _Opacity * var_MainTex.a * saturate(i.posWS.y / 4.0);        // A通道透贴在fragment shader中计算
                return half4(finalRGB * opacity, opacity);     // 返回值
            }
            ENDCG
        }
    }
}