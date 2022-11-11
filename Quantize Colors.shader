Shader "Quantize"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "black" {}
		_Quantize("Quantize colors", Range(1,100)) = 10
	}

		CGINCLUDE //shared includes, variables, and functions
		#include "UnityCG.cginc"

		//uniform float4 _LightColor0;
		// color of light source (from "Lighting.cginc")

		// User-specified properties
			sampler2D _MainTex;
		fixed4 _Tint;
		uniform float _Blend;
		int _Quantize;

		float random(float2 seed)
		{
			return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
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
			Blend SrcAlpha OneMinusSrcAlpha
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
				   // position of the vertex (and fragment) in world space 
				   float4 tex : TEXCOORD1;
			   };
			   vertexOutput vert(vertexInput input)
			   {
					 vertexOutput output;

					 output.tex = input.texcoord;
					 output.pos = UnityObjectToClipPos(input.vertex);

					 return output;
			   }

			   float4 frag(vertexOutput input) : COLOR
			   {
					  float4 col = tex2D(_MainTex, input.tex.xy);
					  col.rgb = round(col.rgb * _Quantize) / _Quantize;
					  return col;
			   }
			   ENDCG
		   }

		}
}