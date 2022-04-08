Shader "BR/BR33_TessGeo_Grass" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
        _TessellationUniform ("细分系数", range(1, 32)) = 4
        _Parameter ("x:width,y:height,z:forward", vector) = (0.5, 0.5, 0.5, 0.5)
        _BladeCurve ("弯曲度衰减", range(0.1, 2.0)) = 0.5
        [Header(Color)]
            _LightCol ("光照颜色", color) = (1.0, 1.0, 1.0, 1.0)
            _GrassColTop ("草上部颜色", color) = (0.0, 0.0, 0.0, 1.0)
            _GrassColBot ("草下部颜色", color) = (0.0, 0.0, 0.0, 1.0)
            _GradientParameter ("渐变系数", range(0, 1)) = 0.5
            _DeepGradient ("深度渐变", range(0, 1)) = 0.2
        [Header(Random)]
            _BladeWidthRandom ("宽度随机强度", range(0, 0.03)) = 0.015
            _BladeHeightRandom ("高度随机强度", range(0, 0.3)) = 0.12
            _bendRandInt ("弯曲随机强度", range(0, 0.3)) = 0.15
        [Header(Wind)]
            _WindMap ("Wind Map", 2D) = "black" {}
            _WindSpeed ("Wind Speed", range(0, 2)) = 1.0
            _WindStrength ("Wind Strength", range(0, 2)) = 1.0
            [Toggle]
            _WindTest ("WindTest", Int) = 0
    }
    SubShader {
        Tags {
            "RenderType"="Opaque"
        }
        
        Cull Off
        
        Pass {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
            
            
            CGPROGRAM
            #pragma vertex vert
            #pragma hull hs
            #pragma domain ds
            #pragma geometry geo
            #pragma fragment frag
            #pragma target 4.6
            
            #pragma shader_feature _WINDTEST_ON
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "Tessellation.cginc"
            #include "../cginc/PersonalHeader.cginc"

            sampler2D _MainTex;
            sampler2D _WindMap;
            float4 _WindMap_ST;
            half4 _Parameter;

            half3 _LightCol;
            half3 _GrassColTop;
            half3 _GrassColBot;
            half _GradientParameter;
            half _DeepGradient;
            
            half _BladeCurve;
            half _BladeWidthRandom;
            half _BladeHeightRandom;
            half _bendRandInt;

            half _WindSpeed;
            half _WindStrength;

            half _WindTest;

            #define BLADE_SEGMENTS 3
            #define test_const float3(0.5, 0.5, 0.5)
        
            // --------------------- function ---------------------
            // Simple noise function.sourced from http://answers.unity.com/answers/624136/view.html
            // Extended discussion on this function can be found at the following link:
            // https://forum.unity.con/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
            // Returns a number in the 0...1 range.
            // 生成随机数
            float rand(float3 co)
            {
                return frac(sin(dot(co.xyz,float3(12.9898,78.233,53.539))) * 43758.5453);
            }

            // Construct a rotation matrix that rotates around the provided axis,sourced from:
            // https://rist.rithub.com/keiiiro/ee439d5e7388f3aafc5296005c8c3f33
            float3x3 AngleAxis3x3(float angle, float3 axis)//旋转矩阵
            {
                float c,s;

                sincos(angle,s,c);

                float t = 1 - c;
                float x = axis.x;
                float y = axis.y;
                float z = axis.z;

                return float3x3(
                t * x * x + c, t * x * y - s * z, t * x * z + s * y,
                t * x * y + s * z, t * y * y + c, t * y * z - s * x,
                t * x * z - s * y, t * y * z + s * x, t * z * z + c
                );
            }

            // hsv from: https://www.laurivan.com/rgb-to-hsv-to-rgb-for-shaders/
            float3 rgb2hsv(float3 c)
            {
                float4 k = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, k.wz), float4(c.gb, k.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            float3 hsv2rgb(float3 c)
            {
                float4 k = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + k.xyz) * 6.0 - k.www); 
                return c.z * lerp(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
            }


            
            
            // --------------------- struct ---------------------
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
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct geometryOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 posOS : TEXCOORD1;
                float3 posTS : TEXCOORD2;
                float3 posWS : TEXCOORD3;
                float3 nDirWS : TEXCOORD4;
            };

            // --------------------- VertexShader ---------------------
            v2f vert(a2v v)                                 // 直接传出，具体操作在几何着色器中进行
            {
                v2f o;

                o.pos = v.vertex;
                o.normal = v.normal;
                o.tangent = v.tangent;
                o.uv = v.uv;
                
                return o;
            }

            // --------------------- TessShader ---------------------
            #ifdef UNITY_CAN_COMPILE_TESSELLATION

                struct OutputPatchConstant                  // Hull Shader参数，不同图元会有所不同
                {
                    float edge[3]   : SV_TESSFACTOR;
                    float inside    : SV_INSIDETESSFACTOR;
                };

                float _TessellationUniform;
                OutputPatchConstant hsconst (InputPatch<v2f, 3> patch)
                {
                    OutputPatchConstant o;
                    float minDist = 10.0;
                    float maxDist = 25.0;
                    float4 distanceFactor = UnityDistanceBasedTess(patch[0].pos, patch[1].pos, patch[2].pos, minDist,
                     maxDist, _TessellationUniform);    // 距离控制密度
                    o.edge[0] = distanceFactor.x;
                    o.edge[1] = distanceFactor.y;
                    o.edge[2] = distanceFactor.z;
                    o.inside = distanceFactor.w;
                    return o;
                }

                // Hull Shader
                [UNITY_domain("tri")]                       // 定义图元: quad,tri
                [UNITY_partitioning("fractional_odd")]      // 切分Edge的方式: equal_spacing, fractional_odd, fractional_even
                [UNITY_outputtopology("triangle_cw")]       // 输出三角形的顶点连接顺序: 顺时针or逆时针, 影响之后剔除功能
                [UNITY_patchconstantfunc("hsconst")]
                [UNITY_outputcontrolpoints(3)]
                v2f hs (InputPatch<v2f, 3> patch, uint id: SV_OutputControlPointID)
                {
                    return patch[id];
                }

                // Domain Shader
                [UNITY_domain("tri")]                       // 定义图元: quad,tri
                v2f ds (OutputPatchConstant tessFactors, const OutputPatch<v2f, 3>patch, float3 bary : SV_DomainLocation)
                {
                    a2v v;
                    v.vertex = patch[0].pos * bary.x + patch[1].pos * bary.y + patch[2].pos * bary.z;
                    v.tangent = patch[0].tangent * bary.x + patch[1].tangent * bary.y + patch[2].tangent * bary.z;
                    v.normal = patch[0].normal * bary.x + patch[1].normal * bary.y + patch[2].normal * bary.z;
                    v.uv = patch[0].uv * bary.x + patch[1].uv * bary.y + patch[2].uv * bary.z;
                    v2f o = vert(v);
                    return o;
                }
            #endif
            
            
            // --------------------- GeometryShader ---------------------
            geometryOutput GenerateGrassVertex(float3 pos, float2 uv, float width, float forward, float height, 
            float3x3 transformMatrix, float3x3 tangentToLocal, float3 normal)
            {
                geometryOutput o;
                float3 posOS = pos + mul(transformMatrix, float3(width, forward, height));
                o.pos = UnityObjectToClipPos(posOS);
                o.posWS = mul(unity_ObjectToWorld, posOS);
                o.posOS = posOS;
                o.posTS = mul(posOS - pos, tangentToLocal);
                o.nDirWS = UnityObjectToWorldNormal(normal);
                o.uv = uv;
                return o;
            }

            [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]                            // 最大输出顶点数量，可以使用参数控制
            void geo(triangle v2f IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
            {
                float3 pos = IN[1].pos;                                         // position of OS
                float3 vNormal = IN[1].normal;
                float4 vTangent = IN[1].tangent;
                float3 vBinormal = cross(vNormal, vTangent) * vTangent.w;

                    
                // random
                float width = (rand(pos.zyx) * 2 -1) * _BladeWidthRandom + _Parameter.x;
                float height = (rand(pos.xzy) * 2 -1) * _BladeHeightRandom + _Parameter.y;
                float forward = rand(pos.yyz) * _Parameter.z;

                // wind
                float2 windUV = pos.xz * _WindMap_ST.xy + _WindMap_ST.zw + frac(_WindSpeed * _Time.x);
                float var_windMap = tex2Dlod(_WindMap, float4(windUV, 0.0, 0.0)).x;
                float3 wind = normalize(float3(var_windMap.x, var_windMap.x, 0.0));
                var_windMap = smoothstep(0.05, 0.9, var_windMap) * _WindStrength;
                float3x3 windRotation = AngleAxis3x3(UNITY_PI * var_windMap, wind);

                // Transformation Matrix
                float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI,float3(0.0, 0.0, 1.0));
                float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * UNITY_TWO_PI * _bendRandInt,float3(-1.0, 0.0, 0.0));
                float3x3 tangentToLocal = transpose(float3x3(vTangent.xyz, vBinormal, vNormal));

                float3x3 transMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix), bendRotationMatrix);
                    
                geometryOutput o;

                // triStream.Append(CreateGeoOutput(pos + mul(tangentToLocal, float3(_Parameter.x, 0, 0)), float2(0, 0)));
                // triStream.Append(CreateGeoOutput(pos + mul(tangentToLocal, float3(-_Parameter.x, 0, 0)), float2(1, 0)));
                // triStream.Append(CreateGeoOutput(pos + mul(tangentToLocal, float3(0, 0, _Parameter.y)), float2(0.5, 1)));

                // 默认使用triangle trip模式，循环创建三角形的左右端点，最后创健三角形最上面的顶点，自动形成三角形
                // 如果需要自定义每一个三角形，可以使用RestartStrip
                for (int iter = 0; iter < BLADE_SEGMENTS; iter++)
                {
                    float t = iter / (float)BLADE_SEGMENTS;
                    float segmentHeight = height * t;
                    float segmentWidth = width * (1 - t);
                    float segmentForward = pow(t, _BladeCurve) * forward;

                    triStream.Append(GenerateGrassVertex(pos, float2(0, t), segmentWidth, segmentForward, 
                    segmentHeight, transMatrix, tangentToLocal, vNormal));
                    triStream.Append(GenerateGrassVertex(pos, float2(1, t), -segmentWidth, segmentForward, 
                    segmentHeight, transMatrix, tangentToLocal, vNormal));
                    // triStream.Append(GenerateGrassVertex(pos + float3(var_windMap, 0.0) * t + mul(tangentToLocal, float3(segmentWidth, segmentForward, segmentHeight)), float2(0, t)));
                    // triStream.Append(GenerateGrassVertex(pos + float3(var_windMap, 0.0) * t + mul(tangentToLocal, float3(-segmentWidth, segmentForward, segmentHeight)), float2(1, t)));
                }

                triStream.Append(GenerateGrassVertex(pos, float2(0.5, 1), 0.0, forward, height, transMatrix, tangentToLocal, vNormal));
                // triStream.Append(GenerateGrassVertex(pos + float3(var_windMap, 0.0) + mul(tangentToLocal, float3(0.0, forward, height)), float2(0.5, 1)));
                // 切线空间坐标系为右手系,z轴向上
                
            }
            

            float4 frag(geometryOutput i) : SV_Target
            {
                //向量准备
                half3 lDirWS = _WorldSpaceLightPos0.xyz;
                half3 nDirWS = normalize(i.nDirWS);
                half3 vDirWS = normalize(_WorldSpaceCameraPos - i.posWS);
                half ndotl = dot(lDirWS, nDirWS);
                half ldotvr = saturate(dot(lDirWS, reflect(-vDirWS, nDirWS)));
                half reverseldotvr = saturate(dot(-lDirWS, reflect(-vDirWS, nDirWS)));
                

                
                
                // windCol
                    float2 windUV = i.posOS.xz * _WindMap_ST.xy + _WindMap_ST.zw + frac(_WindSpeed * _Time.x * 2.0);
                    float var_windMap = tex2Dlod(_WindMap, float4(windUV, 0.0, 0.0)).x;

                    // float2 windUV2 = i.posOS.xz * _WindMap_ST.xy + _WindMap_ST.zw + frac(_WindSpeed * _Time.x);
                    // float var_windMap2 = tex2Dlod(_WindMap, float4(windUV2, 0.0, 0.0)).x;
                    // var_windMap2 = smoothstep(0.05, 0.9, var_windMap2) * _WindStrength;


                //中间量准备
                //光照模型
                //返回值

                float camDist = i.pos.z / _DeepGradient;
                
                half3 grassCol = lerp(_GrassColBot, _GrassColTop, i.posTS.z / _GradientParameter);

                // HSV
                float3 hsv = rgb2hsv(grassCol);
                hsv.x += var_windMap * 0.5 * 0.07 + saturate(1.0 - camDist) * 0.05;                   // _Hue
                hsv.y *= 1.0 - saturate(1.0 - camDist) * 0.1;                                       // _Saturation
                hsv.z *= 1.0 - var_windMap * 3 * 0.07 - saturate(1.0 - camDist) * 0.2;              // _Value
                grassCol = hsv2rgb(hsv);

                #ifdef _WINDTEST_ON
                    grassCol = ndotl ;
                    // grassCol = i.posTS.z / _GradientParameter;
                #endif

                half Lambert = smoothstep(0.15, 0.7, saturate(ndotl * 0.5 + 0.5));

                // half specularAngle = 0.15 * UNITY_PI;
                // half3x3 specularTransMatrix = AngleAxis3x3(specularAngle, float3(0.0, 1.0, 0.0));
                // half3 lDirWS_spec = mul(specularTransMatrix, lDirWS);
                // half ndoth = dot(nDirWS, normalize(lDirWS_spec + vDirWS));
                half specularSun =  saturate(pow(ldotvr, 100.0)) * 0.4 * saturate(i.posTS.z * 4.0);
                half specularMoon =  saturate(pow(reverseldotvr, 150.0)) * 0.1 * saturate(i.posTS.z * 4.0);
                
                half3 ambient = float3(0.0, 0.005, 0.01);
                
                half3 finalRGB = grassCol * Lambert * _LightCol + specularSun * _LightColor0 + specularMoon + 
                ambient;
                half3 fogRGB = ExponentFog(finalRGB, i.posWS.xyz);
                
                return fixed4(fogRGB, 1.0);
                //return var_windMap2;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}