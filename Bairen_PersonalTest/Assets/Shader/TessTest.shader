Shader "Unlit/sh_Tressla"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_TessellationUniform("细分参数",float)= 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM

			#pragma hull myhull
            #pragma domain myds

			//接下来定义的顶点着色器并非如往常一样的
            #pragma vertex tessvert   
            #pragma fragment frag

            #include "UnityCG.cginc"

		    sampler2D _MainTex;
            float4 _MainTex_ST;


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent: TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
            };

       //仅是用来处理顶点空间转换的，涉及到其他的如顶点沿法线挤出的顶点相关操作也由这边来做，曲面细分的部分一般来讲不用动
            v2f vert (appdata v)
            {
                v2f o;
           	    o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
			    o.normal=v.normal;
			    o.tangent=v.tangent;
                return o;			
            }

       //曲面细分着色器的相关部分
			#ifdef UNITY_CAN_COMPILE_TESSELLATION
			
    	//定义曲面细分
			struct Tessvert{
			  float4 vertex : INTERNALTESSPOS;
			  float3 normal : NORMAL;
			  float4 tangent : TANGENT;
			  float2 uv:  TEXCOORD0;
			};
       //定义Patch
			struct OutputPatchConstant{
			   float edge[3] : SV_TESSFACTOR;
               float inside  : SV_INSIDETESSFACTOR;
			};

			//使用顶点着色器传入的数据到曲面细分中进行操作
			Tessvert tessvert(appdata v){
			   Tessvert o;
			   o.vertex  = v.vertex;
			   o.normal  = v.normal;
			   o.tangent = v.tangent;
			   o.uv      = v.uv;
			   return o;
			}

			float _TessellationUniform;

			//设定patch
			OutputPatchConstant hsconst(InputPatch<Tessvert,3>patch){
			   OutputPatchConstant o;
			   o.edge[0]=_TessellationUniform;
			   o.edge[1]=_TessellationUniform;
			   o.edge[2]=_TessellationUniform;
               o.inside =_TessellationUniform;
			   return o;
			}

			//设定一些曲面细分的相关设置
			[UNITY_domain("tri")]
			[UNITY_partitioning("fractional_odd")]
			[UNITY_outputtopology("triangle_cw")]
			[UNITY_patchconstantfunc("hsconst")]
			[UNITY_outputcontrolpoints(3)]
            
			//hull shader
			Tessvert myhull(InputPatch<Tessvert,3>patch,uint id : SV_OUTPUTCONTROLPOINTID){
			   return patch[id];
			}

			//domain shader
			[UNITY_domain("tri")]
			v2f myds(OutputPatchConstant tessFactors,const OutputPatch<Tessvert,3>patch,float3 bary:SV_DOMAINLOCATION){
			    appdata v;
				v.vertex  = patch[0].vertex*bary.x+patch[1].vertex*bary.y+patch[2].vertex*bary.z;
				v.tangent = patch[0].tangent*bary.x+patch[1].tangent*bary.y+patch[2].tangent*bary.z;
			    v.normal  = patch[0].normal*bary.x+patch[1].normal*bary.y+patch[2].normal*bary.z;
				v.uv      = patch[0].uv*bary.x+patch[1].uv*bary.y+patch[2].uv*bary.z;
			    v2f o     = vert(v);  
			    return o;
			}
			#endif

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
           
                return col;
            }
            ENDCG
        }
    }
}