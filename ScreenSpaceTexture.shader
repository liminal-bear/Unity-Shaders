Shader "screen space texture"
{
	Properties
	{
	    _MainTex("Main Texture", 2D) = "black" {}
	}

		CGINCLUDE //shared includes, variables, and functions
#include "UnityCG.cginc"

		//uniform float4 _LightColor0;
		// color of light source (from "Lighting.cginc")

		// User-specified properties
	    sampler2D _MainTex;
		float4 _MainTex_ST;
		fixed4 _Tint;
		uniform float _Blend;
		half _Distortion, _LineSpeed, _Flicker;

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
		  
		  Cull Off

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
				  float4 screenPos : TEXCOORD3;
			  };
			  vertexOutput vert(vertexInput input)
			  {
					vertexOutput output;

					//output.posWorld = mul(modelMatrix, input.vertex);
					output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					output.tex = input.texcoord;
					output.pos = UnityObjectToClipPos(input.vertex);
					output.posObj = input.vertex;
					output.screenPos = ComputeScreenPos(output.pos);
					return output;
			  }

			  float4 frag(vertexOutput input) : COLOR
			  {
					 float2 uv = input.screenPos.xy / input.screenPos.w;
					 float2 scaleduv = uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				     half4 col = tex2D(_MainTex, scaleduv);

					 return col;
			  }
			  ENDCG
		  }

	   }
}