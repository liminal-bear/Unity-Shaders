// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "2d"
{

	//this shader is almost exactly like UnlitBase, but also does a vertex transformation that multiplies the z coordinate by 0.001, thus achieving a flat effect.
	//depending on the model, the 'input.vertex.z' may have to be changed to 'input.vertex.x'

	Properties
	{
	    _MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 1
		_Quantize("Quantize", Range(1,500)) = 1
	}

		CGINCLUDE //shared includes, variables, and functions
#include "UnityCG.cginc"


		// User-specified properties
	    sampler2D _MainTex;
		uniform float _Brightness;

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
				  //float4 posWorld : TEXCOORD0;
				  float4 posObj : TEXCOORD1;
				  // position of the vertex (and fragment) in world space 
				  float4 tex : TEXCOORD2;
				  //float3 tangentWorld : TEXCOORD3;
				  //float3 normalWorld : TEXCOORD4;
				  //float3 binormalWorld : TEXCOORD5;
			  };
			  vertexOutput vert(vertexInput input)
			  {
					vertexOutput output;

					//output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					output.tex = input.texcoord;
					output.posObj = input.vertex;

					input.vertex.z = input.vertex.z * 0.001;//we do not multiply by 0, because then we would get "double planing" (also known as "Z-Fighting")

					output.pos = UnityObjectToClipPos(input.vertex);

					half3 worldN = UnityObjectToWorldNormal(input.normal);

					return output;
			  }

			  float4 frag(vertexOutput input) : COLOR
			  {
				     half4 col = tex2D(_MainTex, input.tex.xy);

					 return col * _Brightness;
			  }
			  ENDCG
		  }

	   }
}