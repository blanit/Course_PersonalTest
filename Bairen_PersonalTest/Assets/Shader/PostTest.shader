Shader "Unlit/PostTest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Pass
        {
            //ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            
            half _Brightness;
            half _Saturation;
            half _Contrast;
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 renderTex = tex2D(_MainTex, i.uv);
            
                
                //brightness
                fixed4 finalCol = renderTex * 0.5;//_Brightness;


                //fixed luminance = 0.2125 * renderTex.r + 0.7154 * renderTex.g + 0.0721 * renderTex.b;
                //fixed3 luminanceCol = fixed3(luminance, luminance, luminance);
                
                //return fixed4(0.5,0.5,0.5,1.0);
                return finalCol;
            }
            ENDCG
        }
    }
    FallBack Off
}
