Shader "static"
{

	//example of using a psuedorandom function to simulate TV static

	Properties
	{
	    _MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 1
	}

		CGINCLUDE //shared includes, variables, and functions
		#include "UnityCG.cginc"

		// User-specified properties
	    sampler2D _MainTex;
		uniform float _Brightness;

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
				  float3 tangentWorld : TEXCOORD3;
				  float3 normalWorld : TEXCOORD4;
				  float3 binormalWorld : TEXCOORD5;
			  };
			  //CustomEditor "Scootoon_2Editor"
			  v2f vert(appdata input)
			  {
					v2f output;

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
					////float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
					////half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
					//half3 worldN = UnityObjectToWorldNormal(input.normal);
					//half3 shlight = ShadeSH9(float4(worldN, 1.0));

					return output;
			  }

			  float4 frag(v2f input) : COLOR
			  {
					//half4 col = tex2D(_MainTex, input.tex.xy);
				    float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);
					float rand = random(input.pos.z);
					float rand2 = random(input.pos.z + 0.000000000001 * input.pos.w);
					half4 col = tex2D(_MainTex, float2(rand,rand2));

					 return col * _Brightness;
			  }
			  ENDCG
		  }

	   }
}