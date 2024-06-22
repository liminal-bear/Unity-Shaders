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
				  float4 screenPos : TEXCOORD3;
			  };
			  v2f vert(appdata input)
			  {
					v2f output;

					output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					output.tex = input.texcoord;
					output.pos = UnityObjectToClipPos(input.vertex);
					output.posObj = input.vertex;
					output.screenPos = ComputeScreenPos(output.pos);
					return output;
			  }

			  float4 frag(v2f input) : COLOR
			  {
				  
					 float2 uv = input.screenPos.xy / input.screenPos.w;

				     half4 col = tex2D(_MainTex, UnityStereoScreenSpaceUVAdjust(uv, _MainTex_ST));

					 return col;
			  }
			  ENDCG
		  }

	   }
}