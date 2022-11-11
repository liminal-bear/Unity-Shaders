// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "CRT Full" 
{
	Properties
	{
		_MainTex("Base (RGB)", 2D) = "white" {}
		_LCDTex("LCD (RGB)", 2D) = "white" {}
		_LCDPixels("LCD pixels", Vector) = (6,8,0,0)
		_Pixels("Pixels", Vector) = (256,256,0,0)
		_NoiseTex("Noise Texture", 2D) = "white" {}
		_NoiseXSpeed("Noise X Speed", Float) = 100.0
		_NoiseYSpeed("Noise Y Speed", Float) = 100.0
		_NoiseCutoff("Noise Cutoff", Range(0, 1.0)) = 0.44
		_NoiseStrength("Noise Strength", Range(0, 5.0)) = 0.44
		_VignetteTex("Vignette Texture", 2D) = "white" {}
		_VignetteStrength("VignetteStrength", Range(0.1, 10.0)) = 3.0
		_Brightness("Brightness", Range(0.0, 10.0)) = 2.34
		_DistortionSrength("Distortion Strength", Range(0.0, 20.0)) = 1.49
		_Zoom("Zoom", Range(1, 10.0)) = 1.53
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 200

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			sampler2D _MainTex;
		    float4 _MainTex_ST;
			float _Zoom;
			sampler2D _LCDTex;
			float4 _LCDTex_ST;
			uniform sampler2D _NoiseTex;
			uniform fixed _NoiseXSpeed;
			uniform fixed _NoiseYSpeed;
			uniform fixed _NoiseCutoff;
			float _NoiseStrength;
			uniform sampler2D _VignetteTex;
			float _VignetteStrength;
			uniform sampler2D _LineTex;
			uniform fixed4 _LineColor;
			float4 _LCDPixels;
			float4 _Pixels;
			float _Brightness;
			uniform fixed _DistortionSrength;

			struct Input
			{
				float2 uv_MainTex;
				float3 worldPos;
			};

			struct vertexInput
			{
				fixed4 vertex : POSITION;
				fixed2 uv : TEXCOORD0;
			};

			struct fragInput
			{
				fixed2 uv : TEXCOORD0;
				fixed4 vertex : SV_POSITION;
			};

			fragInput vert(vertexInput v)
			{
				fragInput o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = (v.uv); //* _MainTex_ST.xy) + _MainTex_ST.zw;
				return o;
			}

			fixed2 LensDistortion(fixed2 uv)
			{
				fixed2 center = uv - 0.5;
				fixed r2 = center.x * center.x + center.y * center.y;
				fixed ratio = 1.0 + r2 * _DistortionSrength * sqrt(r2);

				return center * ratio + 0.5;
			}

			fixed2 Pixelization(fixed2 uv)
			{
				float2 newuv = round(uv * _Pixels.xy + 0.5) / _Pixels.xy;
				return newuv;
			}

			fixed4 frag(fragInput i) : SV_Target
			{
				fixed2 distortionUV = LensDistortion(i.uv);
			    //fixed2 lcdUV = (i.uv * _LCDTex_ST.xy) + _LCDTex_ST.zw;
				fixed2 lcdUV = LensDistortion(i.uv) * _Pixels.xy / _LCDPixels;

				fixed4 vignetteTex = tex2D(_VignetteTex, i.uv);
				//fixed4 lcdTex = Pixelization(lcdUV);
				fixed4 lcdTex = tex2D(_LCDTex, lcdUV);

				distortionUV = (distortionUV - 0.5) / _Zoom + 0.5;

				//fixed4 mainTex = tex2D(_MainTex, (distortionUV * _MainTex_ST.xy) + _MainTex_ST.zw);
				fixed4 mainTex = tex2D(_MainTex, distortionUV);

				fixed2 noiseUV = distortionUV + fixed2(_NoiseXSpeed * _SinTime.z, _NoiseYSpeed * _SinTime.z);
				fixed4 noiseTex = tex2D(_NoiseTex, noiseUV);
				if (noiseTex.r > _NoiseCutoff)
					noiseTex = fixed4(1, 1, 1, 1);

				fixed4 finalColor = mainTex;
				finalColor += noiseTex * _NoiseStrength;
				finalColor *= (vignetteTex / _VignetteStrength);
				finalColor *= lcdTex;
				finalColor *= _Brightness;

				return finalColor;
			}
			ENDCG
		}
	}
}