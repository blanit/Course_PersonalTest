Shader "Bairen/BR51_PBR"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _Metallic ("Metallic", range(0, 1)) = 0
        _Smoothness ("Smoothness", range(0, 1)) = 0
        _LUT ("ind_BRDF_LUT", 2d) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            sampler2D _MainTex;
            sampler2D _LUT;
            half _Metallic;
            half _Smoothness;

            // ------------ BRDF_Function ------------
            #define PI 3.1415926
            
            float3 BRDF_SchlickFresnel (float3 Albedo, float metallic, float ndotv)
            {
                float3 F0 = lerp(unity_ColorSpaceDielectricSpec.rgb, Albedo, metallic);
                float3 fresnel = F0 + (1 - F0) * pow((1 - ndotv), 5);
                // UE方案
                // float3 fresnel = F0 + (1 - F0) * exp2((-5.55473 * vdoth - 6.98316) * vdoth); 
                return fresnel;
            }

            float3 BRDF_GGX (float smoothness, float ndoth)
            {
                float a2 = pow(lerp(0.002, 1, 1 - smoothness), 2);
                float d = ( ndoth * a2 - ndoth ) * ndoth + 1;
                return a2 / ( PI*d*d );
            }

            float3 BRDF_MaskingShadowing (float smoothness, float ndotl, float ndotv)
            {
                float k = pow(pow(1 - smoothness, 4) + 1, 2) / 8;
                float g1 = ndotl / lerp(ndotl, 1.0, k);
                float g2 = ndotv / lerp(ndotv, 1.0, k);
                return g1 * g2;
            }

            float3 PBR_IBL (float smoothness, float3 nDir, float3 vDir, float3 Albedo, float metallic, float ndotv, sampler2D _lut)
            {
                // iblLighting
                float roughness = lerp(0.000001, 0.999999, 1.0 - smoothness);
                float mip_roughness = roughness * (1.7 - 0.7 * roughness);
                float mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
                float3 rDir = reflect(-vDir, nDir);
                float4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, rDir, mip);
                float3 iblLighting = DecodeHDR(rgbm, unity_SpecCube0_HDR);

                // iblBRDF
                float2 DecodeLUT = tex2D(_lut, float2(lerp(0.000001, 0.999999, ndotv), roughness)).rg;
                float3 F0 = lerp(unity_ColorSpaceDielectricSpec.rgb, Albedo, metallic);
                float3 iblBRDF = F0 * DecodeLUT.r + DecodeLUT.g;
                
                return iblLighting * iblBRDF;
            }

            float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
            {
	            return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
            }
            // ------------ BRDF_Function ------------

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 posWS : TEXCOORD1;
                float3 nDirWS : TEXCOORD2;
            };

            v2f vert(appdata_full v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                o.posWS = mul(unity_ObjectToWorld, v.vertex);
                o.nDirWS = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // sample
                half3 Albedo = tex2D(_MainTex, i.uv);

                // basic vector
                half3 lDir = normalize(_WorldSpaceLightPos0.xyz);
                half3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                half3 nDir = normalize(i.nDirWS);
                half3 hDir = normalize(lDir + vDir);
                
                float ndoth = max(saturate(dot(nDir, hDir)), 0.000001);
                float ndotl = max(saturate(dot(nDir, lDir)), 0.000001);
                float ndotv = max(saturate(dot(nDir, vDir)), 0.000001);
                float vdoth = max(saturate(dot(vDir, hDir)), 0.000001);

                // dLighting
                float3 f = BRDF_SchlickFresnel(Albedo, _Metallic, ndotv);            // fresnel term
                float3 g = BRDF_MaskingShadowing(_Smoothness, ndotl, ndotv);    // grazing term
                float3 d = BRDF_GGX(_Smoothness, ndoth);                      // ndf term

                float3 kd = (1 - f)*(1 - _Metallic);
                float3 diff = kd * Albedo * ndotl;

                float3 lightColor = _LightColor0.rgb;
                
                float3 dLighting = (f * d * g * 0.25) / (ndotv * ndotl) * ndotl * PI + diff;
                dLighting *= lightColor;

                // indLighting
                float3 F0 = lerp(unity_ColorSpaceDielectricSpec.rgb, Albedo, _Metallic);
                float3 Flast = fresnelSchlickRoughness(max(ndotv, 0.0), F0, 1 - _Smoothness);
                float kdLast = (1 - Flast) * (1 - _Metallic);
                half3 ambient_contrib = ShadeSH9(float4(i.nDirWS, 1));
                float3 ambient = 0.03 * Albedo;

                float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambient_contrib);
                iblDiffuse *= kdLast * Albedo;
                float3 ibl = PBR_IBL(_Smoothness, nDir, vDir, Albedo, _Metallic, ndotv, _LUT);
                
                float3 indLighting = ibl + iblDiffuse;
                
                return fixed4(dLighting + indLighting, 1.0);
            }
            
            
            ENDCG
        }
    }
}
