Shader "UnlitDither"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 1
		_Opacity("Opacity", Range(0,1)) = 1
	    _DitherCutoff("Dither Cutoff", Range(0,5)) = 5
		_DitherSize("Dither Size", Range(0,5)) = 5
	}

		CGINCLUDE //shared includes, variables, and functions
#include "UnityCG.cginc"

		//uniform float4 _LightColor0;
		// color of light source (from "Lighting.cginc")

		// User-specified properties
		sampler2D _MainTex;
		uniform float _Brightness;

		float _Opacity;
		float _DitherCutoff;
		float _DitherSize;

		float random(float2 seed)
		{
			return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
		}

		half DitheredAlpha(half albedoAlpha, half4 color, half cutoff, half transparency, half ditherSize, float4 positionCS)
		{
			half alpha = transparency;
			float DITHER_THRESHOLDS[16] =
			{
				1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
				13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
				4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
				16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
			};

			float2 uv = positionCS.xy / _ScreenParams.xy;
			uv *= _ScreenParams.xy * ditherSize;
			uint index = (uint(uv.x) % 3) + uint(uv.y) % 3;
			// Returns > 0 if not clipped, < 0 if clipped based
			// on the dither
			clip(alpha - DITHER_THRESHOLDS[index]);
			//clip(alpha - DITHER_THRESHOLDS[round(random(float2(_SinTime.y, _CosTime.y))* 16)]);

			return alpha;
		}

		ENDCG
			SubShader
		{
		   Tags
		   {
			   "Queue" = "Transparent"
			   "IgnoreProjector" = "True"
			   "VRCFallback" = "Toon"
		   }

		   Pass
		   {
			   CGPROGRAM
			   #pragma vertex vert
			   #pragma fragment frag

			   struct vertexInput
			   {
				   float4 vertex : POSITION;
				   float4 texcoord : TEXCOORD0;
				   float3 normal : NORMAL;
				   float4 tangent : TANGENT;
			   };
			   struct vertexOutput
			   {
				   float4 pos : SV_POSITION;
				   float4 posWorld : TEXCOORD0;
				   float4 posObj : TEXCOORD1;
				   // position of the vertex (and fragment) in world space 
				   float4 tex : TEXCOORD2;
				   float3 tangentWorld : TEXCOORD3;
				   float3 normalWorld : TEXCOORD4;
				   float3 binormalWorld : TEXCOORD5;
			   };
			   vertexOutput vert(vertexInput input)
			   {
					 vertexOutput output;

					 float4x4 modelMatrix = unity_ObjectToWorld;
					 float4x4 modelMatrixInverse = unity_WorldToObject;

					 output.tangentWorld = normalize(
						 mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
					 output.normalWorld = normalize(
						 mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
					 output.binormalWorld = normalize(
						 cross(output.normalWorld, output.tangentWorld)
						 * input.tangent.w); // tangent.w is specific to Unity

					 //output.posWorld = mul(modelMatrix, input.vertex);
					 output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					 output.tex = input.texcoord;
					 output.pos = UnityObjectToClipPos(input.vertex);
					 output.posObj = input.vertex;
					 //float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
					 //half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
					 half3 worldN = UnityObjectToWorldNormal(input.normal);
					 half3 shlight = ShadeSH9(float4(worldN, 1.0));

					 return output;
			   }

			   float4 frag(vertexOutput input) : COLOR
			   {
					  half4 col = tex2D(_MainTex, input.tex.xy);

					  col.a = DitheredAlpha(1, float4(col.rgb, 1), _DitherCutoff, _Opacity, _DitherSize, input.pos);
				      //return float4(realCol, clamp(1 + DitheredAlpha(1, float4(realCol, 1), _DitherCutoff, _Opacity, _DitherSize, input.pos), 0, 1));

					  return col * _Brightness;
			   }
			   ENDCG
		   }

		}
}