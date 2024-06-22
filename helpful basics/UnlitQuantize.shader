// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "UnlitBaseQuantize"
{
	Properties
	{
	    _MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 0
		_Quantize("Quantize", Range(1,500)) = 1
	}

		CGINCLUDE //shared includes, variables, and functions
#include "UnityCG.cginc"

		//uniform float4 _LightColor0;
		// color of light source (from "Lighting.cginc")

		// User-specified properties
	    sampler2D _MainTex;
		uniform float _Brightness;
		int _Quantize;

	   float random(float2 seed)
	   {
		   return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
	   }

	   float Quantize(float num, float quantize)
	   {
		   return round(num * quantize) / quantize;
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

			  struct appdata
			  {
				  float4 vertex : POSITION;
				  float4 texcoord : TEXCOORD0;
				  float3 normal : NORMAL;
				  float4 tangent : TANGENT;
			  };
			  struct v2f
			  {
				  float4 pos : SV_POSITION;
				  float4 posWorld : TEXCOORD0;
				  float4 posObj : TEXCOORD1;
				  // position of the vertex (and fragment) in world space 
				  float4 tex : TEXCOORD2;
			  };
			  v2f vert(appdata input)
			  {
					v2f output;

					//output.posWorld = mul(modelMatrix, input.vertex);
					output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					output.tex = input.texcoord;
					output.posObj = input.vertex;

					//output.pos = UnityObjectToClipPos(input.vertex);
					//input.vertex.x = Quantize(input.vertex.x, _Quantize);
					//input.vertex.y = Quantize(input.vertex.y, _Quantize);
					//input.vertex.z = Quantize(input.vertex.z, _Quantize);
					//input.vertex.w = Quantize(input.vertex.w, _Quantize);

					float4 worldVertex = mul(unity_ObjectToWorld, input.vertex);
					worldVertex.x = Quantize(worldVertex.x, _Quantize);
					worldVertex.y = Quantize(worldVertex.y, _Quantize);
					worldVertex.z = Quantize(worldVertex.z, _Quantize);
					worldVertex.w = Quantize(worldVertex.w, _Quantize);

					worldVertex.x += input.vertex.x * 0.001;
					worldVertex.y += input.vertex.y * 0.001;
					worldVertex.z += input.vertex.z * 0.001;
					worldVertex.w += input.vertex.w * 0.001;

					input.vertex = mul(unity_WorldToObject, worldVertex);

					output.pos = UnityObjectToClipPos(input.vertex);

					return output;
			  }

			  float4 frag(v2f input) : COLOR
			  {
				     half4 col = tex2D(_MainTex, input.tex.xy);

					 return col * _Brightness;
			  }
			  ENDCG
		  }

	   }
}