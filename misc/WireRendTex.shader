Shader "Custom/WireRendTex"
{
    //takes in a camera depth texture, and outputs a wireframe
    //Uses Neitri's edge detection formula on a World Normal
    //There are currently moire artifacts when converting the depth to a world normal.

    Properties
    {
        _DepthTexture ("Depth Texture", 2D) = "white" {}
		_WireframeColor("Wireframe Color", Color) = (1, 1, 1, 1)
		_BackgroundColor("Background Color", Color) = (0, 0, 0, 1)
        _WireframeThickness("Wireframe Thickness", Range(0,50)) = 1

        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        
        Pass
        {

            Cull[_Cull]
			ZWrite[_ZWrite]
			Ztest[_ZTest]
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

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

            sampler2D _DepthTexture;
            fixed4 _DepthTexture_TexelSize;
            float _WireframeThickness;
            fixed4 _BackgroundColor;
			fixed4 _WireframeColor;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            half3 AdjustContrast(half3 color, half contrast) 
            {
                return saturate(lerp(half3(0.5, 0.5, 0.5), color, contrast));
            }

            float posterize (float c, float s)
			{
				return floor(c*s)/(s-1);
			}

            float3 CalculateWorldNormal(float3 worldPos)
            {
                float3 dx = ddx(worldPos);
                float3 dy = ddy(worldPos);

                // dx = float3(int3(dx * 10000));
                // dy = float3(int3(dy * 10000));
                // dx = dx / 10000;
                // dy = dy / 10000;

                float3 worldNormal = normalize(cross(dx, dy));
                // float fwidthVal = fwidth(worldPos.r)*999;
                // return float3(fwidthVal,fwidthVal,fwidthVal);
                return worldNormal;
            }

            float3 sampleWorldNormal(sampler2D depthTex, float2 uv, float4 texelsize)
            {

                // // pixelate uv to be directly in line with depthTexResolution
                //similar to point filtering
                // uv.xy = float2(int2(uv.xy * texelsize.zw));
                // uv.xy = uv.xy / texelsize.zw;

                // uv.xy = float2(int2(uv.xy * 10000));
                // uv.xy = uv.xy / 10000;
                // uv.xy = AdjustContrast(float3(uv.xy,1),8);

                // uv.xy = posterize2(uv.xy,1000);

                // return float4(uv.x, uv.y,0,1);

                float depth = tex2D(depthTex, uv).r;

                // float4 depthCol = tex2D(depthTex, uv);
                // return depthCol;


                float4 screenPos = float4(uv * 2 - 1, depth, 1);
                float4 worldPos = mul(unity_ObjectToWorld, screenPos);
                float3 worldNormal = CalculateWorldNormal(worldPos.xyz);
                return worldNormal.rgb;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float4 color = float4(0,0,0,0);

                float2 offset = _WireframeThickness / _ScreenParams.xy;

   	            float3 pos00 = sampleWorldNormal(_DepthTexture, i.uv,_DepthTexture_TexelSize).rgb;
				float3 pos01 = sampleWorldNormal(_DepthTexture, i.uv + float2(0, offset.y),_DepthTexture_TexelSize).rgb;
				float3 pos10 = sampleWorldNormal(_DepthTexture, i.uv - float2(offset.x, 0),_DepthTexture_TexelSize).rgb;
                float3 one = float3(1, 1, 1);
				float w = dot(one, abs(pos10 - pos00)) + dot(one, abs(pos01 - pos00));

				return lerp(_BackgroundColor, _WireframeColor, w);
                // return float4(sampleWorldNormal(_DepthTexture, i.uv,_DepthTexture_TexelSize).rgb,1);
                // return float4(tex2D(_DepthTexture, i.uv).rgb,1);
            }
            ENDCG
        }
    }
}
