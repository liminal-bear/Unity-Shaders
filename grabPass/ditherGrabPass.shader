Shader "screenGrabPass"
{
	Properties
	{
		[KeywordEnum(Default, Overlay)] _RenderMode("Render Mode", Float) = 0
		_MainTex("UI Texture", 2D) = "black" { }
		_RenderRange("RenderRange", Range(0, 99)) = 1
		[KeywordEnum(Off, Front, Back)] _CullingMode("Cull Mode", Float) = 0


		_DitherTex("Dither pallete", 2D) = "white" { }
		_Posterize("Posterization factor", Range(0.0, 128)) = 2.1
		_DitherSize("Dither Size", Range(0, 5)) = 0.48


		_Brightness("Brightness", Range(0, 5)) = 1
	}
	SubShader
		{
		Tags {
			"RenderType" = "TransparentCutout"
			"Queue" = "Transparent+2000"}
		AlphaToMask On
			ZWrite off
			LOD 100
			Cull[_CullingMode]
			GrabPass { "_GrabTexture" }
		Pass
			{
			blend srcalpha oneminussrcalpha
			CGPROGRAM
				#pragma vertex vert
#pragma fragment frag
#pragma multi_compile_fog
#pragma target 4.0
#pragma shader_feature PP_ON
#pragma shader_feature LR_ON

# include "UnityCG.cginc"
	sampler2D _GrabTexture;


	float toGrayscale(float3 input)
	{
		return (input.r + input.g + input.b) / 3;
	}

	struct vertexInput
{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	struct vertexOutput
	{
		float4 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
		float4 distance : TEXCOORD2;
		float4 screenPosition : TEXCOORD3;
	};

	sampler2D _MainTex;
	float4 _MainTex_ST;
	float _Brightness;
	float _RenderMode;
	float _RenderRange;
	float distance;

	sampler2D _DitherTex;
	float4 _DitherTex_TexelSize;

	uniform int _Posterize;
	uniform int _Quantize;

	uniform half _DitherSize;

	
    float Quantize(float num, float quantize)
    {
        return round(num * quantize) / quantize;
    }

	float4 Unity_Posterize_float4(float4 In, float4 Steps)
	{
		return floor(In / (1 / Steps)) * (1 / Steps);
	}

	float3 Unity_Posterize_float3(float3 In, float3 Steps)
	{
		return floor(In / (1 / Steps)) * (1 / Steps);
	}

	float3 DitheredPalette(float x, float3 color1, float3 color2, float4 screenPosition, float2 screenParams)
	{
		//float idx = clamp(x, 0.0, 1.0) * int(_Posterize - 1);

		//float DITHER_THRESHOLDS[16] =
		//{
		//	1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
		//	13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
		//	4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
		//	16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
		//};


		float2 screenPos = (screenPosition.xy * _DitherSize) / screenPosition.w;

		float2 ditherCoordinate = screenPos * screenParams * _DitherTex_TexelSize.xy;
		float ditherValue = tex2D(_DitherTex, ditherCoordinate).r;
		//float ditherValue = tex2D(_DitherTex, uv).r;

		//float2 uv = positionClipSpace.xy / _ScreenParams.xy;
		//uv *= _ScreenParams.xy * _DitherSize;
		//uint index = (uint(uv.x) % 3) + uint(uv.y) % 3;
		// Returns > 0 if not clipped, < 0 if clipped based
		// on the dither
		//clip(alpha - DITHER_THRESHOLDS[index]);
		//clip(alpha - DITHER_THRESHOLDS[round(random(float2(_SinTime.y, _CosTime.y))* 16)]);

		//float3 color1 = Unity_Posterize_float3(lerp(_ShadowColor, _LitColor, idx / (_Posterize-1)),_Posterize);
		//float3 color2 = Unity_Posterize_float3(lerp(_ShadowColor, _LitColor, (idx + 1) / (_Posterize-1)),_Posterize);

		//return alpha;
		//float mixAmt = idx - 0.2 > DITHER_THRESHOLDS[index];
		//float mixAmt = idx > DITHER_THRESHOLDS[index];
		//float mixAmt = idx > ditherValue;
		//float mixAmt = step(ditherValue, x-.1);
		float mixAmt = step(ditherValue, x - .1);
		//float mixAmt = ditherValue >= x ? 1 : 0;
		//return lerp(_ShadowColor, _LitColor, mixAmt);

		//return float3(ditherValue, ditherValue, ditherValue);
		//return float3(DITHER_THRESHOLDS[index], DITHER_THRESHOLDS[index], DITHER_THRESHOLDS[index]);

		return lerp(color1, color2, mixAmt);
	}

	vertexOutput vert(vertexInput input)
	{
		vertexOutput output;
		output.vertex = UnityObjectToClipPos(input.vertex);

		output.distance.x = output.vertex.w;
		output.uv = output.vertex;


		if (_RenderMode > 0)
		{
			output.uv = float4(TRANSFORM_TEX(input.uv, _MainTex), 1, 1);
			output.vertex.xy = output.uv;
			output.vertex.xy -= 0.5;
			output.vertex.xy *= 2;
			output.vertex.y = -output.vertex.y;
			output.vertex.zw = 1;
		}
		output.screenPosition = ComputeScreenPos(output.vertex);


		return output;
	}


			fixed4 frag(vertexOutput input) : SV_Target
			{

				if (_RenderMode > 0)
				{
				}
				else
				{

					input.uv.xy /= input.uv.w;
					input.uv.x = (input.uv.x + 1) / 2;
					input.uv.y = 1 - (input.uv.y + 1) / 2;
				}


				float4 col = tex2D(_GrabTexture, input.uv.xy);

				fixed gray = toGrayscale(col.rgb);
				col = float4(col.rgb / (gray + 0.2), 1);

				col.rgb = Unity_Posterize_float3(col.rgb, _Posterize);

				//col.rgb *= _Brightness;

				//col.rgb = DitheredPalette(toGrayscale(col.rgb), float4(0, 0, 0, 0), float4(1, 1, 1, 1), input.screenPosition);
				col.rgb = DitheredPalette(toGrayscale(col)*9, float3(0,0,0), col.rgb, input.screenPosition, _ScreenParams.xy);


				return col;
			}
		ENDCG
		}
	}
}
//ahzkwid
